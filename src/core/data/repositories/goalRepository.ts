import { getDatabase } from '../database';
import { toIntegerBoolean } from '../sql';
import type { Goal } from '../../domain';
import { getCurrentProfileId } from './profileRepository';
import { syncTrigger } from '../../sync/syncTrigger';

type GoalRow = {
  id: number;
  name: string;
  target_minutes: number;
  active: number;
  created_at: string;
  updated_at: string;
};

function validateGoal(goal: Goal): Goal {
  const name = goal.name.trim();
  if (!name) {
    throw new Error('Goal name is required.');
  }
  if (goal.targetMinutes <= 0) {
    throw new Error('Goal target minutes must be greater than zero.');
  }
  return { ...goal, name };
}

export async function createGoal(goal: Goal): Promise<number> {
  const normalized = validateGoal(goal);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const result = await database.execute('INSERT INTO goals (profile_id, name, target_minutes, active, sync_id) VALUES (?, ?, ?, ?, lower(hex(randomblob(16))));', [profileId, normalized.name, normalized.targetMinutes, toIntegerBoolean(normalized.active)]);
  syncTrigger.notifyChange();
  return Number(result.lastInsertId);
}

export async function updateGoal(goal: Goal): Promise<void> {
  if (!goal.id) throw new Error('Goal id is required for updates.');
  const normalized = validateGoal(goal);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE goals SET name = ?, target_minutes = ?, active = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [normalized.name, normalized.targetMinutes, toIntegerBoolean(normalized.active), normalized.id as number, profileId]);
  syncTrigger.notifyChange();
}

export async function deleteGoal(id: number): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE goals SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [id, profileId]);
  syncTrigger.notifyChange();
}

export async function getGoalById(id: number): Promise<Goal | null> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<GoalRow[]>('SELECT * FROM goals WHERE deleted_at IS NULL AND id = ? AND profile_id = ? LIMIT 1;', [id, profileId]);
  return rows[0] ? mapGoal(rows[0]) : null;
}

export async function listGoals(): Promise<Goal[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<GoalRow[]>('SELECT * FROM goals WHERE deleted_at IS NULL AND profile_id = ? ORDER BY active DESC, updated_at DESC;', [profileId]);
  return rows.map(mapGoal);
}

export async function getActiveGoals(): Promise<Goal[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<GoalRow[]>('SELECT * FROM goals WHERE deleted_at IS NULL AND profile_id = ? AND active = 1 ORDER BY updated_at DESC;', [profileId]);
  return rows.map(mapGoal);
}

export async function getFirstActiveGoalForProfile(profileId: number): Promise<Goal | null> {
  const database = await getDatabase();
  const rows = await database.select<GoalRow[]>(
    'SELECT * FROM goals WHERE deleted_at IS NULL AND profile_id = ? AND active = 1 ORDER BY updated_at DESC LIMIT 1;',
    [profileId]
  );
  return rows[0] ? mapGoal(rows[0]) : null;
}

export async function setGoalActive(id: number, active: boolean): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE goals SET active = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [toIntegerBoolean(active), id, profileId]);
  syncTrigger.notifyChange();
}

function mapGoal(row: GoalRow): Goal {
  return { id: row.id, name: row.name, targetMinutes: row.target_minutes, active: row.active === 1, createdAt: row.created_at, updatedAt: row.updated_at };
}
