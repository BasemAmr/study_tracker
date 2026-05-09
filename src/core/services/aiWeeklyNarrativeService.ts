import { chatCompletion } from './groqClient';
import * as aiCacheRepo from '../data/repositories/aiCacheRepository';
import { isoWeekKey, rolling7DayKey, localCalendarDateKey } from '../utils/aiDateKeys';
import { computeMoodDistribution, computeSubjectBreakdown } from '../utils/analyticsUtils';
import type { StudySession } from '../domain';
import { listSessionsForProfile } from '../data/repositories/sessionRepository';
import { getFirstActiveGoalForProfile } from '../data/repositories/goalRepository';

const FEATURE = 'narrative';

export type WeeklyNarrativePayload = {
  text: string;
  generatedAt: string;
  model: string;
  weekKey: string;
};

function rolling7DayStart(reference: Date): Date {
  const d = new Date(reference.getFullYear(), reference.getMonth(), reference.getDate());
  d.setDate(d.getDate() - 7);
  d.setHours(0, 0, 0, 0);
  return d;
}

function weekSessions(sessionsAll: StudySession[], weekStart: Date, weekEndExclusive: Date): StudySession[] {
  return sessionsAll.filter((s) => {
    const t = new Date(s.startAt).getTime();
    return t >= weekStart.getTime() && t < weekEndExclusive.getTime();
  });
}

async function aggregateWeek(profileId: number, anchor: Date) {
  const weekStart = rolling7DayStart(anchor);
  const endExclusive = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate() + 1);
  endExclusive.setHours(0, 0, 0, 0);

  const wide = await listSessionsForProfile(profileId, {
    startFrom: new Date(weekStart.getTime() - 86400000).toISOString(),
    limit: 8000,
    offset: 0,
  });

  const week = weekSessions(wide, weekStart, endExclusive);

  const totalMin = week.reduce((a, s) => a + s.durationMinutes, 0);
  const subjects = computeSubjectBreakdown(week);
  const moods = computeMoodDistribution(week);

  /** Minutes per local calendar day in this ISO-ish week window */
  const byDayKey = new Map<string, number>();
  for (const s of week) {
    const k = new Date(s.startAt).toLocaleDateString('en-CA');
    byDayKey.set(k, (byDayKey.get(k) ?? 0) + s.durationMinutes);
  }
  let bestDay = '';
  let bestM = -1;
  let worstDay = '';
  let worstM = Infinity;
  for (const [k, m] of byDayKey.entries()) {
    if (m > bestM) {
      bestM = m;
      bestDay = k;
    }
    if (m < worstM) {
      worstM = m;
      worstDay = k;
    }
  }

  /** Tasks rollup */
  let done = 0;
  let totalTasks = 0;
  for (const s of week) {
    const tasks = s.tasks ?? [];
    totalTasks += tasks.length;
    done += tasks.filter((t) => t.completed).length;
  }

  const uniqueStudyDaysWeek = new Set(
    week.map((s) => new Date(s.startAt).toLocaleDateString('en-CA')),
  );
  const studyDaysThisWeekCount = uniqueStudyDaysWeek.size;

  const goal = await getFirstActiveGoalForProfile(profileId);
  let goalBits = '';
  if (goal) {
    goalBits = `${goal.active ? 'Active' : 'Inactive'} goal "${goal.name}" targets ${goal.targetMinutes} weekly minutes — logged ${totalMin} this window.`;
  } else {
    goalBits = 'No pinned weekly goal.';
  }

  return {
    weekKey: rolling7DayKey(anchor),
    weekStart,
    week,
    totalMin,
    sessionCount: week.length,
    subjects,
    moods,
    bestDay,
    bestM,
    worstDay,
    worstMinutesLean: worstM === Infinity ? 0 : worstM,
    tasksDone: done,
    tasksTotal: totalTasks,
    studyDaysThisWeekCount,
    goalBits,
  };
}

/**
 * Cached weekly journaling paragraph (manual trigger from Analytics).
 * `anchor` defaults to today so the Monday–Sunday window matches the labelled ISO week bucket.
 */
export async function generateForWeek(
  profileId: number,
  anchorDate: Date = new Date(),
  forceRefresh: boolean = false,
): Promise<WeeklyNarrativePayload | null> {
  const data = await aggregateWeek(profileId, anchorDate);

  try {
    if (!forceRefresh) {
      const cached = await aiCacheRepo.get(profileId, FEATURE, data.weekKey);
      if (cached) {
        return JSON.parse(cached) as WeeklyNarrativePayload;
      }
    }

    const subjectTop = data.subjects
      .slice(0, 5)
      .map((s) => `${s.name}: ${s.minutes}m (${s.sessionCount} sessions)`)
      .join('; ');
    const moodTop = data.moods
      .slice(0, 4)
      .map((m) => `${m.mood}:${m.percentage}%`)
      .join(', ');

    const systemPrompt = `
You summarize a student's week as a SHORT journal paragraph (THREE or FOUR sentences),
past tense, candid, anchored to quantitative facts below.
Forbidden: prescribing advice/to-dos/future tense coaching, emoji, clichés ("you crushed it").
Facts:
Minutes: ${data.totalMin} across ${data.sessionCount} sessions.
Subject mix: ${subjectTop || 'none'}
Mood histogram: ${moodTop || 'no mood labels'}
Highest-volume day approx: ${data.bestDay || 'n/a'}; leanest tracked day approx: ${data.worstDay || 'n/a'}.
Notebook tasks flagged done: ${data.tasksDone} / ${data.tasksTotal}.
Approx distinct study-days within this mapped window: ${data.studyDaysThisWeekCount}.
${data.goalBits}
`;
    const userPrompt =
      'Respond with one cohesive paragraph referencing specific numbers/subjects naturally. Plain text only.';

    const text = await chatCompletion({
      systemPrompt,
      prompt: userPrompt,
      jsonMode: false,
      timeoutMs: 6000,
    });
    if (!text) return null;

    const payload: WeeklyNarrativePayload = {
      text: text.trim(),
      generatedAt: new Date().toISOString(),
      model: 'llama-3.1-8b-instant',
      weekKey: data.weekKey,
    };
    await aiCacheRepo.set(profileId, FEATURE, data.weekKey, JSON.stringify(payload));
    return payload;
  } catch {
    return null;
  }
}

export async function getCachedNarrative(
  profileId: number,
  weekKey: string,
): Promise<WeeklyNarrativePayload | null> {
  const raw = await aiCacheRepo.get(profileId, FEATURE, weekKey);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as WeeklyNarrativePayload;
  } catch {
    return null;
  }
}
