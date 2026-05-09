import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// profiles table.
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().unique().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  TextColumn get academicLevel => text().withDefault(const Constant('Undergraduate'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get ownerDeviceId => text().withDefault(const Constant(''))();
}

/// study_sessions table — the core entity.
class StudySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().unique().clientDefault(() => _uuid.v4())();
  IntColumn get profileId => integer().withDefault(const Constant(1)).references(Profiles, #id)();
  TextColumn get startAt => text()();
  TextColumn get endAt => text()();
  IntColumn get durationMinutes => integer().check(durationMinutes.isBiggerThanValue(0))();
  IntColumn get subjectId => integer().nullable().references(Subjects, #id)();
  TextColumn get subjectName => text().nullable()();
  TextColumn get topic => text().nullable()();
  TextColumn get chapterTag => text().nullable()();
  TextColumn get mood => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get mode => text().check(mode.isIn(['pomodoro', 'long_session', 'manual']))();
  IntColumn get breakMinutes => integer().withDefault(const Constant(0))();
  TextColumn get backgroundImage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deletedAt => text().nullable()();
}

/// session_tasks table — tasks belong to a session.
class SessionTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().unique().clientDefault(() => _uuid.v4())();
  IntColumn get profileId => integer().withDefault(const Constant(1)).references(Profiles, #id)();
  IntColumn get sessionId => integer().references(StudySessions, #id)();
  TextColumn get title => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deletedAt => text().nullable()();
}

/// subjects table.
class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().unique().clientDefault(() => _uuid.v4())();
  IntColumn get profileId => integer().withDefault(const Constant(1)).references(Profiles, #id)();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  IntColumn get groupId => integer().nullable().references(SubjectGroups, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deletedAt => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {profileId, name},
      ];
}

/// subject_groups table.
class SubjectGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().unique().clientDefault(() => _uuid.v4())();
  IntColumn get profileId => integer().withDefault(const Constant(1)).references(Profiles, #id)();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deletedAt => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {profileId, name},
      ];
}

/// app_settings key-value table.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// goals table.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().unique().clientDefault(() => _uuid.v4())();
  IntColumn get profileId => integer().withDefault(const Constant(1)).references(Profiles, #id)();
  TextColumn get name => text()();
  IntColumn get targetMinutes => integer().check(targetMinutes.isBiggerThanValue(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deletedAt => text().nullable()();
}

/// mood_logs table.
class MoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().unique().clientDefault(() => _uuid.v4())();
  IntColumn get profileId => integer().withDefault(const Constant(1)).references(Profiles, #id)();
  IntColumn get sessionId => integer().nullable().references(StudySessions, #id)();
  TextColumn get mood => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get deletedAt => text().nullable()();
}

/// ai_challenges table.
@DataClassName('AiChallengeRow')
class AiChallenges extends Table {
  TextColumn get id => text()();
  IntColumn get profileId => integer().withDefault(const Constant(1)).references(Profiles, #id)();
  TextColumn get tier => text().check(tier.isIn(['daily', 'weekly', 'monthly', 'surprise']))();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get icon => text()();
  TextColumn get metric => text()();
  IntColumn get target => integer()();
  TextColumn get expiresAt => text()();
  TextColumn get difficulty => text()();
  TextColumn get rewardBadgeName => text()();
  TextColumn get rewardBadgeIcon => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get rawResponse => text().nullable()();
  TextColumn get subTargetsJson => text().nullable()();
  IntColumn get unitMinMinutes => integer().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('active')).check(status.isIn(['active', 'completed', 'expired', 'replaced']))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local-only closing snapshots for AI missions (never synced).
@DataClassName('AiChallengeHistoryRow')
class AiChallengeHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get tier => text().check(tier.isIn(['daily', 'weekly', 'monthly', 'surprise']))();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get metric => text()();
  IntColumn get target => integer()();
  IntColumn get progressAtClose => integer()();
  TextColumn get closeReason =>
      text().check(closeReason.isIn(['replaced', 'expired', 'completed']))();
  TextColumn get closedAt => text()();
  TextColumn get originalCreatedAt => text()();
  TextColumn get originalExpiresAt => text()();
  TextColumn get subTargetsJson => text().nullable()();
  IntColumn get unitMinMinutes => integer().nullable()();

}

/// sync_state — tracks last-sync per (peer_device_id, transport) pair.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get peerDeviceId => text()();
  TextColumn get transport => text()();
  TextColumn get lastSyncedAt => text().nullable()();
  TextColumn get lastSyncDirection => text().nullable()();
  IntColumn get lastRowCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {peerDeviceId, transport};
}

/// sync_history — log of sync events.
class SyncHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get peerDeviceId => text().nullable()();
  TextColumn get peerDeviceName => text().nullable()();
  TextColumn get transport => text()();
  TextColumn get direction => text()();
  IntColumn get rowsSent => integer().withDefault(const Constant(0))();
  IntColumn get rowsReceived => integer().withDefault(const Constant(0))();
  BoolColumn get success => boolean().withDefault(const Constant(true))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();
}

/// notification_settings — device-local, profile-scoped settings for notifications.
class NotificationSettings extends Table {
  IntColumn get profileId => integer().references(Profiles, #id).named('profile_id')();
  BoolColumn get preStudyEnabled => boolean().withDefault(const Constant(false)).named('pre_study_enabled')();
  BoolColumn get streakEnabled => boolean().withDefault(const Constant(false)).named('streak_enabled')();
  BoolColumn get weeklyEnabled => boolean().withDefault(const Constant(false)).named('weekly_enabled')();
  BoolColumn get goalEnabled => boolean().withDefault(const Constant(false)).named('goal_enabled')();
  BoolColumn get reengage3Enabled => boolean().withDefault(const Constant(false)).named('reengage_3_enabled')();
  BoolColumn get reengage7Enabled => boolean().withDefault(const Constant(false)).named('reengage_7_enabled')();
  TextColumn get slotATime => text().withDefault(const Constant('14:00')).named('slot_a_time')();
  TextColumn get quietHoursStart => text().withDefault(const Constant('22:00')).named('quiet_hours_start')();
  TextColumn get quietHoursEnd => text().withDefault(const Constant('08:00')).named('quiet_hours_end')();
  IntColumn get reengageIntervalDays => integer().withDefault(const Constant(3)).check(reengageIntervalDays.isBiggerThanValue(0)).named('reengage_interval_days')();
  IntColumn get reengageHour => integer().withDefault(const Constant(14)).check(reengageHour.isBetweenValues(0, 23)).named('reengage_hour')();
  // Added in later migrations: explicit per-slot HH:mm fields
  TextColumn get preStudyTime => text().withDefault(const Constant('14:00')).named('pre_study_time')();
  TextColumn get weeklySummaryTime => text().withDefault(const Constant('19:00')).named('weekly_summary_time')();
  IntColumn get weeklySummaryDow => integer().withDefault(const Constant(7)).check(weeklySummaryDow.isBetweenValues(1, 7)).named('weekly_summary_dow')();
  IntColumn get goalDow => integer().withDefault(const Constant(3)).named('goal_dow')();
  TextColumn get goalTime => text().withDefault(const Constant('19:00')).named('goal_time')();
  TextColumn get reengageTime => text().withDefault(const Constant('14:00')).named('reengage_time')();
  /// ISO-8601 string (matches raw SQL / CURRENT_TIMESTAMP text affinity — not epoch millis).
  TextColumn get updatedAt =>
      text().withDefault(const Constant('1970-01-01T00:00:00.000Z')).named('updated_at')();

  @override
  Set<Column> get primaryKey => {profileId};
}

/// notification_log — record of notification decisions and outcomes.
class NotificationLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id).named('profile_id')();
  IntColumn get notificationId => integer().named('notification_id')();
  TextColumn get outcome => text().check(outcome.isIn(['fired', 'suppressed']))();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
}

/// ai_feature_settings — toggles for device-local AI features per profile.
class AiFeatureSettings extends Table {
  IntColumn get profileId => integer().references(Profiles, #id).named('profile_id')();
  BoolColumn get featChallengeAi => boolean().withDefault(const Constant(false)).named('feat_challenge_ai')();
  BoolColumn get featSessionInsights => boolean().withDefault(const Constant(false)).named('feat_session_insights')();
  BoolColumn get featStudyPlanner => boolean().withDefault(const Constant(false)).named('feat_study_planner')();
  BoolColumn get featMotivation => boolean().withDefault(const Constant(false)).named('feat_motivation')();
  BoolColumn get featWeeklyReview => boolean().withDefault(const Constant(false)).named('feat_weekly_review')();
  // Additional toggles added later
  BoolColumn get coachEnabled => boolean().withDefault(const Constant(false)).named('coach_enabled')();
  BoolColumn get smartChallengesEnabled => boolean().withDefault(const Constant(false)).named('smart_challenges_enabled')();
  BoolColumn get debriefEnabled => boolean().withDefault(const Constant(false)).named('debrief_enabled')();
  BoolColumn get weeklyNarrativeEnabled => boolean().withDefault(const Constant(false)).named('weekly_narrative_enabled')();
  BoolColumn get subjectDifficultyEnabled => boolean().withDefault(const Constant(false)).named('subject_difficulty_enabled')();
  BoolColumn get surpriseNotificationsEnabled =>
      boolean().withDefault(const Constant(false)).named('surprise_notifications_enabled')();
  IntColumn get surpriseCheckIntervalHours =>
      integer().withDefault(const Constant(3)).named('surprise_check_interval_hours')();
  /// ISO-8601 string for rows written via raw SQL / INSERT OR REPLACE.
  TextColumn get updatedAt =>
      text().withDefault(const Constant('1970-01-01T00:00:00.000Z')).named('updated_at')();

  @override
  Set<Column> get primaryKey => {profileId};
}

/// ai_cache — simple device-local cache keyed by (profile, feature, cacheKey)
class AiCache extends Table {
  IntColumn get profileId => integer().references(Profiles, #id).named('profile_id')();
  TextColumn get feature => text()();
  TextColumn get cacheKey => text().named('cache_key')();
  TextColumn get payloadJson => text().named('payload_json')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {profileId, feature, cacheKey};
}
