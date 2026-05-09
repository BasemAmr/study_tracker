import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart' as db;
import '../db/database_provider.dart';
import '../../domain/domain.dart' as domain;
import '../../core/sync/sync_trigger.dart';


/// Subject and SubjectGroup repository.
class SubjectRepository {
  final db.AppDatabase _db;
  List<domain.Subject>? _subjectsCache;
  List<domain.SubjectGroup>? _groupsCache;
  int? _cachedProfileId;

  SubjectRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    final profileId = int.tryParse(row?.value ?? '1') ?? 1;
    if (_cachedProfileId != profileId) {
      _cachedProfileId = profileId;
      _invalidateCache();
    }
    return profileId;
  }

  void _invalidateCache() {
    _subjectsCache = null;
    _groupsCache = null;
  }

  void clearLocalCache() {
    _invalidateCache();
  }

  // ── Subjects ────────────────────────────────────────────────────

  Future<List<domain.Subject>> listAll() async {
    await _activeProfileId();
    if (_subjectsCache != null) return _subjectsCache!;
    final profileId = _cachedProfileId ?? 1;
    final rows = await (_db.select(_db.subjects)..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).get();
    final mapped = rows.map(_mapSubject).toList();
    _subjectsCache = mapped;
    return mapped;
  }

  Stream<List<domain.Subject>> watchAll() {
    final profile = _db.select(_db.appSettings)..where((t) => t.key.equals('currentProfileId'));
    return profile
        .watchSingleOrNull()
        .map((row) => int.tryParse(row?.value ?? '1') ?? 1)
        .distinct()
        .asyncExpand((profileId) {
      return (_db.select(_db.subjects)..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull()))
          .watch()
          .map((rows) => rows.map(_mapSubject).toList());
    });
  }

  Stream<List<domain.SubjectGroup>> watchGroups() {
    final profile = _db.select(_db.appSettings)..where((t) => t.key.equals('currentProfileId'));
    return profile
        .watchSingleOrNull()
        .map((row) => int.tryParse(row?.value ?? '1') ?? 1)
        .distinct()
        .asyncExpand((profileId) {
      return (_db.select(_db.subjectGroups)..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull()))
          .watch()
          .map((rows) => rows.map(_mapGroup).toList());
    });
  }

  Future<domain.Subject?> getById(int id) async {
    final profileId = await _activeProfileId();
    final row = await (_db.select(_db.subjects)
          ..where((t) => t.id.equals(id) & t.profileId.equals(profileId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _mapSubject(row);
  }

  Future<int> createSubject(domain.Subject subject) async {
    final profileId = await _activeProfileId();
    final id = await _db.into(_db.subjects).insert(
          db.SubjectsCompanion.insert(
            profileId: Value(profileId),
            name: subject.name,
            color: Value(subject.color),
            groupId: Value(subject.groupId),
            updatedAt: Value(DateTime.now()),
          ),
        );
    _invalidateCache();
    SyncTrigger.instance.notifyWrite();
    return id;

  }

  Future<void> updateSubject(domain.Subject subject) async {
    if (subject.id == null) throw ArgumentError('Subject id required.');
    final profileId = await _activeProfileId();
    await (_db.update(_db.subjects)
          ..where((t) => t.id.equals(subject.id!) & t.profileId.equals(profileId)))
        .write(db.SubjectsCompanion(
      name: Value(subject.name),
      color: Value(subject.color),
      groupId: Value(subject.groupId),
      updatedAt: Value(DateTime.now()),
    ));
    _invalidateCache();
    SyncTrigger.instance.notifyWrite();
  }


  Future<void> deleteSubject(int id) async {
    final profileId = await _activeProfileId();
    await (_db.update(_db.subjects)..where((t) => t.id.equals(id) & t.profileId.equals(profileId)))
        .write(db.SubjectsCompanion(
          deletedAt: Value(DateTime.now().toUtc().toIso8601String()),
          updatedAt: Value(DateTime.now()),
        ));
    _invalidateCache();
    SyncTrigger.instance.notifyWrite();
  }


  // ── Groups ──────────────────────────────────────────────────────

  Future<List<domain.SubjectGroup>> listGroups() async {
    await _activeProfileId();
    if (_groupsCache != null) return _groupsCache!;
    final profileId = _cachedProfileId ?? 1;
    final rows = await (_db.select(_db.subjectGroups)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull()))
        .get();
    final mapped = rows.map(_mapGroup).toList();
    _groupsCache = mapped;
    return mapped;
  }

  Future<int> createGroup(domain.SubjectGroup group) async {
    final profileId = await _activeProfileId();
    final id = await _db.into(_db.subjectGroups).insert(
          db.SubjectGroupsCompanion.insert(
            profileId: Value(profileId),
            name: group.name,
            color: Value(group.color),
            updatedAt: Value(DateTime.now()),
          ),
        );
    _invalidateCache();
    SyncTrigger.instance.notifyWrite();
    return id;

  }

  Future<void> deleteGroup(int id) async {
    final profileId = await _activeProfileId();
    await (_db.update(_db.subjectGroups)
          ..where((t) => t.id.equals(id) & t.profileId.equals(profileId)))
        .write(db.SubjectGroupsCompanion(
          deletedAt: Value(DateTime.now().toUtc().toIso8601String()),
          updatedAt: Value(DateTime.now()),
        ));
    _invalidateCache();
    SyncTrigger.instance.notifyWrite();
  }


  Future<void> updateGroup(domain.SubjectGroup group) async {
    if (group.id == null) throw ArgumentError('SubjectGroup id required.');
    final profileId = await _activeProfileId();
    await (_db.update(_db.subjectGroups)
          ..where((t) => t.id.equals(group.id!) & t.profileId.equals(profileId)))
        .write(db.SubjectGroupsCompanion(
      name: Value(group.name),
      color: Value(group.color),
      updatedAt: Value(DateTime.now()),
    ));
    _invalidateCache();
    SyncTrigger.instance.notifyWrite();
  }


  // ── Grouped ─────────────────────────────────────────────────────

  Future<List<domain.GroupedSubjects>> listGrouped() async {
    final subjects = await listAll();
    final groups = await listGroups();

    final ungrouped = subjects.where((s) => s.groupId == null).toList();
    final byGroup = <int, List<domain.Subject>>{};
    for (final s in subjects) {
      if (s.groupId != null) {
        byGroup.putIfAbsent(s.groupId!, () => []).add(s);
      }
    }

    final result = <domain.GroupedSubjects>[];
    if (ungrouped.isNotEmpty) {
      result.add(domain.GroupedSubjects(subjects: ungrouped));
    }
    for (final g in groups) {
      result.add(domain.GroupedSubjects(
        group: g,
        subjects: byGroup[g.id!] ?? [],
      ));
    }
    return result;
  }

  // ── Mappers ─────────────────────────────────────────────────────

  domain.Subject _mapSubject(db.Subject row) => domain.Subject(
        id: row.id,
        name: row.name,
        color: row.color,
        groupId: row.groupId,
        createdAt: row.createdAt,
      );

  domain.SubjectGroup _mapGroup(db.SubjectGroup row) => domain.SubjectGroup(
        id: row.id,
        name: row.name,
        color: row.color,
        createdAt: row.createdAt,
      );
}

final subjectRepositoryProvider = Provider<SubjectRepository>(
  (ref) => SubjectRepository(ref.watch(databaseProvider)),
);
