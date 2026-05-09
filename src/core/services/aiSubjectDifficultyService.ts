import { chatCompletion } from './groqClient';
import * as aiCacheRepo from '../data/repositories/aiCacheRepository';
import { localCalendarDateKey, isoWeekKey } from '../utils/aiDateKeys';
import { listSessionsForProfile } from '../data/repositories/sessionRepository';
import {
  getAiFeaturesOrDefault,
  getForProfile,
} from '../data/repositories/aiFeatureSettingsRepository';
import type { StudySession } from '../domain';

const FEATURE = 'difficulty';
const WEEKLY_AUTO = 'difficulty_auto_week';

export type SubjectDifficultyOk = {
  hardest_subject: string;
  reason: string;
  suggestion: string;
};

export type SubjectDifficultyAnalyzeResult =
  | { ok: true; data: SubjectDifficultyOk }
  | { ok: false; error: 'not_enough_data' };

export async function getCachedDifficultyToday(profileId: number): Promise<SubjectDifficultyOk | null> {
  const dayKey = localCalendarDateKey(new Date());
  const raw = await aiCacheRepo.get(profileId, FEATURE, dayKey);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as SubjectDifficultyOk;
  } catch {
    return null;
  }
}

type SubjectAgg = {
  name: string;
  sessions: number;
  minutes: number;
  moodCounts: Record<string, number>;
  tasksCompleted: number;
  tasksTotal: number;
};

function aggregate30d(sessions: StudySession[]): SubjectAgg[] {
  const map = new Map<string, SubjectAgg>();
  for (const s of sessions) {
    const name = (s.subjectName ?? 'General').trim() || 'General';
    let cur =
      map.get(name) ??
      ({
        name,
        sessions: 0,
        minutes: 0,
        moodCounts: {},
        tasksCompleted: 0,
        tasksTotal: 0,
      } satisfies SubjectAgg);
    cur.minutes += s.durationMinutes;
    cur.sessions += 1;
    if (s.mood) cur.moodCounts[s.mood] = (cur.moodCounts[s.mood] ?? 0) + 1;
    const tt = s.tasks ?? [];
    cur.tasksTotal += tt.length;
    cur.tasksCompleted += tt.filter((t) => t.completed).length;
    map.set(name, cur);
  }
  return [...map.values()].filter((x) => x.sessions >= 3);
}

/**
 * Cached once per calendar day (`cache_key = YYYY-MM-DD`). Exclude subjects &lt;3 sessions in trailing 30d.
 */
export async function analyze(
  profileId: number,
  forceRefresh: boolean = false,
): Promise<SubjectDifficultyAnalyzeResult> {
  const since = new Date();
  since.setDate(since.getDate() - 30);

  const raw = await listSessionsForProfile(profileId, {
    startFrom: since.toISOString(),
    limit: 8000,
    offset: 0,
  });

  const qualified = aggregate30d(raw);
  if (!qualified.length) {
    return { ok: false, error: 'not_enough_data' };
  }

  const dayKey = localCalendarDateKey(new Date());

  try {
    if (!forceRefresh) {
      const cached = await aiCacheRepo.get(profileId, FEATURE, dayKey);
      if (cached) {
        const parsed = JSON.parse(cached) as SubjectDifficultyOk;
        if (parsed?.hardest_subject && parsed.reason && parsed.suggestion) {
          return { ok: true, data: parsed };
        }
      }
    }

    const lines = qualified
      .map(
        (a) =>
          `${a.name}: ${a.sessions} sessions | ${a.minutes}m total | moods: ${Object.entries(a.moodCounts)
            .map(([k, v]) => `${k}:${v}`)
            .join(', ') || 'none'} | tasks finished ${a.tasksCompleted}/${a.tasksTotal}`,
      )
      .join('\n');

    const systemPrompt = `
Identify which subject statistically feels toughest for THIS learner comparing ONLY the aggregates below.

Return VALID JSON ONLY with keys:
{"hardest_subject":"exact label from dataset","reason":"one factual sentence quoting patterns","suggestion":"one realistic next-step about that subject"}

Do not emoji. Mention the hardest subject explicitly by name inside reason or suggestion.

DATA (last 30d, subjects with ≥3 sessions only):
${lines}
`;

    const out = await chatCompletion({
      systemPrompt,
      prompt: `Pick the objectively stretched subject and justify with data.`,
      jsonMode: true,
      timeoutMs: 5000,
    });
    if (!out) return { ok: false, error: 'not_enough_data' };

    const parsed = JSON.parse(out) as SubjectDifficultyOk;
    if (
      typeof parsed.hardest_subject !== 'string' ||
      typeof parsed.reason !== 'string' ||
      typeof parsed.suggestion !== 'string'
    ) {
      return { ok: false, error: 'not_enough_data' };
    }

    await aiCacheRepo.set(profileId, FEATURE, dayKey, JSON.stringify(parsed));
    return { ok: true, data: parsed };
  } catch {
    return { ok: false, error: 'not_enough_data' };
  }
}

/**
 * Sundays only: optional auto-difficulty ping once per ISO week when toggle + telemetry allow.
 */
export async function maybeAutoRunWeeklyDifficulty(profileId: number, now = new Date()): Promise<void> {
  try {
    if (now.getDay() !== 0) return;

    const row = await getForProfile(profileId);
    const feats = getAiFeaturesOrDefault(profileId, row);
    if (!feats.subjectDifficultyEnabled) return;

    const wk = isoWeekKey(now);
    const already = await aiCacheRepo.get(profileId, WEEKLY_AUTO, wk);
    if (already) return;

    const res = await analyze(profileId);
    if (!res.ok) return;

    await aiCacheRepo.set(profileId, WEEKLY_AUTO, wk, JSON.stringify({ ranAt: now.toISOString() }));
  } catch {
    /* optional path — swallow */
  }
}
