import { getDatabase } from '../database';
import { normalizeNullableText, normalizeText } from '../sql';
import type { SubjectGroup } from '../../domain';
import { getCurrentProfileId } from './profileRepository';
import { syncTrigger } from '../../sync/syncTrigger';

type SubjectGroupRow = {
  id: number;
  name: string;
  color: string | null;
  created_at: string;
};

function validateGroup(group: SubjectGroup): SubjectGroup {
  const name = normalizeText(group.name ?? '');
  if (!name) throw new Error('Group name is required.');
  return { ...group, name, color: normalizeNullableText(group.color) };
}

export async function createSubjectGroup(group: SubjectGroup): Promise<number> {
  const normalized = validateGroup(group);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const result = await database.execute(
    'INSERT INTO subject_groups (profile_id, name, color, sync_id, updated_at) VALUES (?, ?, ?, lower(hex(randomblob(16))), CURRENT_TIMESTAMP);',
    [profileId, normalized.name, normalized.color ?? null]
  );
  syncTrigger.notifyChange();
  return Number(result.lastInsertId);
}

export async function updateSubjectGroup(group: SubjectGroup): Promise<void> {
  if (!group.id) throw new Error('Group id is required for updates.');
  const normalized = validateGroup(group);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute(
    'UPDATE subject_groups SET name = ?, color = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;',
    [normalized.name, normalized.color ?? null, normalized.id as number, profileId]
  );
  syncTrigger.notifyChange();
}

export async function deleteSubjectGroup(id: number): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE subject_groups SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [id, profileId]);
  syncTrigger.notifyChange();
}

export async function listSubjectGroups(): Promise<SubjectGroup[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<SubjectGroupRow[]>(
    'SELECT * FROM subject_groups WHERE deleted_at IS NULL AND profile_id = ? ORDER BY name ASC;',
    [profileId]
  );
  return rows.map(mapGroup);
}

export async function getSubjectGroupById(id: number): Promise<SubjectGroup | null> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<SubjectGroupRow[]>(
    'SELECT * FROM subject_groups WHERE deleted_at IS NULL AND id = ? AND profile_id = ? LIMIT 1;',
    [id, profileId]
  );
  return rows[0] ? mapGroup(rows[0]) : null;
}

function mapGroup(row: SubjectGroupRow): SubjectGroup {
  return {
    id: row.id,
    name: row.name,
    color: row.color,
    createdAt: row.created_at
  };
}
