import { getDatabase } from '../database';
import { toIntegerBoolean, toBoolean, normalizeText } from '../sql';
import type { SessionTask } from '../../domain';
import { getCurrentProfileId } from './profileRepository';
import { syncTrigger } from '../../sync/syncTrigger';

type SessionTaskRow = { id: number; session_id: number; title: string; completed: number; created_at: string };

function validateSessionTask(task: SessionTask): SessionTask {
  const title = normalizeText(task.title ?? '');
  if (!title) throw new Error('Task title is required.');
  return { ...task, title };
}

export async function createSessionTask(sessionId: number, task: SessionTask): Promise<number> {
  const normalized = validateSessionTask(task);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const result = await database.execute('INSERT INTO session_tasks (profile_id, session_id, title, completed, sync_id, updated_at) VALUES (?, ?, ?, ?, lower(hex(randomblob(16))), CURRENT_TIMESTAMP);', [profileId, sessionId, normalized.title, toIntegerBoolean(normalized.completed)]);
  syncTrigger.notifyChange();
  return Number(result.lastInsertId);
}

export async function updateSessionTask(task: SessionTask): Promise<void> {
  if (!task.id) throw new Error('Task id is required for updates.');
  const normalized = validateSessionTask(task);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE session_tasks SET title = ?, completed = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [normalized.title, toIntegerBoolean(normalized.completed), normalized.id as number, profileId]);
  syncTrigger.notifyChange();
}

export async function deleteSessionTask(id: number): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE session_tasks SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [id, profileId]);
  syncTrigger.notifyChange();
}

export async function listSessionTasksBySessionId(sessionId: number): Promise<SessionTask[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<SessionTaskRow[]>('SELECT * FROM session_tasks WHERE deleted_at IS NULL AND session_id = ? AND profile_id = ? ORDER BY id ASC;', [sessionId, profileId]);
  return rows.map(mapSessionTask);
}

export async function markSessionTaskComplete(id: number, completed: boolean): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE session_tasks SET completed = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [toIntegerBoolean(completed), id, profileId]);
  syncTrigger.notifyChange();
}

export async function replaceSessionTasks(sessionId: number, tasks: SessionTask[]): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE session_tasks SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE session_id = ? AND profile_id = ?;', [sessionId, profileId]);
  for (const task of tasks) {
    await createSessionTask(sessionId, task);
  }
}

function mapSessionTask(row: SessionTaskRow): SessionTask {
  return { id: row.id, sessionId: row.session_id, title: row.title, completed: toBoolean(row.completed), createdAt: row.created_at };
}
