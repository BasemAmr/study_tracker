import { getForProfile, getOrDefault } from '../data/repositories/notificationSettingsRepository';
import { NotificationId, cancelAll, scheduleDaily, scheduleWeekly, scheduleRecurringInterval } from './notificationScheduler';
import { getForProfile as getAiFeatureSettings, getAiFeaturesOrDefault } from '../data/repositories/aiFeatureSettingsRepository';

/** Hard-coded streak-protection anchor per BEHAVIOR-N2 Type 2 ("midnight − 2 hours" → 22:00 local). */
const STREAK_FIRE_HHMM = '22:00';

/**
 * BEHAVIOR-N7 — idempotent reschedule on cold launch (caller provides active profile id).
 * N‑T‑1…5 wire concrete clock anchors from `notification_settings`.
 */
export async function rescheduleAllNotifications(profileId: number): Promise<void> {
  await cancelAll();

  const rowSaved = await getForProfile(profileId);
  const s = getOrDefault(profileId, rowSaved);

  const basePayload = { profileId } as const;

  if (s.preStudyEnabled) {
    await scheduleDaily(NotificationId.PreStudy, s.preStudyTime, { ...basePayload, kind: 'pre_study' });
  }

  if (s.streakEnabled) {
    await scheduleDaily(NotificationId.Streak, STREAK_FIRE_HHMM, { ...basePayload, kind: 'streak' });
  }

  if (s.weeklyEnabled) {
    await scheduleWeekly(NotificationId.Weekly, s.weeklySummaryDow, s.weeklySummaryTime, {
      ...basePayload,
      kind: 'weekly'
    });
  }

  if (s.goalEnabled) {
    await scheduleWeekly(NotificationId.Goal, s.goalDow, s.goalTime, { ...basePayload, kind: 'goal' });
  }

  if (s.reengage3Enabled) {
    await scheduleDaily(NotificationId.Reengagement3, s.reengageTime, { ...basePayload, kind: 'reengage_3' });
  }

  if (s.reengage7Enabled) {
    await scheduleDaily(NotificationId.Reengagement7, s.reengageTime, { ...basePayload, kind: 'reengage_7' });
  }

  // T6: Surprise mission check — interval-based recurring schedule
  const aiSettings = await getAiFeatureSettings(profileId);
  const aiFeatures = getAiFeaturesOrDefault(profileId, aiSettings);
  if (aiFeatures.surpriseNotificationsEnabled && aiFeatures.surpriseCheckIntervalHours > 0) {
    await scheduleRecurringInterval(NotificationId.SurpriseCheck, aiFeatures.surpriseCheckIntervalHours, {
      ...basePayload,
      intervalHours: aiFeatures.surpriseCheckIntervalHours
    });
  }
}
