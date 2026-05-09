import { isTauri, invoke } from '@tauri-apps/api/core';
import type { Options as NativeNotificationOptions } from '@tauri-apps/plugin-notification';
import { getCurrentProfileId } from '../data/repositories/profileRepository';
import { append } from '../data/repositories/notificationLogRepository';
import { shouldFire, calendarDaysSinceLastStudyDay, type NotificationKind } from './notificationDecisionEngine';
import { navigateNotificationDeepLink } from './deepLinkRouter';
import { NotificationId, type NotificationPayload } from './notificationKinds';
import { composeNotificationMessage, buildGoalReminderBody } from './messageTemplates';
import { distinctStudyLocalDayKeysAscending, getLastSessionStartAtIso } from '../data/repositories/sessionRepository';
import { calculateStreaks } from '../utils/streakUtils';
import { aiChallengeRepository } from '../data/repositories/aiChallengeRepository';
import { aiChallengeHistoryRepository } from '../data/repositories/aiChallengeHistoryRepository';
import { getAiFeaturesOrDefault, getForProfile as getAiFeatureSettings } from '../data/repositories/aiFeatureSettingsRepository';
import { getStructuredSettings } from '../data/repositories/appSettingsRepository';
import { aiChallengeService } from '../services/aiChallengeService';

export { rescheduleAllNotifications as rescheduleAll } from './notificationReschedule';

export function notificationKindFromNotificationId(id: number): NotificationKind | null {
  switch (id) {
    case NotificationId.PreStudy:
      return 'pre_study';
    case NotificationId.Streak:
      return 'streak';
    case NotificationId.Weekly:
      return 'weekly';
    case NotificationId.Goal:
      return 'goal';
    case NotificationId.Reengagement3:
      return 'reengage_3';
    case NotificationId.Reengagement7:
      return 'reengage_7';
    default:
      return null;
  }
}

function readProfileId(extra?: Record<string, unknown>): number | null {
  const v = extra?.profileId;
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string' && /^\d+$/.test(v)) return Number(v);
  return null;
}

function readKindExtra(extra?: Record<string, unknown>): NotificationKind | null {
  const k = extra?.kind;
  if (
    k === 'pre_study' ||
    k === 'streak' ||
    k === 'weekly' ||
    k === 'goal' ||
    k === 'reengage_3' ||
    k === 'reengage_7'
  ) {
    return k;
  }
  return null;
}

function resolveKind(notificationId: number, payload: NotificationPayload): NotificationKind | null {
  return (
    readKindExtra(payload as Record<string, unknown>) ?? notificationKindFromNotificationId(notificationId)
  );
}

async function streakForMessage(profileId: number): Promise<number> {
  const keys = await distinctStudyLocalDayKeysAscending(profileId);
  const dates = keys.map((k) => {
    const [y, mo, da] = k.split('-').map((x) => parseInt(x, 10));
    return new Date(y, mo - 1, da);
  });
  return calculateStreaks(dates, 1).currentStreak;
}

async function buildToastContent(
  notificationId: number,
  profileId: number,
  kind: NotificationKind,
  now: Date
): Promise<{ title: string; body: string }> {
  if (kind === 'goal') {
    const body = await buildGoalReminderBody(profileId, now);
    return { title: 'StudyTracker', body: body ?? 'Check your weekly goal in StudyTracker when you have a minute.' };
  }
  if (kind === 'streak') {
    const streak = await streakForMessage(profileId);
    return await composeNotificationMessage(notificationId, profileId, kind, now, { currentStreak: streak });
  }
  if (kind === 'reengage_3' || kind === 'reengage_7') {
    const lastIso = await getLastSessionStartAtIso(profileId);
    const days = lastIso ? calendarDaysSinceLastStudyDay(new Date(lastIso), now) : 0;
    return await composeNotificationMessage(notificationId, profileId, kind, now, { daysSinceLastSession: days });
  }
  return await composeNotificationMessage(notificationId, profileId, kind, now);
}

/** Runs when our in-process timer elapses — BEHAVIOR-N4 suppression before invoking `fire_notification`. */
export async function dispatchTimedNotification(
  notificationId: number,
  payload: NotificationPayload
): Promise<{ showedToast: boolean }> {
  const profileId = readProfileId(payload as Record<string, unknown>) ?? (await getCurrentProfileId());
  const now = new Date();

  // T6: Special handling for surprise mission check (does not go through decision engine)
  if (notificationId === NotificationId.SurpriseCheck) {
    return await handleSurpriseMissionCheckTick(notificationId, profileId, payload);
  }

  const kind = resolveKind(notificationId, payload);
  if (!kind) return { showedToast: false };

  const decision = await shouldFire(kind, profileId, now);

  const { cancel, scheduleAt } = await import('./notificationScheduler');

  if (!decision.fire && decision.rerouteTo) {
    console.info(`[notifications] id=${notificationId} kind=${kind} → SUPPRESSED (${decision.reason}) → rerouting to ${decision.rerouteTo.toLocaleTimeString()}`);
    await append(profileId, notificationId, 'suppressed', `${decision.reason}:rerouting`);
    await cancel(notificationId);
    await scheduleAt(notificationId, decision.rerouteTo, { ...payload, profileId, kind });
    return { showedToast: false };
  }

  if (!decision.fire) {
    // Log suppression reason so it's visible in Tauri DevTools console
    console.info(`[notifications] id=${notificationId} kind=${kind} → SUPPRESSED reason="${decision.reason}" time=${now.toLocaleTimeString()}`);
    await append(profileId, notificationId, 'suppressed', decision.reason);
    return { showedToast: false };
  }

  console.info(`[notifications] id=${notificationId} kind=${kind} → FIRING at ${now.toLocaleTimeString()}`);

  if (!isTauri()) {
    return { showedToast: false };
  }

  const { title, body } = await buildToastContent(notificationId, profileId, kind, now);
  try {
    await invoke('fire_notification', { id: notificationId, title, body, payload });
  } catch (e) {
    // Surface to caller so Settings "Test" button can show a visible error instead of silent fail.
    console.warn('[notifications] fire_notification failed:', e);
    throw e;
  }

  await append(profileId, notificationId, 'fired', decision.reason);
  return { showedToast: true };
}

/**
 * Test-only: fire a toast immediately, bypassing the scheduler and all decision-engine
 * gates (quiet hours, time-band, session-today, streak checks).
 * Used by the Settings "Test Notification" button to isolate OS-level issues.
 */
export async function testFireNotification(): Promise<{ ok: boolean; error?: string }> {
  if (!isTauri()) return { ok: false, error: 'Not running inside Tauri' };
  try {
    await invoke('fire_notification', {
      id: 9999,
      title: 'StudyTracker — Test',
      body: 'Notifications are working ✓',
      payload: { kind: 'pre_study' }
    });
    return { ok: true };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

/**
 * Simulate what the decision engine would decide for `kind` right now, without
 * needing a real timer to fire first. Used by the Settings debug panel.
 * Returns the decision so the UI can display the suppression reason.
 */
export async function simulateScheduledFire(kind: NotificationKind): Promise<{ fire: boolean; reason: string }> {
  const profileId = await getCurrentProfileId();
  const now = new Date();
  const decision = await shouldFire(kind, profileId, now);
  console.info(`[notifications] simulate kind=${kind} → fire=${decision.fire} reason="${decision.reason}"`);
  return { fire: decision.fire, reason: decision.reason };
}

/** BEHAVIOR-N5 — official plugin emits `Options` shaped like the outbound builder (`id`, `extra`, …). */
export async function handleSchedulerAction(opts: NativeNotificationOptions): Promise<void> {
  const notificationId = opts.id;
  if (notificationId === undefined) return;
  await navigateNotificationDeepLink(notificationId);
}

/**
 * T6: Handle the surprise mission check tick.
 * Flow: check current surprise → if expired, snapshot to history → call API to refresh
 *       → fire user notification "New surprise mission available" on success
 *       → silent on failure (error visible inside app on tab open).
 * Then reschedule the next interval check.
 *
 * Gating: only if AI enabled + API key present. Silently skip otherwise.
 */
async function handleSurpriseMissionCheckTick(
  notificationId: number,
  profileId: number,
  payload: NotificationPayload
): Promise<{ showedToast: boolean }> {
  try {
    // Gating logic: if AI disabled or no API key, skip silently (no toast, no notification).
    const aiSettings = await getAiFeatureSettings(profileId);
    const aiFeatures = getAiFeaturesOrDefault(profileId, aiSettings);
    const appSettings = await getStructuredSettings();

    if (!aiFeatures.smartChallengesEnabled || !appSettings.groqApiKey) {
      // Gating: AI off or no API key → no-op. Log as suppressed.
      await append(profileId, notificationId, 'suppressed', 'AI disabled or no API key');

      // Reschedule the next interval check
      const intervalHours = readPayloadInt(payload, 'intervalHours', 3);
      const { scheduleRecurringInterval } = await import('./notificationScheduler');
      await scheduleRecurringInterval(notificationId, intervalHours, { ...payload, profileId });

      return { showedToast: false };
    }

    // Core T6 logic: check surprise mission, refresh if needed, fire user notification if successful
    const currentSurprise = await aiChallengeRepository.getActiveByTier('surprise');

    if (!currentSurprise) {
      // No active mission: just call API to create one
      const result = await aiChallengeService.refreshTierNow('surprise');
      if (result.ok) {
        // Success: fire user-visible notification
        if (isTauri()) {
          try {
            await invoke('fire_notification', {
              id: NotificationId.SurpriseAvailable,
              title: 'StudyTracker',
              body: 'New surprise mission available! Check it out now.',
              payload
            });
          } catch (e) {
            console.warn('[notifications] fire_notification for surprise available failed:', e);
          }
        }
        await append(profileId, notificationId, 'fired', 'surprise check: new mission created');
      } else {
        // Failure: silent (error visible in app on next tab open)
        await append(profileId, notificationId, 'suppressed', 'surprise check: API failed');
      }
    } else if (new Date(currentSurprise.expiresAt).getTime() < Date.now()) {
      // Surprise mission is expired: snapshot it to history, then refresh
      const progress = await aiChallengeService.calculateProgress(currentSurprise);
      await aiChallengeHistoryRepository.create({
        profileId,
        tier: currentSurprise.tier,
        title: currentSurprise.title,
        description: currentSurprise.description,
        metric: currentSurprise.metric,
        target: currentSurprise.target,
        progressAtClose: progress.current,
        closeReason: 'expired',
        closedAt: new Date().toISOString(),
        originalCreatedAt: currentSurprise.createdAt ?? new Date().toISOString(),
        originalExpiresAt: currentSurprise.expiresAt,
        subTargets: currentSurprise.subTargets ?? null,
        unitMinMinutes: currentSurprise.unitMinMinutes ?? null
      });

      // Try to refresh with API
      const result = await aiChallengeService.refreshTierNow('surprise');
      if (result.ok) {
        // Success: fire user notification
        if (isTauri()) {
          try {
            await invoke('fire_notification', {
              id: NotificationId.SurpriseAvailable,
              title: 'StudyTracker',
              body: 'New surprise mission available! Check it out now.',
              payload
            });
          } catch (e) {
            console.warn('[notifications] fire_notification for surprise available failed:', e);
          }
        }
        await append(profileId, notificationId, 'fired', 'surprise check: expired mission renewed');
      } else {
        // Failure: silent (error visible in app)
        await append(profileId, notificationId, 'suppressed', 'surprise check: expired mission API refresh failed');
      }
    } else {
      // If mission exists and not expired: do nothing, just reschedule next check
      await append(profileId, notificationId, 'fired', 'surprise check: mission still active');
    }

    // Always reschedule the next interval check (even if this one had an error)
    const intervalHours = readPayloadInt(payload, 'intervalHours', 3);
    const { scheduleRecurringInterval } = await import('./notificationScheduler');
    await scheduleRecurringInterval(notificationId, intervalHours, { ...payload, profileId });

    return { showedToast: true };
  } catch (e) {
    // Unexpected error: log as suppressed and silently reschedule
    console.error('[notifications] handleSurpriseMissionCheckTick error:', e);
    await append(profileId, notificationId, 'suppressed', `surprise check error: ${String(e)}`);

    // Reschedule next check despite error
    const intervalHours = readPayloadInt(payload, 'intervalHours', 3);
    const { scheduleRecurringInterval } = await import('./notificationScheduler');
    await scheduleRecurringInterval(notificationId, intervalHours, { ...payload, profileId });

    return { showedToast: false };
  }
}

/** Helper: parse interval hours from payload (defaults to 3). */
function readPayloadInt(payload: NotificationPayload, key: string, fallback: number): number {
  const v = (payload as Record<string, unknown>)[key];
  if (typeof v === 'number' && Number.isFinite(v) && v > 0) return v;
  if (typeof v === 'string') {
    const n = Number(v);
    if (Number.isFinite(n) && n > 0) return n;
  }
  return fallback;
}
