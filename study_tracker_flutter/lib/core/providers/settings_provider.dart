import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities.dart';
import '../../data/db/database_provider.dart';
import '../../data/db/database.dart' as db;
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/subject_repository.dart';
import '../../core/sync/sync_trigger.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  final SubjectRepository _subjectRepo;
  final SessionRepository _sessionRepo;
  final db.AppDatabase _db;

  StructuredSettings _settings = const StructuredSettings();
  bool _isLoading = true;
  bool _isSwitchingProfile = false;
  int? _switchingToProfileId;
  String? _error;
  Timer? _syncRefreshDebounce;
  StreamSubscription<List<db.Profile>>? _profilesSubscription;

  StructuredSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSwitchingProfile => _isSwitchingProfile;
  int? get switchingToProfileId => _switchingToProfileId;
  String? get error => _error;

  List<SubjectGroup> subjectGroups = [];
  int activeGroupId = -1;
  List<Subject> subjects = [];
  List<Profile> profiles = [];
  int currentProfileId = 1;

  SettingsProvider(this._settingsRepo, this._subjectRepo, this._sessionRepo, this._db) {
    // Keep profile UI reactive to DB changes (including sync-applied payloads).
    _profilesSubscription = (_db.select(_db.profiles)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .listen((_) {
      unawaited(_refreshProfilesOnly());
    });

    // Sync-trigger writes can be noisy; debounce and avoid full blocking reload.
    SyncTrigger.instance.addListener(_scheduleBackgroundRefresh);
  }

  @override
  void dispose() {
    SyncTrigger.instance.removeListener(_scheduleBackgroundRefresh);
    _syncRefreshDebounce?.cancel();
    _profilesSubscription?.cancel();
    super.dispose();
  }

  void _scheduleBackgroundRefresh() {
    _syncRefreshDebounce?.cancel();
    _syncRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_backgroundRefresh());
    });
  }

  Future<void> _backgroundRefresh() async {
    try {
      _settings = await _settingsRepo.getStructured();
      await _refreshProfilesOnly(notify: false);
      _notify();
    } catch (e) {
      _error = e.toString();
      _notify();
    }
  }

  Future<void> _refreshProfilesOnly({bool notify = true}) async {
    final nextProfiles = await _settingsRepo.listProfiles();
    final nextCurrentProfileId = await _settingsRepo.getCurrentProfileId();
    final previousProfileId = currentProfileId;
    profiles = nextProfiles;

    // Recovery: if the active profile vanished (e.g. deleted via sync from another
    // device), persist a fallback id immediately and invalidate scoped caches so
    // Dashboard/Sessions stop showing the deleted profile's data.
    if (!nextProfiles.any((p) => p.id == nextCurrentProfileId)) {
       if (nextProfiles.isNotEmpty) {
          final fallbackId = nextProfiles.first.id!;
          currentProfileId = fallbackId;
          unawaited(_settingsRepo.setCurrentProfileId(fallbackId));
          _subjectRepo.clearLocalCache();
          _sessionRepo.clearLocalCache();
          activeGroupId = -1;
          subjects = [];
          subjectGroups = const [SubjectGroup(id: -1, name: 'All Subjects', color: '#5a7a5a')];
       }
    } else {
       currentProfileId = nextCurrentProfileId;
    }

    if (previousProfileId != currentProfileId) {
      _subjectRepo.clearLocalCache();
      _sessionRepo.clearLocalCache();
    }

    final currentProfile = _findCurrentProfile();
    if (currentProfile != null) {
      _settings = _settings.copyWith(
        displayName: currentProfile.name,
        academicLevel: currentProfile.academicLevel,
      );
    }
    if (notify) _notify();
  }

  Future<int> clearAppCache() async {
    var clearedBytes = 0;

    Future<void> clearDirectory(Directory directory) async {
      if (!await directory.exists()) return;
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          clearedBytes += await entity.length();
        }
      }
      await directory.delete(recursive: true);
      await directory.create(recursive: true);
    }

    final cacheDir = await getApplicationCacheDirectory();
    final tempDir = await getTemporaryDirectory();
    final docsDir = await _db.databaseFile();
    final overlaysDir = Directory('${docsDir.parent.path}${Platform.pathSeparator}session_overlays');

    await clearDirectory(cacheDir);
    await clearDirectory(tempDir);
    await clearDirectory(overlaysDir);

    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {
      // No-op on unsupported platforms.
    }

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    return clearedBytes;
  }

  Future<db.DatabaseCompactResult> compactDatabase() {
    return _db.compactDatabase();
  }

  bool _notificationPending = false;

  void _notify() {
    if (!hasListeners || _notificationPending) return;
    _notificationPending = true;
    Future.microtask(() {
      _notificationPending = false;
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> wipeDatabase() async {
    await _db.wipeDatabase();
    await loadSettings();
  }

  Future<void> loadSettings({bool notify = true}) async {
    _isLoading = true;
    _error = null;
    if (notify) _notify();

    try {
      await _db.ensureCoreSeedData();
      _settings = await _settingsRepo.getStructured();
      await _refreshProfilesOnly(notify: false);
      final groups = await _subjectRepo.listGroups();
      subjectGroups = [
        const SubjectGroup(id: -1, name: 'All Subjects', color: '#5a7a5a'),
        ...groups,
      ];
      subjects = await _subjectRepo.listAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      if (notify) _notify();
    }
  }

  void updateField({
    String? displayName,
    String? academicLevel,
    String? languageCode,
    int? dailyGoalHours,
    int? focusMinutes,
    int? breakMinutes,
    bool? aiChallengesEnabled,
    String? groqApiKey,
    String? defaultBackground,
    int? overlayHue,
    bool? isFocusAudioEnabled,
    double? focusAudioVolume,
  }) {
    _settings = _settings.copyWith(
      displayName: displayName,
      academicLevel: academicLevel,
      languageCode: languageCode,
      dailyGoalMinutes: dailyGoalHours != null ? dailyGoalHours * 60 : null,
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      aiChallengesEnabled: aiChallengesEnabled,
      groqApiKey: groqApiKey,
      defaultBackground: defaultBackground,
      overlayHue: overlayHue,
      isFocusAudioEnabled: isFocusAudioEnabled,
      focusAudioVolume: focusAudioVolume,
    );
    _notify();
  }

  Future<void> saveSettings() async {
    _isLoading = true;
    _notify();

    try {
      final map = <String, String>{
        'dailyGoalMinutes': _settings.dailyGoalMinutes.toString(),
        'focusMinutes': _settings.focusMinutes.toString(),
        'breakMinutes': _settings.breakMinutes.toString(),
        'languageCode': _settings.languageCode,
        'aiChallengesEnabled': _settings.aiChallengesEnabled.toString(),
        'groqApiKey': _settings.groqApiKey ?? '',
        'defaultBackground': _settings.defaultBackground ?? '',
        'overlayHue': (_settings.overlayHue ?? 210).toString(),
        'isFocusAudioEnabled': _settings.isFocusAudioEnabled.toString(),
        'focusAudioVolume': _settings.focusAudioVolume.toString(),
      };
      await _settingsRepo.setMany(map);
      await _settingsRepo.setCurrentProfileId(currentProfileId);
      final currentProfile = _findCurrentProfile();
      if (currentProfile != null) {
        await _settingsRepo.updateProfile(
          currentProfile.copyWith(
            name: _settings.displayName?.trim().isNotEmpty == true
                ? _settings.displayName!.trim()
                : currentProfile.name,
            academicLevel: _settings.academicLevel ?? currentProfile.academicLevel,
          ),
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void setActiveGroup(int groupId) {
    activeGroupId = groupId;
    _notify();
  }

  List<Subject> get filteredSubjects {
    if (activeGroupId == -1) return subjects;
    return subjects.where((s) => s.groupId == activeGroupId).toList();
  }

  Future<void> addSubjectGroup({
    required String name,
    String color = '#5a7a5a',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    await _subjectRepo.createGroup(SubjectGroup(name: cleanName, color: color));
    final groups = await _subjectRepo.listGroups();
    subjectGroups = [
      const SubjectGroup(id: -1, name: 'All Subjects', color: '#5a7a5a'),
      ...groups,
    ];
    _notify();
  }

  Future<void> addSubject({
    required String name,
    int? groupId,
    String color = '#5a7a5a',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    await _subjectRepo.createSubject(
      Subject(
        name: cleanName,
        color: color,
        groupId: (groupId == -1) ? null : groupId,
      ),
    );
    subjects = await _subjectRepo.listAll();
    _notify();
  }

  Future<void> updateSubject({
    required int id,
    required String name,
    required int? groupId,
    required String color,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    await _subjectRepo.updateSubject(
      Subject(
        id: id,
        name: cleanName,
        color: color,
        groupId: groupId == -1 ? null : groupId,
      ),
    );
    subjects = await _subjectRepo.listAll();
    _notify();
  }

  Future<void> deleteSubject(int id) async {
    await _subjectRepo.deleteSubject(id);
    subjects = await _subjectRepo.listAll();
    _notify();
  }

  Future<void> updateSubjectGroup({
    required int id,
    required String name,
    required String color,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    await _subjectRepo.updateGroup(SubjectGroup(id: id, name: cleanName, color: color));
    final groups = await _subjectRepo.listGroups();
    subjectGroups = [
      const SubjectGroup(id: -1, name: 'All Subjects', color: '#5a7a5a'),
      ...groups,
    ];
    _notify();
  }

  Future<void> deleteSubjectGroup(int id) async {
    // Keep subjects by ungrouping them before deleting the group.
    final groupedSubjects = subjects.where((s) => s.groupId == id).toList(growable: false);
    for (final subject in groupedSubjects) {
      if (subject.id == null) continue;
      await _subjectRepo.updateSubject(subject.copyWith(groupId: null));
    }
    await _subjectRepo.deleteGroup(id);

    final groups = await _subjectRepo.listGroups();
    subjectGroups = [
      const SubjectGroup(id: -1, name: 'All Subjects', color: '#5a7a5a'),
      ...groups,
    ];
    subjects = await _subjectRepo.listAll();

    if (activeGroupId == id) {
      activeGroupId = -1;
    }
    _notify();
  }

  Profile? _findCurrentProfile() {
    for (final profile in profiles) {
      if (profile.id == currentProfileId) {
        return profile;
      }
    }
    return profiles.isNotEmpty ? profiles.first : null;
  }

  Future<void> switchProfile(int profileId) async {
    if (currentProfileId == profileId || _isSwitchingProfile) return;

    _isSwitchingProfile = true;
    _switchingToProfileId = profileId;
    _error = null;
    _notify();

    try {
      // Apply target profile shell immediately and clear stale scoped lists.
      currentProfileId = profileId;
      activeGroupId = -1;
      subjects = [];
      subjectGroups = const [SubjectGroup(id: -1, name: 'All Subjects', color: '#5a7a5a')];
      
      Profile? target;
      for (final profile in profiles) {
        if (profile.id == profileId) {
          target = profile;
          break;
        }
      }
      if (target != null) {
        _settings = _settings.copyWith(
          displayName: target.name,
          academicLevel: target.academicLevel,
        );
      }

      await _settingsRepo.setCurrentProfileId(profileId);
      _subjectRepo.clearLocalCache();
      _sessionRepo.clearLocalCache();
      
      // Load settings without extra notify since we'll notify at the end of this try block.
      await loadSettings(notify: false);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSwitchingProfile = false;
      _switchingToProfileId = null;
      _notify();
    }
  }

  Future<void> addProfile({
    required String name,
    required String academicLevel,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final id = await _settingsRepo.createProfile(
      Profile(name: cleanName, academicLevel: academicLevel),
    );
    currentProfileId = id;
    await _settingsRepo.setCurrentProfileId(id);
    await loadSettings();
  }

  Future<void> updateProfile({
    required int id,
    required String name,
    required String academicLevel,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    await _settingsRepo.updateProfile(
      Profile(id: id, name: cleanName, academicLevel: academicLevel),
    );
    await loadSettings();
  }

  Future<void> deleteProfile(int id) async {
    if (profiles.length <= 1) {
      _error = 'At least one profile is required.';
      _notify();
      return;
    }
    await _settingsRepo.deleteProfile(id);
    final updated = await _settingsRepo.listProfiles();
    profiles = updated;
    if (currentProfileId == id) {
      currentProfileId = profiles.first.id ?? 1;
      await _settingsRepo.setCurrentProfileId(currentProfileId);
    }
    await loadSettings();
  }
}

final settingsProvider = ChangeNotifierProvider<SettingsProvider>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final subjectRepo = ref.watch(subjectRepositoryProvider);
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final db = ref.watch(databaseProvider);
  return SettingsProvider(settingsRepo, subjectRepo, sessionRepo, db)..loadSettings();
});

