import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../db/database.dart' as db;
import '../db/database_provider.dart';

class AiFeatureSettingsRepository {
  final db.AppDatabase _db;

  AiFeatureSettingsRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '1') ?? 1;
  }

  Future<Map<String, dynamic>?> getSettings() async {
    final profileId = await _activeProfileId();
    final result = await _db.customSelect(
      'SELECT * FROM ai_feature_settings WHERE profile_id = ? LIMIT 1',
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
            .customSelect('SELECT * FROM ai_feature_settings WHERE profile_id = ? LIMIT 1',
                variables: [drift.Variable(profileId)], readsFrom: {_db.aiFeatureSettings})
            .watch()
            .map((rows) => rows.isEmpty ? null : rows.first.data));
  }

  /// Merge partial updates with the existing row so toggles do not NULL out other columns.
  Future<void> upsertSettings(Map<String, Object?> values) async {
    if (values.isEmpty) return;
    final profileId = await _activeProfileId();
    final existing = await (_db.select(_db.aiFeatureSettings)..where((t) => t.profileId.equals(profileId))).getSingleOrNull();

    bool merged(String snakeKey, bool prior) {
      if (!values.containsKey(snakeKey)) return prior;
      return _coerceBool(values[snakeKey], prior);
    }

    int mergedPositiveHours(String snakeKey, int prior) {
      if (!values.containsKey(snakeKey)) return prior;
      final v = values[snakeKey];
      if (v is int) return v > 0 ? v : prior;
      if (v is num) {
        final n = v.toInt();
        return n > 0 ? n : prior;
      }
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null && n > 0) return n;
      }
      return prior;
    }

    final next = db.AiFeatureSetting(
      profileId: profileId,
      featChallengeAi: merged('feat_challenge_ai', existing?.featChallengeAi ?? false),
      featSessionInsights: merged('feat_session_insights', existing?.featSessionInsights ?? false),
      featStudyPlanner: merged('feat_study_planner', existing?.featStudyPlanner ?? false),
      featMotivation: merged('feat_motivation', existing?.featMotivation ?? false),
      featWeeklyReview: merged('feat_weekly_review', existing?.featWeeklyReview ?? false),
      coachEnabled: merged('coach_enabled', existing?.coachEnabled ?? false),
      smartChallengesEnabled: merged('smart_challenges_enabled', existing?.smartChallengesEnabled ?? false),
      debriefEnabled: merged('debrief_enabled', existing?.debriefEnabled ?? false),
      weeklyNarrativeEnabled: merged('weekly_narrative_enabled', existing?.weeklyNarrativeEnabled ?? false),
      subjectDifficultyEnabled: merged('subject_difficulty_enabled', existing?.subjectDifficultyEnabled ?? false),
      surpriseNotificationsEnabled:
          merged('surprise_notifications_enabled', existing?.surpriseNotificationsEnabled ?? false),
      surpriseCheckIntervalHours: mergedPositiveHours(
        'surprise_check_interval_hours',
        existing?.surpriseCheckIntervalHours ?? 3,
      ),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _db.into(_db.aiFeatureSettings).insertOnConflictUpdate(
      db.AiFeatureSettingsCompanion(
        profileId: drift.Value(next.profileId),
        featChallengeAi: drift.Value(next.featChallengeAi),
        featSessionInsights: drift.Value(next.featSessionInsights),
        featStudyPlanner: drift.Value(next.featStudyPlanner),
        featMotivation: drift.Value(next.featMotivation),
        featWeeklyReview: drift.Value(next.featWeeklyReview),
        coachEnabled: drift.Value(next.coachEnabled),
        smartChallengesEnabled: drift.Value(next.smartChallengesEnabled),
        debriefEnabled: drift.Value(next.debriefEnabled),
        weeklyNarrativeEnabled: drift.Value(next.weeklyNarrativeEnabled),
        subjectDifficultyEnabled: drift.Value(next.subjectDifficultyEnabled),
        surpriseNotificationsEnabled: drift.Value(next.surpriseNotificationsEnabled),
        surpriseCheckIntervalHours: drift.Value(next.surpriseCheckIntervalHours),
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

final aiFeatureSettingsRepositoryProvider = Provider<AiFeatureSettingsRepository>(
  (ref) => AiFeatureSettingsRepository(ref.watch(databaseProvider)),
);
