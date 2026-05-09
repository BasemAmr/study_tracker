import type { NotificationSettingsRow } from '../data/repositories/notificationSettingsRepository';
import { getForProfile, getOrDefault } from '../data/repositories/notificationSettingsRepository';
import {
  hasSessionOnLocalCalendarDay,
  getLastSessionStartAtIso,
  distinctStudyLocalDayKeysAscending,
  sumDurationMinutesBetween
} from '../data/repositories/sessionRepository';
import { countFiresSince, hasFiredSinceIso } from '../data/repositories/notificationLogRepository';
import { getFirstActiveGoalForProfile } from '../data/repositories/goalRepository';
import { calculateStreaks } from '../utils/streakUtils';
import type { NotificationKind } from './notificationKinds';

export type { NotificationKind } from './notificationKinds';

export type NotificationDecision = {
  fire: boolean;
  reason: string;
  rerouteTo?: Date;
};

function parseClockToMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(':').map((x) => Number(x));
  if (!Number.isFinite(h) || !Number.isFinite(m)) return 0;
  return h * 60 + m;
}

function minutesFromMidnight(d: Date): number {
  return d.getHours() * 60 + d.getMinutes();
}

export function setLocalWallClockFromHhmm(base: Date, hhmm: string): Date {
  const [hh, mm] = hhmm.split(':').map((x) => parseInt(x, 10));
  const out = new Date(base);
  out.setHours(hh ?? 0, mm ?? 0, 0, 0);
  return out;
}

function isOvernightQuiet(quietStart: string, quietEnd: string): boolean {
  return parseClockToMinutes(quietStart) > parseClockToMinutes(quietEnd);
}

function inQuietHours(now: Date, quietStart: string, quietEnd: string): boolean {
  const t = minutesFromMidnight(now);
  const s = parseClockToMinutes(quietStart);
  const e = parseClockToMinutes(quietEnd);
  if (isOvernightQuiet(quietStart, quietEnd)) {
    return t >= s || t < e;
  }
  return t >= s && t < e;
}

/** Next quiet window end instant after `now` (BEHAVIOR-N4 anchor for reroute). */
export function nextQuietEnd(now: Date, quietStart: string, quietEnd: string): Date {
  const t = minutesFromMidnight(now);
  const s = parseClockToMinutes(quietStart);
  const e = parseClockToMinutes(quietEnd);
  const overnight = isOvernightQuiet(quietStart, quietEnd);

  if (!overnight) {
    const endToday = setLocalWallClockFromHhmm(now, quietEnd);
    if (inQuietHours(now, quietStart, quietEnd)) {
      return endToday > now ? endToday : new Date(endToday.getTime() + 86400000);
    }
    return endToday > now ? endToday : new Date(endToday.getTime() + 86400000);
  }

  if (t < e) {
    const endToday = setLocalWallClockFromHhmm(now, quietEnd);
    return endToday > now ? endToday : new Date(endToday.getTime() + 86400000);
  }

  if (t >= s) {
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    return setLocalWallClockFromHhmm(tomorrow, quietEnd);
  }

  const endToday = setLocalWallClockFromHhmm(now, quietEnd);
  return endToday > now ? endToday : new Date(endToday.getTime() + 86400000);
}

/** Start of local Monday 00:00 for week math (goal pacing). */
function startOfWeekMondayLocal(now: Date): Date {
  const x = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const dow = x.getDay(); // Sun=0
  const offset = dow === 0 ? -6 : 1 - dow;
  x.setDate(x.getDate() + offset);
  x.setHours(0, 0, 0, 0);
  return x;
}

/** Inclusive calendar days from Monday week-start through `through` sod. */
function daysElapsedWeekThrough(weekStartMonday: Date, through: Date): number {
  const sodT = new Date(through.getFullYear(), through.getMonth(), through.getDate());
  const diffMs = sodT.getTime() - weekStartMonday.getTime();
  return Math.min(7, Math.max(1, Math.floor(diffMs / 86400000) + 1));
}

function daysLeftInclusiveInWeek(now: Date): number {
  const mon = startOfWeekMondayLocal(now);
  const sod = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const idx = Math.floor((sod.getTime() - mon.getTime()) / 86400000); // Mon=0..Sun=6
  return Math.max(1, 7 - idx);
}

/** Calendar days between sod(last session) → sod(now), same-day = 0. */
export function calendarDaysSinceLastStudyDay(lastSessionStart: Date, now: Date): number {
  const sod = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const ua = sod(lastSessionStart).getTime();
  const ub = sod(now).getTime();
  return Math.round((ub - ua) / 86400000);
}

/** Study dates ascending for streakUtils (unique local calendar days). */
async function streakStudyDates(profileId: number): Promise<Date[]> {
  const keys = await distinctStudyLocalDayKeysAscending(profileId);
  return keys.map((k) => {
    const [y, mo, da] = k.split('-').map((x) => parseInt(x, 10));
    return new Date(y, mo - 1, da);
  });
}

/** Matches daily notification alarm — ±band minutes from HH:mm anchor. */
function withinDailyFireBand(now: Date, hhmm: string, band = 65): boolean {
  const tgt = parseClockToMinutes(hhmm);
  const cur = minutesFromMidnight(now);
  const delta = Math.abs(cur - tgt);
  const wrapped = Math.min(delta, 24 * 60 - delta);
  return wrapped <= band;
}

// ─── BEHAVIOR-N2 type predicates (exported per N-T-* tickets)

/** N-T-1 / BEHAVIOR-N2 Type 1 — pre-study reminder. Fires within ±90 min of configured time. */
export async function shouldFirePreStudy(
  profileId: number,
  now: Date,
  settings: NotificationSettingsRow
): Promise<NotificationDecision> {
  // Removed: session_already_logged_today — pre-study is a time-of-day prompt,
  // not gated on whether the user already studied. They may want a second session.
  const cur = minutesFromMidnight(now);
  const tgt = parseClockToMinutes(settings.preStudyTime);
  /** Timer should land within ±90min; suppress if delayed past that (past pre-study window). */
  if (cur < tgt - 90) return { fire: false, reason: 'pre_study_before_window' };
  if (cur > tgt + 90) return { fire: false, reason: 'past_pre_study_time' };
  return { fire: true, reason: 'n2_type1' };
}

/** N-T-2 / BEHAVIOR-N2 Type 2 — streak protection (≥3 streak, fixed 22:00 band). */
export async function shouldFireStreak(profileId: number, now: Date, sessionToday: boolean): Promise<NotificationDecision> {
  if (sessionToday) return { fire: false, reason: 'session_already_logged_today' };

  const studyDates = await streakStudyDates(profileId);
  const { currentStreak } = calculateStreaks(studyDates, 1);
  if (currentStreak < 3) return { fire: false, reason: 'streak_below_three' };

  if (!withinDailyFireBand(now, '22:00', 65)) {
    return { fire: false, reason: 'outside_streak_protection_window' };
  }

  return { fire: true, reason: 'n2_type2' };
}

/** N-T-3 / BEHAVIOR-N2 Type 3 — weekly summary dedupe rolling 6d. */
export async function shouldFireWeekly(
  profileId: number,
  now: Date,
  settings: NotificationSettingsRow
): Promise<NotificationDecision> {
  const since = new Date(now);
  since.setDate(since.getDate() - 6);
  since.setHours(0, 0, 0, 0);
  const n = await countFiresSince(profileId, 1003, since);
  if (n > 0) return { fire: false, reason: 'weekly_already_fired_recent' };
  // Check against the user-configured day of week (1=Sun…7=Sat stored; convert to JS 0-based).
  // The scheduler already arms the timer on the correct day; this guard catches timer drift.
  const configuredJsDow = (settings.weeklySummaryDow - 1 + 7) % 7;
  if (now.getDay() !== configuredJsDow) return { fire: false, reason: 'not_weekly_anchor_day' };
  return { fire: true, reason: 'n2_type3' };
}

/** N-T-4 / BEHAVIOR-N2 Type 4 — goal pace (user-configured DOW + time slot). */
export async function shouldFireGoal(
  profileId: number,
  now: Date,
  settings: NotificationSettingsRow
): Promise<NotificationDecision> {
  const since = new Date(now);
  since.setDate(since.getDate() - 6);
  since.setHours(0, 0, 0, 0);
  if ((await countFiresSince(profileId, 1004, since)) > 0) {
    return { fire: false, reason: 'goal_reminder_already_fired_this_week' };
  }

  const goal = await getFirstActiveGoalForProfile(profileId);
  if (!goal) return { fire: false, reason: 'no_active_goal' };

  const weekStart = startOfWeekMondayLocal(now);
  const actual = await sumDurationMinutesBetween(profileId, weekStart.toISOString(), now.toISOString());

  const daysElapsed = daysElapsedWeekThrough(weekStart, now);
  const expectedSoFar = (daysElapsed / 7) * goal.targetMinutes;
  if (actual >= expectedSoFar) return { fire: false, reason: 'goal_on_track' };

  // Check against user-configured goal day of week (same 1=Sun…7=Sat → JS 0-based conversion).
  const configuredJsDow = (settings.goalDow - 1 + 7) % 7;
  if (now.getDay() !== configuredJsDow) return { fire: false, reason: 'not_goal_anchor_day' };

  return { fire: true, reason: 'n2_type4' };
}

/** BEHAVIOR-N2 Type 5 — re-engagement; `variant` 3 vs 7 day gates. Tone: supportive, never guilt-trip. */
export async function shouldFireReengagement(
  profileId: number,
  now: Date,
  settings: NotificationSettingsRow,
  sessionToday: boolean,
  variant: 3 | 7
): Promise<NotificationDecision> {
  if (sessionToday) return { fire: false, reason: 'session_already_logged_today' };

  if (!withinDailyFireBand(now, settings.reengageTime, 90)) {
    return { fire: false, reason: 'outside_reengage_time_window' };
  }

  const lastIso = await getLastSessionStartAtIso(profileId);
  if (!lastIso) return { fire: false, reason: 'no_prior_session_anchor' };

  const lastStart = new Date(lastIso);
  const daysApart = calendarDaysSinceLastStudyDay(lastStart, now);

  if (variant === 3) {
    if (daysApart !== settings.reengageIntervalDays) {
      return { fire: false, reason: 'reengage3_day_mismatch' };
    }
    if (await hasFiredSinceIso(profileId, 1005, lastIso)) {
      return { fire: false, reason: 'reengage3_already_sent_this_silence' };
    }
    return { fire: true, reason: 'n2_type5_three' };
  }

  if (daysApart !== 7) return { fire: false, reason: 'reengage7_day_mismatch' };
  if (await hasFiredSinceIso(profileId, 1006, lastIso)) {
    return { fire: false, reason: 'reengage7_already_sent_this_silence' };
  }
  return { fire: true, reason: 'n2_type5_seven' };
}

function quietDecision(settings: NotificationSettingsRow, now: Date): NotificationDecision | null {
  if (inQuietHours(now, settings.quietHoursStart, settings.quietHoursEnd)) {
    return {
      fire: false,
      reason: 'quiet_hours',
      rerouteTo: nextQuietEnd(now, settings.quietHoursStart, settings.quietHoursEnd)
    };
  }
  return null;
}

/** F-T-3 + N-T-1…5 orchestration — BEHAVIOR-N4 quiet held before per-type N2 rules */
export async function shouldFire(kind: NotificationKind, profileId: number, now: Date): Promise<NotificationDecision> {
  const row = await getForProfile(profileId);
  const settings = getOrDefault(profileId, row);

  const q = quietDecision(settings, now);
  if (q) return q;

  const sessionToday = await hasSessionOnLocalCalendarDay(profileId, now);

  switch (kind) {
    case 'pre_study':
      // sessionToday no longer passed — pre-study fires on time regardless of prior sessions.
      return shouldFirePreStudy(profileId, now, settings);
    case 'streak':
      return shouldFireStreak(profileId, now, sessionToday);
    case 'weekly':
      return shouldFireWeekly(profileId, now, settings);
    case 'goal':
      return shouldFireGoal(profileId, now, settings);
    case 'reengage_3':
      return shouldFireReengagement(profileId, now, settings, sessionToday, 3);
    case 'reengage_7':
      return shouldFireReengagement(profileId, now, settings, sessionToday, 7);
    default:
      return { fire: false, reason: 'unknown_kind' };
  }
}
