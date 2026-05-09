import 'package:drift/drift.dart';
import '../db/database.dart' as db;
import '../db/database_provider.dart';
import '../../domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/sync_trigger.dart';


/// Session repository — all CRUD and query operations for study_sessions.
class SessionRepository {
  final db.AppDatabase _db;
  List<domain.StudySession>? _allSessionsCache;
  domain.SessionSummary? _summaryCache;
  final Map<int, List<domain.StudySession>> _recentCache = {};
  int? _cachedProfileId;

  SessionRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    final profileId = int.tryParse(row?.value ?? '1') ?? 1;
    if (_cachedProfileId != profileId) {
      _cachedProfileId = profileId;
      _invalidateCaches();
    }
    return profileId;
  }

  void _invalidateCaches() {
    _allSessionsCache = null;
    _summaryCache = null;
    _recentCache.clear();
  }

  void clearLocalCache() {
    _invalidateCaches();
  }

  // ── Validation ──────────────────────────────────────────────────

  void _validate(domain.StudySession session) {
    if (session.startAt.isAfter(session.endAt)) {
      throw ArgumentError('startAt must be before endAt.');
    }
    if (session.durationMinutes <= 0) {
      throw ArgumentError('durationMinutes must be positive.');
    }
  }

  // ── Create ──────────────────────────────────────────────────────

  Future<int> create(domain.StudySession session) async {
    _validate(session);
    final profileId = await _activeProfileId();
    final id = await _db.into(_db.studySessions).insert(
          db.StudySessionsCompanion.insert(
            profileId: Value(profileId),
            startAt: session.startAt.toIso8601String(),
            endAt: session.endAt.toIso8601String(),
            durationMinutes: session.durationMinutes,
            subjectId: Value(session.subjectId),
            subjectName: Value(session.subjectName),
            topic: Value(session.topic),
            chapterTag: Value(session.chapterTag),
            mood: Value(session.mood),
            notes: Value(session.notes),
            mode: session.mode.dbValue,
            breakMinutes: Value(session.breakMinutes),
            backgroundImage: Value(session.backgroundImage),
            updatedAt: Value(DateTime.now()),
          ),
        );
    // Insert tasks if any
    for (final task in session.tasks) {
      await _db.into(_db.sessionTasks).insert(
            db.SessionTasksCompanion.insert(
              profileId: Value(profileId),
              sessionId: id,
              title: task.title,
              completed: Value(task.completed),
            ),
          );
    }
    _invalidateCaches();
    SyncTrigger.instance.notifyWrite();
    return id;

  }

  // ── Update ──────────────────────────────────────────────────────

  Future<void> update(domain.StudySession session) async {
    if (session.id == null) throw ArgumentError('Session id required for update.');
    _validate(session);
        final profileId = await _activeProfileId();
    await (_db.update(_db.studySessions)
          ..where((t) => t.id.equals(session.id!) & t.profileId.equals(profileId)))
        .write(db.StudySessionsCompanion(
          startAt: Value(session.startAt.toIso8601String()),
          endAt: Value(session.endAt.toIso8601String()),
      durationMinutes: Value(session.durationMinutes),
      subjectId: Value(session.subjectId),
      subjectName: Value(session.subjectName),
      topic: Value(session.topic),
      chapterTag: Value(session.chapterTag),
      mood: Value(session.mood),
      notes: Value(session.notes),
      mode: Value(session.mode.dbValue),
      breakMinutes: Value(session.breakMinutes),
      backgroundImage: Value(session.backgroundImage),
      updatedAt: Value(DateTime.now()),
    ));
    _invalidateCaches();
    SyncTrigger.instance.notifyWrite();
  }


  // ── Delete ──────────────────────────────────────────────────────

  Future<void> delete(int id) async {
    final profileId = await _activeProfileId();
    await (_db.update(_db.studySessions)
          ..where((t) => t.id.equals(id) & t.profileId.equals(profileId)))
        .write(db.StudySessionsCompanion(
          deletedAt: Value(DateTime.now().toUtc().toIso8601String()),
          updatedAt: Value(DateTime.now()),
        ));
    _invalidateCaches();
    SyncTrigger.instance.notifyWrite();
  }


  // ── Read ────────────────────────────────────────────────────────

  Future<domain.StudySession?> getById(int id) async {
    final profileId = await _activeProfileId();
    final row = await (_db.select(_db.studySessions)
          ..where((t) => t.id.equals(id) & t.profileId.equals(profileId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) return null;
    final tasks = await _getTasksForSession(id);
    return _mapRow(row, tasks);
  }

  /// Fetch sessions with optional filter.
  Future<List<domain.StudySession>> list(domain.SessionFilter filter) async {
    final profileId = await _activeProfileId();
    final isUnfiltered = filter.subjectId == null &&
        filter.groupId == null &&
        filter.mode == null &&
        filter.startFrom == null &&
        filter.startTo == null &&
        (filter.query == null || filter.query!.isEmpty) &&
        filter.offset == 0;

    if (isUnfiltered) {
      if (filter.limit >= 9999 && _allSessionsCache != null) {
        return _allSessionsCache!;
      }
      final recentCached = _recentCache[filter.limit];
      if (recentCached != null) {
        return recentCached;
      }
    }

    List<int>? groupSubjectIds;
    if (filter.groupId != null) {
      final groupRows = await (_db.select(_db.subjects)
        ..where((s) => s.groupId.equals(filter.groupId!) & s.profileId.equals(profileId)))
          .get();
      groupSubjectIds = groupRows.map((e) => e.id).toList();
      if (groupSubjectIds.isEmpty) {
        return const [];
      }
    }

    var query = _db.select(_db.studySessions);
    query = query
      ..where((t) {
        Expression<bool> expr = const Constant(true);
        expr = expr & t.profileId.equals(profileId) & t.deletedAt.isNull();
        if (filter.subjectId != null) {
          expr = expr & t.subjectId.equals(filter.subjectId!);
        }
        if (groupSubjectIds != null) {
          expr = expr & t.subjectId.isIn(groupSubjectIds);
        }
        if (filter.mode != null) {
          expr = expr & t.mode.equals(filter.mode!.dbValue);
        }
        if (filter.startFrom != null) {
          expr = expr &
              t.startAt.isBiggerOrEqualValue(filter.startFrom!.toIso8601String());
        }
        if (filter.startTo != null) {
          expr = expr &
              t.startAt.isSmallerOrEqualValue(filter.startTo!.toIso8601String());
        }
        if (filter.query != null && filter.query!.isNotEmpty) {
          final q = '%${filter.query}%';
          expr = expr &
              (t.subjectName.like(q) | t.topic.like(q) | t.notes.like(q));
        }
        return expr;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
      ..limit(filter.limit, offset: filter.offset);

    final rows = await query.get();
    final mapped = rows.map((r) => _mapRow(r, const [])).toList();

    if (isUnfiltered) {
      if (filter.limit >= 9999) {
        _allSessionsCache = mapped;
      } else {
        _recentCache[filter.limit] = mapped;
      }
    }

    return mapped;
  }

    Future<List<domain.StudySession>> getRecent(int limit) =>
      list(domain.SessionFilter(limit: limit));

  /// Summary stats — total sessions, total minutes, average, recent.
  Future<domain.SessionSummary> getSummary() async {
    final profileId = await _activeProfileId();
    if (_summaryCache != null) return _summaryCache!;

    final result = await _db.customSelect(
      'SELECT COUNT(*) AS total_sessions, '
      'COALESCE(SUM(duration_minutes), 0) AS total_minutes, '
      'COALESCE(AVG(duration_minutes), 0) AS average_minutes '
      'FROM study_sessions WHERE profile_id = ? AND deleted_at IS NULL',
      variables: [Variable.withInt(profileId)],
    ).getSingle();
    final recent = await getRecent(5);
    final summary = domain.SessionSummary(
      totalSessions: result.data['total_sessions'] as int,
      totalMinutes: result.data['total_minutes'] as int,
      averageMinutes: (result.data['average_minutes'] as num).toDouble(),
      recentSessions: recent,
    );
    _summaryCache = summary;
    return summary;
  }

  /// Summary stats for the last 7 days only.
  Future<domain.SessionSummary> getSummaryLast7Days() async {
    final profileId = await _activeProfileId();
    final now = DateTime.now();
    final cutoffDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final cutoff = cutoffDate.toIso8601String();
    final result = await _db.customSelect(
      'SELECT COUNT(*) AS total_sessions, '
      'COALESCE(SUM(duration_minutes), 0) AS total_minutes, '
      'COALESCE(AVG(duration_minutes), 0) AS average_minutes '
      'FROM study_sessions '
      'WHERE profile_id = ? AND deleted_at IS NULL AND start_at >= ?',
      variables: [Variable<int>(profileId), Variable<String>(cutoff)],
    ).getSingle();
    final recent = await list(domain.SessionFilter(limit: 5, startFrom: cutoffDate));
    return domain.SessionSummary(
      totalSessions: result.data['total_sessions'] as int,
      totalMinutes: result.data['total_minutes'] as int,
      averageMinutes: (result.data['average_minutes'] as num).toDouble(),
      recentSessions: recent,
    );
  }

  /// Current study streak (consecutive days with sessions).
  Future<int> getCurrentStreak({DateTime? now}) async {
    final profileId = await _activeProfileId();
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(const Duration(days: 90)).toIso8601String();
    final rows = await _db.customSelect(
      'SELECT date(start_at) AS study_day '
      'FROM study_sessions '
      'WHERE profile_id = ? AND deleted_at IS NULL AND start_at >= ? '
      'GROUP BY study_day '
      'ORDER BY study_day DESC',
      variables: [Variable<int>(profileId), Variable<String>(cutoff)],
    ).get();

    if (rows.isEmpty) return 0;

    final days = rows
        .map((row) => DateTime.parse(row.data['study_day'] as String))
        .toList();

    DateTime cursor = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
    final hasToday = days.any((d) => _isSameDay(d, cursor));
    if (!hasToday) cursor = cursor.subtract(const Duration(days: 1));

    var streak = 0;
    while (days.any((d) => _isSameDay(d, cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Most-studied subject over the last 7 days (by total minutes).
  Future<String?> getMostStudiedSubjectLast7Days() async {
    final profileId = await _activeProfileId();
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)).toIso8601String();
    final result = await _db.customSelect(
      'SELECT subject_name, COALESCE(SUM(duration_minutes), 0) AS total_minutes '
      'FROM study_sessions '
      'WHERE profile_id = ? AND deleted_at IS NULL '
      'AND subject_name IS NOT NULL AND subject_name != \'\' '
      'AND start_at >= ? '
      'GROUP BY subject_name '
      'ORDER BY total_minutes DESC '
      'LIMIT 1',
      variables: [Variable<int>(profileId), Variable<String>(cutoff)],
    ).getSingleOrNull();

    return result?.data['subject_name'] as String?;
  }

  /// Total study minutes from Monday 00:00 through now (for goal progress calculation).
  Future<int> getTotalMinutesThisWeek() async {
    final profileId = await _activeProfileId();
    final now = DateTime.now();
    // Monday = 1, Sunday = 7; calculate Monday of this week at 00:00
    final dayOfWeek = now.weekday; // 1=Mon, 7=Sun
    final mondayThisWeek = now.subtract(Duration(days: dayOfWeek - 1));
    final mondayStart = DateTime(mondayThisWeek.year, mondayThisWeek.month, mondayThisWeek.day);
    final cutoff = mondayStart.toIso8601String();
    
    final result = await _db.customSelect(
      'SELECT COALESCE(SUM(duration_minutes), 0) AS total_minutes '
      'FROM study_sessions '
      'WHERE profile_id = ? AND deleted_at IS NULL AND start_at >= ?',
      variables: [Variable<int>(profileId), Variable<String>(cutoff)],
    ).getSingle();
    
    return result.data['total_minutes'] as int;
  }

  /// Most recent session's start date/time, or null if no sessions.
  Future<DateTime?> getLastSessionDate() async {
    final profileId = await _activeProfileId();
    final result = await _db.customSelect(
      'SELECT start_at FROM study_sessions '
      'WHERE profile_id = ? AND deleted_at IS NULL '
      'ORDER BY start_at DESC LIMIT 1',
      variables: [Variable<int>(profileId)],
    ).getSingleOrNull();
    
    if (result == null) return null;
    return DateTime.parse(result.data['start_at'] as String);
  }

  /// Elapsed days in current week (1 = Monday, 7 = Sunday).
  /// Used for goal progress pace calculation.
  int getElapsedDaysThisWeek({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    // weekday: 1=Mon, 7=Sun. We count Mon as 1, Sun as 7.
    return effectiveNow.weekday;
  }

  Stream<List<domain.StudySession>> watchAllSessions() {
    final profile = _db.select(_db.appSettings)..where((t) => t.key.equals('currentProfileId'));
    return profile
        .watchSingleOrNull()
        .map((row) => int.tryParse(row?.value ?? '1') ?? 1)
        .distinct()
        .asyncExpand((profileId) {
      final query = _db.select(_db.studySessions)
        ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startAt)]);
      return query.watch().map((rows) => rows.map((r) => _mapRow(r, const [])).toList());
    });
  }

  Stream<List<domain.StudySession>> watchList(domain.SessionFilter filter) {
    final profile = _db.select(_db.appSettings)..where((t) => t.key.equals('currentProfileId'));
    return profile
        .watchSingleOrNull()
        .map((row) => int.tryParse(row?.value ?? '1') ?? 1)
        .distinct()
        .asyncExpand((profileId) {
      var query = _db.select(_db.studySessions);
      query = query
        ..where((t) {
          Expression<bool> expr = const Constant(true);
          expr = expr & t.profileId.equals(profileId) & t.deletedAt.isNull();
          if (filter.subjectId != null) {
            expr = expr & t.subjectId.equals(filter.subjectId!);
          }
          if (filter.mode != null) {
            expr = expr & t.mode.equals(filter.mode!.dbValue);
          }
          if (filter.startFrom != null) {
            expr = expr & t.startAt.isBiggerOrEqualValue(filter.startFrom!.toIso8601String());
          }
          if (filter.startTo != null) {
            expr = expr & t.startAt.isSmallerOrEqualValue(filter.startTo!.toIso8601String());
          }
          if (filter.query != null && filter.query!.isNotEmpty) {
            final q = '%${filter.query}%';
            expr = expr & (t.subjectName.like(q) | t.topic.like(q) | t.notes.like(q));
          }
          return expr;
        })
        ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
        ..limit(filter.limit, offset: filter.offset);

      return query.watch().map((rows) => rows.map((r) => _mapRow(r, const [])).toList());
    });
  }

  Stream<List<domain.StudySession>> watchRecentSessions(int limit) {
    final profile = _db.select(_db.appSettings)..where((t) => t.key.equals('currentProfileId'));
    return profile
        .watchSingleOrNull()
        .map((row) => int.tryParse(row?.value ?? '1') ?? 1)
        .distinct()
        .asyncExpand((profileId) {
      final query = _db.select(_db.studySessions)
        ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
        ..limit(limit);
      return query.watch().map((rows) => rows.map((r) => _mapRow(r, const [])).toList());
    });
  }

  Stream<domain.SessionSummary> watchTodaySummary() {
    return watchAllSessions().map((sessions) {
      final totalSessions = sessions.length;
      final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final averageMinutes = totalSessions == 0 ? 0.0 : totalMinutes / totalSessions;
      final recentSessions = sessions.take(5).toList();

      return domain.SessionSummary(
        totalSessions: totalSessions,
        totalMinutes: totalMinutes,
        averageMinutes: averageMinutes,
        recentSessions: recentSessions,
      );
    });
  }

  /// All sessions for analytics (no limit).
    Future<List<domain.StudySession>> getAll() =>
      list(const domain.SessionFilter(limit: 9999));

  // ── Helpers ─────────────────────────────────────────────────────

  Future<List<domain.SessionTask>> _getTasksForSession(int sessionId) async {
    final profileId = await _activeProfileId();
    final rows = await (_db.select(_db.sessionTasks)
          ..where((t) => t.sessionId.equals(sessionId) & t.profileId.equals(profileId)))
        .get();
    return rows.map(_mapTaskRow).toList();
  }

  /// Batch-load tasks for many sessions (e.g. AI analytics over a window).
  Future<Map<int, List<domain.SessionTask>>> tasksBySessionIds(Iterable<int> sessionIds) async {
    final ids = sessionIds.toSet().toList();
    if (ids.isEmpty) return {};
    final profileId = await _activeProfileId();
    final rows = await (_db.select(_db.sessionTasks)
          ..where((t) => t.profileId.equals(profileId) & t.sessionId.isIn(ids)))
        .get();
    final map = <int, List<domain.SessionTask>>{};
    for (final r in rows) {
      map.putIfAbsent(r.sessionId, () => []).add(_mapTaskRow(r));
    }
    return map;
  }

  domain.StudySession _mapRow(db.StudySession row, List<domain.SessionTask> tasks) {
    return domain.StudySession(
      id: row.id,
      startAt: DateTime.parse(row.startAt),
      endAt: DateTime.parse(row.endAt),
      durationMinutes: row.durationMinutes,
      subjectId: row.subjectId,
      subjectName: row.subjectName,
      topic: row.topic,
      chapterTag: row.chapterTag,
      mood: row.mood,
      notes: row.notes,
      mode: domain.StudySessionMode.fromDb(row.mode),
      breakMinutes: row.breakMinutes,
      backgroundImage: row.backgroundImage,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      tasks: tasks,
    );
  }

  domain.SessionTask _mapTaskRow(db.SessionTask row) {
    return domain.SessionTask(
      id: row.id,
      sessionId: row.sessionId,
      title: row.title,
      completed: row.completed,
      createdAt: row.createdAt,
    );
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);
