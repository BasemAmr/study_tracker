import { getDatabase } from '../database';
import { normalizeNullableText, normalizeText } from '../sql';
import type { Subject } from '../../domain';
import { getCurrentProfileId } from './profileRepository';
import { syncTrigger } from '../../sync/syncTrigger';

type SubjectRow = {
  id: number;
  name: string;
  color: string | null;
  group_id: number | null;
  difficulty_level: number | null;
  created_at: string;
  session_count?: number;
  group_name?: string | null;
};

function validateSubject(subject: Subject): Subject {
  const name = normalizeText(subject.name ?? '');

  if (!name) {
    throw new Error('Subject name is required.');
  }

  return {
    ...subject,
    name,
    color: normalizeNullableText(subject.color)
  };
}

export async function createSubject(subject: Subject): Promise<number> {
  const normalized = validateSubject(subject);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const result = await database.execute(
    'INSERT INTO subjects (profile_id, name, color, group_id, sync_id, updated_at) VALUES (?, ?, ?, ?, lower(hex(randomblob(16))), CURRENT_TIMESTAMP);',
    [profileId, normalized.name, normalized.color ?? null, normalized.groupId ?? null]
  );
  syncTrigger.notifyChange();
  return Number(result.lastInsertId);
}

export async function updateSubject(subject: Subject): Promise<void> {
  if (!subject.id) {
    throw new Error('Subject id is required for updates.');
  }

  const normalized = validateSubject(subject);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute(
    'UPDATE subjects SET name = ?, color = ?, group_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;',
    [normalized.name, normalized.color ?? null, normalized.groupId ?? null, normalized.id as number, profileId]
  );
  syncTrigger.notifyChange();
}

export async function deleteSubject(id: number): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE subjects SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [id, profileId]);
  syncTrigger.notifyChange();
}

export async function getSubjectById(id: number): Promise<Subject | null> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<SubjectRow[]>('SELECT * FROM subjects WHERE deleted_at IS NULL AND id = ? AND profile_id = ? LIMIT 1;', [id, profileId]);
  return rows[0] ? mapSubject(rows[0]) : null;
}

export async function getSubjectByName(name: string): Promise<Subject | null> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<SubjectRow[]>('SELECT * FROM subjects WHERE deleted_at IS NULL AND profile_id = ? AND name = ? COLLATE NOCASE LIMIT 1;', [profileId, normalizeText(name)]);
  return rows[0] ? mapSubject(rows[0]) : null;
}

export async function listSubjects(): Promise<Subject[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<SubjectRow[]>(`
    SELECT subjects.*, COUNT(study_sessions.id) AS session_count
    FROM subjects
    LEFT JOIN study_sessions ON study_sessions.subject_id = subjects.id AND study_sessions.profile_id = subjects.profile_id
    WHERE subjects.profile_id = ?
    GROUP BY subjects.id
    ORDER BY session_count DESC, subjects.created_at DESC;
  `, [profileId]);
  return rows.map(mapSubject);
}

export async function listSubjectsByGroupId(groupId: number | null): Promise<Subject[]> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = groupId === null
    ? await database.select<SubjectRow[]>('SELECT * FROM subjects WHERE deleted_at IS NULL AND profile_id = ? AND group_id IS NULL ORDER BY name ASC;', [profileId])
    : await database.select<SubjectRow[]>('SELECT * FROM subjects WHERE deleted_at IS NULL AND profile_id = ? AND group_id = ? ORDER BY name ASC;', [profileId, groupId]);
  return rows.map(mapSubject);
}

export async function assignSubjectToGroup(subjectId: number, groupId: number | null): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE subjects SET group_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [groupId, subjectId, profileId]);
  syncTrigger.notifyChange();
}

function mapSubject(row: SubjectRow): Subject {
  return {
    id: row.id,
    name: row.name,
    color: row.color,
    groupId: row.group_id ?? null,
    difficultyLevel: row.difficulty_level ?? null,
    createdAt: row.created_at
  };
}

export async function updateDifficulty(subjectId: number, difficultyLevel: number): Promise<void> {
  if (difficultyLevel < 1 || difficultyLevel > 5) {
    throw new Error('Difficulty level must be between 1 and 5.');
  }

  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute(
    'UPDATE subjects SET difficulty_level = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;',
    [difficultyLevel, subjectId, profileId]
  );
  syncTrigger.notifyChange();
}
