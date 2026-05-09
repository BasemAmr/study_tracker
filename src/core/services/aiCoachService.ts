import { chatCompletion } from './groqClient';
import * as aiCacheRepo from '../data/repositories/aiCacheRepository';
import {
  getAiFeaturesOrDefault,
  getForProfile
} from '../data/repositories/aiFeatureSettingsRepository';
import { getFirstActiveGoalForProfile } from '../data/repositories/goalRepository';
import { getProfileById } from '../data/repositories/profileRepository';
import {
  distinctStudyLocalDayKeysAscending,
  sumDurationMinutesBetween
} from '../data/repositories/sessionRepository';
import { summarizeLastSevenDays } from './studySignalsForAi';
import { calculateStreaks } from '../utils/streakUtils';
import { localCalendarDateKey } from '../utils/aiDateKeys';

export type CoachCachePayload = {
  message: string;
  generatedAt: string;
  model: string;
};

const FEATURE = 'coach';

/** Dedupes simultaneous coach generations for the same profile (boot + Dashboard mount). */
const coachInflight = new Map<number, Promise<CoachCachePayload | null>>();

function startOfWeekMondayLocal(now: Date): Date {
  const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const dow = d.getDay();
  const mondayDelta = dow === 0 ? -6 : 1 - dow;
  d.setDate(d.getDate() + mondayDelta);
  d.setHours(0, 0, 0, 0);
  return d;
}

/** Once-per-local-day coach string; silently null on failures (UI hides card). */
export async function ensureTodaysMessage(profileId: number): Promise<CoachCachePayload | null> {
  const inflight = coachInflight.get(profileId);
  if (inflight) return inflight;

  const promise = coachBody(profileId).finally(() => coachInflight.delete(profileId));
  coachInflight.set(profileId, promise);
  return promise;
}

async function coachBody(profileId: number): Promise<CoachCachePayload | null> {
  const row = await getForProfile(profileId);
  const feats = getAiFeaturesOrDefault(profileId, row);
  if (!feats.coachEnabled) return null;

  const dayKey = localCalendarDateKey(new Date());

  try {
    const cached = await aiCacheRepo.get(profileId, FEATURE, dayKey);
    if (cached) {
      try {
        return JSON.parse(cached) as CoachCachePayload;
      } catch {
        /* fall through regenerate */
      }
    }

    const dayKeysAscending = await distinctStudyLocalDayKeysAscending(profileId);
    const studyDatesDesc = [...dayKeysAscending]
      .map((k) => new Date(`${k}T12:00:00`))
      .sort((a, b) => a.getTime() - b.getTime());
    const streaks = calculateStreaks(studyDatesDesc);

    const seven = await summarizeLastSevenDays(profileId);

    const weekStart = startOfWeekMondayLocal(new Date());
    const wm = await sumDurationMinutesBetween(
      profileId,
      weekStart.toISOString(),
      new Date().toISOString(),
    );

    let goalLine = '';
    const goal = await getFirstActiveGoalForProfile(profileId);
    if (goal && goal.targetMinutes > 0) {
      const pct = Math.round((wm / goal.targetMinutes) * 100);
      goalLine = `Active goal "${goal.name}": weekly progress about ${pct}% of ${goal.targetMinutes}-minute target (${wm} minutes logged Monday–today).`;
    } else {
      goalLine = 'No active quantitative goal surfaced for this learner.';
    }

    const profile = await getProfileById(profileId);
    const academic = profile?.academicLevel ?? 'unspecified programme';

    const subjectLine = seven.topSubject
      ? `Dominant seven-day subject: "${seven.topSubject}" (${seven.perSubjectMinutes[seven.topSubject] ?? 0} minutes).`
      : 'No dominant subject surfaced in the trailing week.';

    const systemPrompt = `
You privately coach ONE StudyTracker user (${academic} track).

Ground truth you must weave into TWO or THREE complete sentences referencing explicit numbers/subjects pulled from bullets — never vague cheerleading.
Facts:
• ${seven.totalMinutes} minutes across ${seven.sessionCount} sessions in the trailing 7-day window.
• ${subjectLine}
• Study streak (unique active days heuristic): currently ${streaks.currentStreak} day(s), historical max in view: ${streaks.longestStreak}.
• ${goalLine}

Rules:
• No emoji, no "Great job" / motivational clichés sans data.
• English only.

Reply with plain prose only — no headings.
`;
    const userPrompt = `Today is ${dayKey}. Write the student's coaching note referencing their real stats.`;

    const text = await chatCompletion({
      systemPrompt,
      prompt: userPrompt,
      jsonMode: false,
      timeoutMs: 4500,
    });
    if (!text) return null;

    const payload: CoachCachePayload = {
      message: text.trim(),
      generatedAt: new Date().toISOString(),
      model: 'llama-3.1-8b-instant'
    };
    await aiCacheRepo.set(profileId, FEATURE, dayKey, JSON.stringify(payload));
    return payload;
  } catch {
    return null;
  }
}
