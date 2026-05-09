import type { MoodLog } from '../domain';
import { createMoodLog, deleteMoodLog, getMoodLogById, getRecentMoodLogs, listMoodLogs, listMoodLogsBySessionId, updateMoodLog } from '../data/repositories';

export function normalizeMoodLog(moodLog: MoodLog): MoodLog {
  return { ...moodLog, mood: moodLog.mood.trim(), note: moodLog.note?.trim() || null };
}

export async function saveMoodLog(moodLog: MoodLog): Promise<number> {
  const normalized = normalizeMoodLog(moodLog);
  return normalized.id ? (await updateMoodLog(normalized), normalized.id) : createMoodLog(normalized);
}

export { createMoodLog, deleteMoodLog, getMoodLogById, getRecentMoodLogs, listMoodLogs, listMoodLogsBySessionId, updateMoodLog };
