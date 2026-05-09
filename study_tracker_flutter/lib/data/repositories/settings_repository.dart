import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart' as db;
import '../db/database_provider.dart';
import '../../domain/domain.dart' as domain;
import '../../core/sync/sync_trigger.dart';


/// Settings repository — key-value store backed by app_settings table.
class SettingsRepository {
  final db.AppDatabase _db;

  SettingsRepository(this._db);

  static const _defaults = <String, String>{
    'dailyGoalMinutes': '240', // 4 hours from design
    'focusMinutes': '50', // from design
    'breakMinutes': '10', // from design
    'themeMode': 'light',
    'defaultSessionMode': 'pomodoro',
    'aiChallengesEnabled': 'true',
    'displayName': 'Eleanor',
    'academicLevel': 'Postgraduate',
    'isFocusAudioEnabled': 'true',
    'focusAudioVolume': '0.4',
    'defaultBackground': 'Forest',
    'overlayHue': '210',
    'languageCode': 'en',
    'currentProfileId': '1',
    'syncDebugEnabled': 'true',
    'syncDebugAlwaysVisible': 'false',
    // Opt-in: the persistent sync status chip and background auto-sync stay off until
    // the user explicitly turns WiFi sync on in the Sync tab.
    'wifiSyncEnabled': 'false',
  };

  static const Set<String> _profileScopedKeys = {
    'dailyGoalMinutes',
    'focusMinutes',
    'breakMinutes',
    'defaultSessionMode',
    'aiChallengesEnabled',
    'groqApiKey',
    'isFocusAudioEnabled',
    'focusAudioVolume',
    'defaultBackground',
    'overlayHue',
    'displayName',
    'academicLevel',
    'activeAiMissionId',
    'aiMissionTierFailure.daily',
    'aiMissionTierFailure.weekly',
    'aiMissionTierFailure.monthly',
    'aiMissionTierFailure.surprise',
  };

  String _profileKey(int profileId, String key) => 'profile.$profileId.$key';

  bool _isProfileScoped(String key) => _profileScopedKeys.contains(key);

  Future<String?> get(String key) async {
    if (_isProfileScoped(key)) {
      final profileId = await getCurrentProfileId();
      final scopedRow = await (_db.select(_db.appSettings)
            ..where((t) => t.key.equals(_profileKey(profileId, key))))
          .getSingleOrNull();
      if (scopedRow != null) return scopedRow.value;
    }

    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value ?? _defaults[key];
  }

  Future<void> set(String key, String value) async {
    final effectiveKey = _isProfileScoped(key)
        ? _profileKey(await getCurrentProfileId(), key)
        : key;
    await _db.into(_db.appSettings).insert(
          db.AppSettingsCompanion.insert(
            key: effectiveKey,
            value: value,
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
    SyncTrigger.instance.notifyWrite();
  }


  Future<void> delete(String key) async {
    final effectiveKey = _isProfileScoped(key)
        ? _profileKey(await getCurrentProfileId(), key)
        : key;
    await (_db.delete(_db.appSettings)..where((t) => t.key.equals(effectiveKey))).go();
    SyncTrigger.instance.notifyWrite();
  }


  Future<Map<String, String>> getAll() async {
    final profileId = await getCurrentProfileId();
    final scopedPrefix = 'profile.$profileId.';
    final rows = await _db.select(_db.appSettings).get();
    final result = Map<String, String>.from(_defaults);

    for (final row in rows) {
      if (!row.key.startsWith('profile.')) {
        result[row.key] = row.value;
      }
    }

    for (final row in rows) {
      if (!row.key.startsWith(scopedPrefix)) continue;
      final baseKey = row.key.substring(scopedPrefix.length);
      result[baseKey] = row.value;
    }

    return result;
  }

  Future<void> setMany(Map<String, String> settings) async {
    await _db.transaction(() async {
      for (final entry in settings.entries) {
        await set(entry.key, entry.value);
      }
    });
  }

  Future<domain.StructuredSettings> getStructured() async {
    final all = await getAll();
    return domain.StructuredSettings(
      dailyGoalMinutes: int.tryParse(all['dailyGoalMinutes'] ?? '') ?? 120,
      focusMinutes: int.tryParse(all['focusMinutes'] ?? '') ?? 25,
      breakMinutes: int.tryParse(all['breakMinutes'] ?? '') ?? 5,
      themeMode: domain.AppThemeMode.fromDb(all['themeMode'] ?? 'light'),
      defaultSessionMode: domain.StudySessionMode.fromDb(all['defaultSessionMode'] ?? 'pomodoro'),
      defaultBackground: all['defaultBackground'],
      overlayOpacity: double.tryParse(all['overlayOpacity'] ?? ''),
      overlayHue: int.tryParse(all['overlayHue'] ?? ''),
      displayName: all['displayName'],
      academicLevel: all['academicLevel'],
      languageCode: all['languageCode'] ?? 'en',
      aiChallengesEnabled: (all['aiChallengesEnabled'] ?? 'true') == 'true',
      groqApiKey: all['groqApiKey'],
      isFocusAudioEnabled: (all['isFocusAudioEnabled'] ?? 'true') == 'true',
      focusAudioVolume: double.tryParse(all['focusAudioVolume'] ?? '') ?? 0.4,
      // Must match INSERT seeds + _defaults opt-in semantics: absent key → off in UI.
      wifiSyncEnabled: (all['wifiSyncEnabled'] ?? 'false') == 'true',
      syncDeviceId: all['syncDeviceId'] ?? '',
    );
  }

  Future<int> getCurrentProfileId() async {
    final raw = await get('currentProfileId');
    return int.tryParse(raw ?? '1') ?? 1;
  }

  Future<void> setCurrentProfileId(int profileId) async {
    await set('currentProfileId', profileId.toString());
  }

  Future<List<domain.Profile>> listProfiles() async {
    final rows = await (_db.select(_db.profiles)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final profiles = rows
        .map(
          (row) => domain.Profile(
            id: row.id,
            syncId: row.syncId,
            name: row.name,
            academicLevel: row.academicLevel,
            ownerDeviceId: row.ownerDeviceId,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList();

    return profiles;
  }

  Future<int> createProfile(domain.Profile profile) async {
    final deviceId = await get('syncDeviceId') ?? '';
    final id = await _db.into(_db.profiles).insert(
          db.ProfilesCompanion.insert(
            syncId: profile.syncId != null ? Value(profile.syncId!) : const Value.absent(),
            name: profile.name,
            academicLevel: Value(profile.academicLevel),
            ownerDeviceId: Value(deviceId),
            updatedAt: Value(DateTime.now()),
          ),
        );
    SyncTrigger.instance.notifyWrite();
    return id;
  }

  Future<void> updateProfile(domain.Profile profile) async {
    if (profile.id == null) throw ArgumentError('Profile id required for update.');
    // Never allow updating ownerDeviceId via normal update
    await (_db.update(_db.profiles)..where((t) => t.id.equals(profile.id!))).write(
      db.ProfilesCompanion(
        name: Value(profile.name),
        academicLevel: Value(profile.academicLevel),
        updatedAt: Value(DateTime.now()),
      ),
    );
    SyncTrigger.instance.notifyWrite();
  }


  Future<({int studySessions, int subjects, int goals, int moodLogs})> getProfileDeletionStats(
    int profileId,
  ) async {
    final sessions = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM study_sessions WHERE profile_id = ?',
      variables: [Variable<int>(profileId)],
    ).getSingle();
    final subjects = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM subjects WHERE profile_id = ?',
      variables: [Variable<int>(profileId)],
    ).getSingle();
    final goals = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM goals WHERE profile_id = ?',
      variables: [Variable<int>(profileId)],
    ).getSingle();
    final moodLogs = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM mood_logs WHERE profile_id = ?',
      variables: [Variable<int>(profileId)],
    ).getSingle();
    return (
      studySessions: sessions.data['c']! as int,
      subjects: subjects.data['c']! as int,
      goals: goals.data['c']! as int,
      moodLogs: moodLogs.data['c']! as int,
    );
  }

  /// BEHAVIOR-016: hard-delete children, soft-delete profile. Default profile cannot be deleted.
  Future<void> deleteProfile(int profileId) async {
    final row = await (_db.select(_db.profiles)..where((t) => t.id.equals(profileId)))
        .getSingleOrNull();
    if (row == null) return;
    if (row.syncId == 'profile-default') {
      throw StateError('The default profile cannot be deleted.');
    }
    final others = await (_db.select(_db.profiles)..where((t) => t.deletedAt.isNull())).get();
    if (others.length <= 1) {
      throw StateError('Cannot delete the last remaining profile.');
    }
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM session_tasks WHERE session_id IN (SELECT id FROM study_sessions WHERE profile_id = ?)',
        [profileId],
      );
      await _db.customStatement('DELETE FROM mood_logs WHERE profile_id = ?', [profileId]);
      await _db.customStatement('DELETE FROM session_tasks WHERE profile_id = ?', [profileId]);
      await _db.customStatement('DELETE FROM study_sessions WHERE profile_id = ?', [profileId]);
      await _db.customStatement('DELETE FROM subjects WHERE profile_id = ?', [profileId]);
      await _db.customStatement('DELETE FROM subject_groups WHERE profile_id = ?', [profileId]);
      await _db.customStatement('DELETE FROM goals WHERE profile_id = ?', [profileId]);
      await _db.customStatement('DELETE FROM ai_challenges WHERE profile_id = ?', [profileId]);
      await (_db.update(_db.profiles)..where((t) => t.id.equals(profileId))).write(
        db.ProfilesCompanion(
          deletedAt: Value(nowIso),
          updatedAt: Value(now),
        ),
      );
    });
    final current = await getCurrentProfileId();
    if (current == profileId) {
      final remaining = await listProfiles();
      if (remaining.isNotEmpty) {
        await setCurrentProfileId(remaining.first.id!);
      }
    }
    SyncTrigger.instance.notifyWrite();
  }

}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
