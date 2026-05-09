import { getDatabase } from '../database';
import { normalizeNullableText, normalizeText } from '../sql';
import type { MoodLog } from '../../domain';
import { getCurrentProfileId } from './profileRepository';
import { syncTrigger } from '../../sync/syncTrigger';

type MoodLogRow = { id: number; session_id: number | null; mood: string; note: string | null; created_at: string };

function validateMoodLog(moodLog: MoodLog): MoodLog {
  const mood = normalizeText(moodLog.mood ?? '');
  if (!mood) throw new Error('Mood is required.');
  return { ...moodLog, mood, note: normalizeNullableText(moodLog.note) };
}

export async function createMoodLog(moodLog: MoodLog): Promise<number> {
  const normalized = validateMoodLog(moodLog);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const result = await database.execute('INSERT INTO mood_logs (profile_id, session_id, mood, note, sync_id, updated_at) VALUES (?, ?, ?, ?, lower(hex(randomblob(16))), CURRENT_TIMESTAMP);', [profileId, normalized.sessionId ?? null, normalized.mood, normalized.note ?? null]);
  syncTrigger.notifyChange();
  return Number(result.lastInsertId);
}

export async function updateMoodLog(moodLog: MoodLog): Promise<void> {
  if (!moodLog.id) throw new Error('Mood log id is required for updates.');
  const normalized = validateMoodLog(moodLog);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE mood_logs SET session_id = ?, mood = ?, note = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [normalized.sessionId ?? null, normalized.mood, normalized.note ?? null, normalized.id as number, profileId]);
  syncTrigger.notifyChange();
}

export async function deleteMoodLog(id: number): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE mood_logs SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [id, profileId]);
  syncTrigger.notifyChange();
}

export async function getMoodLogById(id: number): Promise<MoodLog | null> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<MoodLogRow[]>('SELECT * FROM mood_logs WHERE deleted_at IS NULL AND id = ? AND profile_id = ? LIMIT 1;', [id, profileId]);
  return rows[0] ? mapMoodLog(rows[0]) : null;
}

export async function listMoodLogs(): Promise<MoodLog[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<MoodLogRow[]>('SELECT * FROM mood_logs WHERE deleted_at IS NULL AND profile_id = ? ORDER BY created_at DESC;', [profileId]);
  return rows.map(mapMoodLog);
}

export async function listMoodLogsBySessionId(sessionId: number): Promise<MoodLog[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<MoodLogRow[]>('SELECT * FROM mood_logs WHERE deleted_at IS NULL AND session_id = ? AND profile_id = ? ORDER BY created_at DESC;', [sessionId, profileId]);
  return rows.map(mapMoodLog);
}

export async function getRecentMoodLogs(limit = 5): Promise<MoodLog[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<MoodLogRow[]>('SELECT * FROM mood_logs WHERE deleted_at IS NULL AND profile_id = ? ORDER BY created_at DESC LIMIT ?;', [profileId, limit]);
  return rows.map(mapMoodLog);
}

function mapMoodLog(row: MoodLogRow): MoodLog {
  return { id: row.id, sessionId: row.session_id, mood: row.mood, note: row.note, createdAt: row.created_at };
}
