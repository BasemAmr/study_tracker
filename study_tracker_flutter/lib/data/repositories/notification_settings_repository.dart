import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../db/database.dart' as db;
import '../db/database_provider.dart';

class NotificationSettingsRepository {
  final db.AppDatabase _db;

  NotificationSettingsRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '1') ?? 1;
  }

  Future<Map<String, dynamic>?> getSettings() async {
    final profileId = await _activeProfileId();
    final result = await _db.customSelect(
      'SELECT * FROM notification_settings WHERE profile_id = ? LIMIT 1',
      variables: [drift.Variable(profileId)],
    ).getSingleOrNull();
    return result?.data;
  }

  Stream<Map<String, dynamic>?> watchSettings() {
    final profileStream = _db.select(_db.appSettings)..where((t) => t.key.equals('currentProfileId'));
    return profileStream
        .watchSingleOrNull()
        .map((row) => int.tryParse(row?.value ?? '1') ?? 1)
        .distinct()
        .asyncExpand((profileId) => _db
            .customSelect('SELECT * FROM notification_settings WHERE profile_id = ? LIMIT 1',
                variables: [drift.Variable(profileId)], readsFrom: {_db.notificationSettings})
            .watch()
            .map((rows) => rows.isEmpty ? null : rows.first.data));
  }

  /// Merge partial updates with the existing row so toggles do not NULL out other columns.
  Future<void> upsertSettings(Map<String, Object?> values) async {
    if (values.isEmpty) return;
    final profileId = await _activeProfileId();
    final existing = await (_db.select(_db.notificationSettings)..where((t) => t.profileId.equals(profileId))).getSingleOrNull();

    bool mergedBool(String snakeKey, bool prior) {
      if (!values.containsKey(snakeKey)) return prior;
      return _coerceBool(values[snakeKey], prior);
    }

    String mergedString(String snakeKey, String prior) {
      if (!values.containsKey(snakeKey)) return prior;
      return values[snakeKey]?.toString() ?? prior;
    }

    int mergedInt(String snakeKey, int prior) {
      if (!values.containsKey(snakeKey)) return prior;
      final val = values[snakeKey];
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? prior;
      return prior;
    }

    final next = db.NotificationSetting(
      profileId: profileId,
      preStudyEnabled: mergedBool('pre_study_enabled', existing?.preStudyEnabled ?? false),
      streakEnabled: mergedBool('streak_enabled', existing?.streakEnabled ?? false),
      weeklyEnabled: mergedBool('weekly_enabled', existing?.weeklyEnabled ?? false),
      goalEnabled: mergedBool('goal_enabled', existing?.goalEnabled ?? false),
      reengage3Enabled: mergedBool('reengage_3_enabled', existing?.reengage3Enabled ?? false),
      reengage7Enabled: mergedBool('reengage_7_enabled', existing?.reengage7Enabled ?? false),
      slotATime: mergedString('slot_a_time', existing?.slotATime ?? '14:00'),
      quietHoursStart: mergedString('quiet_hours_start', existing?.quietHoursStart ?? '22:00'),
      quietHoursEnd: mergedString('quiet_hours_end', existing?.quietHoursEnd ?? '08:00'),
      reengageIntervalDays: mergedInt('reengage_interval_days', existing?.reengageIntervalDays ?? 3),
      reengageHour: mergedInt('reengage_hour', existing?.reengageHour ?? 14),
      preStudyTime: mergedString('pre_study_time', existing?.preStudyTime ?? '14:00'),
      weeklySummaryTime: mergedString('weekly_summary_time', existing?.weeklySummaryTime ?? '19:00'),
      weeklySummaryDow: mergedInt('weekly_summary_dow', existing?.weeklySummaryDow ?? 7),
      goalDow: mergedInt('goal_dow', existing?.goalDow ?? 3),
      goalTime: mergedString('goal_time', existing?.goalTime ?? '19:00'),
      reengageTime: mergedString('reengage_time', existing?.reengageTime ?? '14:00'),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _db.into(_db.notificationSettings).insertOnConflictUpdate(
      db.NotificationSettingsCompanion(
        profileId: drift.Value(next.profileId),
        preStudyEnabled: drift.Value(next.preStudyEnabled),
        streakEnabled: drift.Value(next.streakEnabled),
        weeklyEnabled: drift.Value(next.weeklyEnabled),
        goalEnabled: drift.Value(next.goalEnabled),
        reengage3Enabled: drift.Value(next.reengage3Enabled),
        reengage7Enabled: drift.Value(next.reengage7Enabled),
        slotATime: drift.Value(next.slotATime),
        quietHoursStart: drift.Value(next.quietHoursStart),
        quietHoursEnd: drift.Value(next.quietHoursEnd),
        reengageIntervalDays: drift.Value(next.reengageIntervalDays),
        reengageHour: drift.Value(next.reengageHour),
        preStudyTime: drift.Value(next.preStudyTime),
        weeklySummaryTime: drift.Value(next.weeklySummaryTime),
        weeklySummaryDow: drift.Value(next.weeklySummaryDow),
        goalDow: drift.Value(next.goalDow),
        goalTime: drift.Value(next.goalTime),
        reengageTime: drift.Value(next.reengageTime),
        updatedAt: drift.Value(next.updatedAt),
      ),
    );
  }

  static bool _coerceBool(Object? v, bool fallback) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return fallback;
  }
}

final notificationSettingsRepositoryProvider = Provider<NotificationSettingsRepository>(
  (ref) => NotificationSettingsRepository(ref.watch(databaseProvider)),
);
