import type { StudySessionMode } from '../domain';
import { listSessionsForProfile } from '../data/repositories/sessionRepository';
import { calculateStreaks } from '../utils/streakUtils';

/** Compact 30-day study fingerprint for smarter Groq prompts (Feature 2). */
export async function buildThirtyDayWeakSpotSummary(profileId: number): Promise<string> {
  const since = new Date();
  since.setDate(since.getDate() - 30);
  const sinceIso = since.toISOString();
  const sessions = await listSessionsForProfile(profileId, {
    startFrom: sinceIso,
    limit: 5000,
    offset: 0
  });

  if (sessions.length === 0) {
    return 'Last 30 days: no logged sessions.';
  }

  const bySubject = new Map<
    string,
    { minutes: number; sessions: number; moods: Record<string, number>; after8pm: number }
  >();
  let totalMin = 0;
  let after8PmAll = 0;
  const modeHits: Record<StudySessionMode, number> = {
    pomodoro: 0,
    long_session: 0,
    manual: 0
  };

  for (const s of sessions) {
    totalMin += s.durationMinutes;
    const sn = (s.subjectName ?? 'General').trim() || 'General';
    modeHits[s.mode]++;
    const h = new Date(s.startAt).getHours();
    const late = h >= 20 || h < 5;
    if (h >= 20) after8PmAll++;

    const cur =
      bySubject.get(sn) ?? { minutes: 0, sessions: 0, moods: {}, after8pm: 0 };
    cur.minutes += s.durationMinutes;
    cur.sessions += 1;
    if (s.mood) cur.moods[s.mood] = (cur.moods[s.mood] ?? 0) + 1;
    if (late && h >= 20) cur.after8pm++;
    bySubject.set(sn, cur);
  }

  let mostSubject = '';
  let mostMin = -1;
  let leastSubject = '';
  let leastMin = Infinity;
  for (const [name, v] of bySubject.entries()) {
    if (v.minutes > mostMin) {
      mostMin = v.minutes;
      mostSubject = name;
    }
    if (v.minutes < leastMin) {
      leastMin = v.minutes;
      leastSubject = name;
    }
  }

  const avgDur = Math.round(totalMin / sessions.length);
  let topMood = 'n/a';
  let topMoodC = 0;
  const moodAgg: Record<string, number> = {};
  for (const s of sessions) {
    const m = s.mood?.trim();
    if (!m) continue;
    moodAgg[m] = (moodAgg[m] ?? 0) + 1;
    if ((moodAgg[m] ?? 0) > topMoodC) {
      topMoodC = moodAgg[m] ?? 0;
      topMood = m;
    }
  }

  const studyDates = sessions.map((s) => new Date(s.startAt));
  studyDates.sort((a, b) => a.getTime() - b.getTime());
  const streaks = calculateStreaks(studyDates);

  let preferredMode: StudySessionMode = 'manual';
  let modeMax = 0;
  (['pomodoro', 'long_session', 'manual'] as const).forEach((m) => {
    if (modeHits[m] > modeMax) {
      modeMax = modeHits[m];
      preferredMode = m;
    }
  });

  const uniqueSubjects = bySubject.size;
  const pctAfter8 =
    sessions.length > 0 ? Math.round((after8PmAll / sessions.length) * 100) : 0;

  const lines = [
    `Rolling 30-day window (${sessions.length} sessions, ${totalMin} minutes total).`,
    `Average session duration: ${avgDur} minutes.`,
    `Most studied subject: ${mostSubject} (${mostMin} min across ${bySubject.get(mostSubject)?.sessions ?? 0} sessions).`,
    `Least studied logged subject by time: ${leastSubject} (${leastMin} minutes). Unique subjects touched: ${uniqueSubjects}.`,
    `Most frequent mood tag: ${topMood} (${topMoodC} mentions).`,
    `Sessions starting at or after 20:00 local: ${pctAfter8}% of sessions (${after8PmAll} hits).`,
    `Current uninterrupted study-day streak (from logged days): ${streaks.currentStreak}; longest streak in window context: ${streaks.longestStreak}.`,
    `Preferred session mode by count: ${preferredMode.replace('_', ' ')}.`,
    '',
    `Instruction for task design (examples only — invent fresh wording): tailor challenges that nudge realistic stretch goals (e.g. late-night learner "Night Owl" shift, narrowly focused learner "Branch Out" to dormant subjects, "Deep Work" length targets, aligning with dominant mood peaks). Stay inside JSON schema the user supplies.`
  ];

  return lines.join('\n');
}

/** Lightweight 7-day figures for Coach + weekly narrative scaffolding. */
export async function summarizeLastSevenDays(profileId: number): Promise<{
  totalMinutes: number;
  sessionCount: number;
  perSubjectMinutes: Record<string, number>;
  topSubject: string | null;
}> {
  const since = new Date();
  since.setDate(since.getDate() - 7);
  const sessions = await listSessionsForProfile(profileId, {
    startFrom: since.toISOString(),
    limit: 5000,
    offset: 0
  });

  let totalMinutes = 0;
  const perSubjectMinutes: Record<string, number> = {};
  for (const s of sessions) {
    totalMinutes += s.durationMinutes;
    const sn = (s.subjectName ?? 'General').trim() || 'General';
    perSubjectMinutes[sn] = (perSubjectMinutes[sn] ?? 0) + s.durationMinutes;
  }

  let topSubject: string | null = null;
  let maxM = -1;
  for (const [sn, m] of Object.entries(perSubjectMinutes)) {
    if (m > maxM) {
      maxM = m;
      topSubject = sn;
    }
  }

  return {
    totalMinutes,
    sessionCount: sessions.length,
    perSubjectMinutes,
    topSubject
  };
}
