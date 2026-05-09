import { NotificationId, type NotificationKind } from './notificationKinds';
import {
  getDominantSubjectLastDays,
  sumDurationMinutesBetween,
  sessionCountBetween,
  topSubjectMinutesInRange
} from '../data/repositories/sessionRepository';
import { getFirstActiveGoalForProfile } from '../data/repositories/goalRepository';

const TITLE = 'StudyTracker';

function dayOfYearLocal(d: Date): number {
  const start = new Date(d.getFullYear(), 0, 1);
  return Math.floor((d.getTime() - start.getTime()) / 86400000) + 1;
}

function formatHoursMinutes(totalMinutes: number): { h: number; m: number; label: string } {
  const h = Math.floor(totalMinutes / 60);
  const m = Math.round(totalMinutes % 60);
  if (h <= 0) return { h: 0, m, label: `${m}m` };
  if (m === 0) return { h, m: 0, label: `${h}h` };
  return { h, m, label: `${h}h ${m}m` };
}

function startOfWeekMondayLocal(d: Date): Date {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dow = x.getDay();
  const offset = dow === 0 ? -6 : 1 - dow;
  x.setDate(x.getDate() + offset);
  x.setHours(0, 0, 0, 0);
  return x;
}

function daysElapsedWeekThrough(weekStartMonday: Date, through: Date): number {
  const sodT = new Date(through.getFullYear(), through.getMonth(), through.getDate());
  const diffMs = sodT.getTime() - weekStartMonday.getTime();
  return Math.min(7, Math.max(1, Math.floor(diffMs / 86400000) + 1));
}

function daysLeftInclusiveInWeek(now: Date): number {
  const mon = startOfWeekMondayLocal(now);
  const sod = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const idx = Math.floor((sod.getTime() - mon.getTime()) / 86400000);
  return Math.max(1, 7 - idx);
}

export async function buildGoalReminderBody(profileId: number, now: Date): Promise<string | null> {
  const goal = await getFirstActiveGoalForProfile(profileId);
  if (!goal) return null;
  const weekStart = startOfWeekMondayLocal(now);
  const actual = await sumDurationMinutesBetween(profileId, weekStart.toISOString(), now.toISOString());
  const daysElapsed = daysElapsedWeekThrough(weekStart, now);
  const expectedSoFar = (daysElapsed / 7) * goal.targetMinutes;
  const deficitMinutes = Math.max(0, Math.round(expectedSoFar - actual));
  return composeGoalProgressMessage({
    goalName: goal.name,
    deficitMinutes,
    daysLeftThisWeek: daysLeftInclusiveInWeek(now)
  });
}

/** BEHAVIOR-N2 Type 1 — deterministic pool; subject line when dominant subject logged ≥3× in last 7d. */
export async function composePreStudyMessage(profileId: number, now: Date): Promise<string> {
  const poolSize = 3;
  const idx = dayOfYearLocal(now) % poolSize;

  const msg0 =
    'Starting to study soon? Open the app to set your focus and track it 📚';
  const msg1 =
    "Heading into a session? Log it in Study Tracker so your streak counts";

  if (idx === 2) {
    const dom = await getDominantSubjectLastDays(profileId, 7);
    if (dom && dom.count >= 3) {
      return `Your ${dom.name} is waiting — ready to track today's session?`;
    }
    return msg0;
  }
  return idx === 0 ? msg0 : msg1;
}

export function composeStreakMessage(currentStreak: number): string {
  return `Your ${currentStreak}-day streak ends at midnight — 20 minutes now keeps it alive 🔥`;
}

export async function composeWeeklyMessage(profileId: number, now: Date): Promise<string> {
  const end = now;
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  start.setDate(start.getDate() - 7);
  const totalMinutes = await sumDurationMinutesBetween(profileId, start.toISOString(), end.toISOString());
  const nSessions = await sessionCountBetween(profileId, start.toISOString(), end.toISOString());
  if (totalMinutes <= 0 || nSessions === 0) {
    return "No sessions this week — this is a good time to plan next week's goals";
  }
  const top = await topSubjectMinutesInRange(profileId, start.toISOString(), end.toISOString());
  const subj = top?.name ?? 'your subjects';
  const { label } = formatHoursMinutes(totalMinutes);
  return `This week: ${label} studied across ${nSessions} sessions. Your best subject: ${subj}. Open to see your full breakdown →`;
}

/** hours behind (~one decimal); message rounds for display */
export function composeGoalProgressMessage(opts: {
  goalName: string;
  deficitMinutes: number;
  /** Local-days left including today until end of ISO week Monday-start (max 7) */
  daysLeftThisWeek: number;
}): string {
  const hoursBehind = Math.max(opts.deficitMinutes / 60, 0);
  const n = Number.isInteger(hoursBehind) ? String(hoursBehind) : hoursBehind.toFixed(1).replace(/\.0$/, '');
  const plural = opts.daysLeftThisWeek === 1 ? 'day' : 'days';
  return `You're ${n} hours behind on your '${opts.goalName}' goal — ${opts.daysLeftThisWeek} ${plural} left this week to catch up`;
}

/** BEHAVIOR-N2 Type 5 — no guilt-trip wording (explicit tone constraint). */
export function composeReengagementMessage(daysSinceLast: number): string {
  if (daysSinceLast >= 7) {
    return "It's been a week. Your study history is still here whenever you come back 📖";
  }
  return `It's been ${daysSinceLast} days since your last session — no pressure, but your data is here when you're ready`;
}

export async function composeNotificationMessage(
  notificationId: NotificationId | number,
  profileId: number,
  kind: NotificationKind,
  now: Date,
  extra?: { currentStreak?: number; daysSinceLastSession?: number }
): Promise<{ title: string; body: string }> {
  switch (kind) {
    case 'pre_study': {
      const body = await composePreStudyMessage(profileId, now);
      return { title: TITLE, body };
    }
    case 'streak': {
      const n = extra?.currentStreak ?? 0;
      return { title: TITLE, body: composeStreakMessage(n) };
    }
    case 'weekly': {
      const body = await composeWeeklyMessage(profileId, now);
      return { title: TITLE, body };
    }
    case 'goal': {
      const body =
        (extra as { goalBody?: string } | undefined)?.goalBody ??
        "Check in on your weekly goal — open StudyTracker when you're ready.";
      return { title: TITLE, body };
    }
    case 'reengage_3':
    case 'reengage_7': {
      const d = extra?.daysSinceLastSession ?? 0;
      return { title: TITLE, body: composeReengagementMessage(d) };
    }
    default:
      return { title: TITLE, body: 'Open StudyTracker.' };
  }
}
