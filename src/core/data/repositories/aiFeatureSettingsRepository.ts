import { getDatabase } from '../database';

export type AiFeatureSettingsRow = {
  profileId: number;
  /** Legacy mirrors — synced on write for SQLite columns still present from v11 */
  featChallengeAi: boolean;
  featSessionInsights: boolean;
  featStudyPlanner: boolean;
  featMotivation: boolean;
  featWeeklyReview: boolean;
  coachEnabled: boolean;
  smartChallengesEnabled: boolean;
  debriefEnabled: boolean;
  weeklyNarrativeEnabled: boolean;
  subjectDifficultyEnabled: boolean;
  surpriseNotificationsEnabled: boolean;
  surpriseCheckIntervalHours: number;
  updatedAt: string;
};

type Row = {
  profile_id: number;
  feat_challenge_ai: number;
  feat_session_insights: number;
  feat_study_planner: number;
  feat_motivation: number;
  feat_weekly_review: number;
  coach_enabled: number | null;
  smart_challenges_enabled: number | null;
  debrief_enabled: number | null;
  weekly_narrative_enabled: number | null;
  subject_difficulty_enabled: number | null;
  surprise_notifications_enabled: number | null;
  surprise_check_interval_hours: number | null;
  updated_at: string;
};

function toBool(n: number | null): boolean {
  return n === 1;
}

function mapRow(r: Row): AiFeatureSettingsRow {
  const coach =
    r.coach_enabled !== null ? toBool(r.coach_enabled) : toBool(r.feat_motivation);
  const smart =
    r.smart_challenges_enabled !== null
      ? toBool(r.smart_challenges_enabled)
      : toBool(r.feat_challenge_ai);
  const debrief =
    r.debrief_enabled !== null ? toBool(r.debrief_enabled) : toBool(r.feat_session_insights);
  const weeklyNar =
    r.weekly_narrative_enabled !== null
      ? toBool(r.weekly_narrative_enabled)
      : toBool(r.feat_weekly_review);
  const subjDiff =
    r.subject_difficulty_enabled !== null
      ? toBool(r.subject_difficulty_enabled)
      : toBool(r.feat_study_planner);

  const surpriseEnabled =
    r.surprise_notifications_enabled !== null ? toBool(r.surprise_notifications_enabled) : false;
  const surpriseHoursRaw = r.surprise_check_interval_hours;
  const surpriseHours =
    surpriseHoursRaw != null && Number.isFinite(Number(surpriseHoursRaw)) && Number(surpriseHoursRaw) > 0
      ? Number(surpriseHoursRaw)
      : 3;

  return {
    profileId: r.profile_id,
    featChallengeAi: smart,
    featSessionInsights: debrief,
    featStudyPlanner: subjDiff,
    featMotivation: coach,
    featWeeklyReview: weeklyNar,
    coachEnabled: coach,
    smartChallengesEnabled: smart,
    debriefEnabled: debrief,
    weeklyNarrativeEnabled: weeklyNar,
    subjectDifficultyEnabled: subjDiff,
    surpriseNotificationsEnabled: surpriseEnabled,
    surpriseCheckIntervalHours: surpriseHours,
    updatedAt: r.updated_at
  };
}

export function defaultAiFeaturesForProfile(profileId: number): AiFeatureSettingsRow {
  const now = new Date().toISOString();
  return {
    profileId,
    featChallengeAi: false,
    featSessionInsights: false,
    featStudyPlanner: false,
    featMotivation: false,
    featWeeklyReview: false,
    coachEnabled: false,
    smartChallengesEnabled: false,
    debriefEnabled: false,
    weeklyNarrativeEnabled: false,
    subjectDifficultyEnabled: false,
    surpriseNotificationsEnabled: false,
    surpriseCheckIntervalHours: 3,
    updatedAt: now
  };
}

export function getAiFeaturesOrDefault(
  profileId: number,
  row: AiFeatureSettingsRow | null
): AiFeatureSettingsRow {
  return row ?? defaultAiFeaturesForProfile(profileId);
}

export async function getForProfile(profileId: number): Promise<AiFeatureSettingsRow | null> {
  const database = await getDatabase();
  const rows = await database.select<Row[]>(
    'SELECT * FROM ai_feature_settings WHERE profile_id = ? LIMIT 1',
    [profileId]
  );
  return rows[0] ? mapRow(rows[0]) : null;
}

export async function upsert(row: AiFeatureSettingsRow): Promise<void> {
  const database = await getDatabase();
  const b = (x: boolean) => (x ? 1 : 0);
  await database.execute(
    `INSERT INTO ai_feature_settings (
      profile_id,
      feat_challenge_ai, feat_session_insights, feat_study_planner, feat_motivation, feat_weekly_review,
      coach_enabled, smart_challenges_enabled, debrief_enabled, weekly_narrative_enabled, subject_difficulty_enabled,
      surprise_notifications_enabled, surprise_check_interval_hours,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(profile_id) DO UPDATE SET
      feat_challenge_ai = excluded.feat_challenge_ai,
      feat_session_insights = excluded.feat_session_insights,
      feat_study_planner = excluded.feat_study_planner,
      feat_motivation = excluded.feat_motivation,
      feat_weekly_review = excluded.feat_weekly_review,
      coach_enabled = excluded.coach_enabled,
      smart_challenges_enabled = excluded.smart_challenges_enabled,
      debrief_enabled = excluded.debrief_enabled,
      weekly_narrative_enabled = excluded.weekly_narrative_enabled,
      subject_difficulty_enabled = excluded.subject_difficulty_enabled,
      surprise_notifications_enabled = excluded.surprise_notifications_enabled,
      surprise_check_interval_hours = excluded.surprise_check_interval_hours,
      updated_at = CURRENT_TIMESTAMP`,
    [
      row.profileId,
      b(row.smartChallengesEnabled),
      b(row.debriefEnabled),
      b(row.subjectDifficultyEnabled),
      b(row.coachEnabled),
      b(row.weeklyNarrativeEnabled),
      b(row.coachEnabled),
      b(row.smartChallengesEnabled),
      b(row.debriefEnabled),
      b(row.weeklyNarrativeEnabled),
      b(row.subjectDifficultyEnabled),
      b(row.surpriseNotificationsEnabled),
      row.surpriseCheckIntervalHours
    ]
  );
}
