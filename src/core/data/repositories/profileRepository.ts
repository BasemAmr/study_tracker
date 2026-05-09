import { getDatabase } from '../database';
import { normalizeText } from '../sql';
import type { Profile } from '../../domain';
import { getDeviceId } from '../../sync/syncIdentity';
import { withWriteLock, execWithBusyRetry } from '../writeLock';

/** Per BEHAVIOR-016 / BEHAVIOR-017: remove child rows; profile row left unchanged (tombstone already set by caller).
 *
 * NOTE: We intentionally do NOT wrap this in BEGIN/COMMIT.
 * `@tauri-apps/plugin-sql` runs each statement on a pooled connection, so
 * `BEGIN TRANSACTION` on connection A and `COMMIT` on connection B is undefined
 * behaviour and is the actual root cause of the "cannot start a transaction
 * within a transaction" / "cannot rollback - no transaction" cascades you see.
 *
 * The deletes below are idempotent: if any one fails the others can be retried
 * later (or by the next sync apply) without corrupting state. The profile row
 * itself stays — the *tombstone* is what makes the profile invisible. */
export async function hardDeleteAllDataForProfileId(profileId: number): Promise<void> {
  await withWriteLock(() => hardDeleteAllDataForProfileIdUnlocked(profileId));
}

/** Same as `hardDeleteAllDataForProfileId` but without acquiring the global write lock.
 * Use ONLY from a caller that already holds the lock (e.g. applyPayload). */
export async function hardDeleteAllDataForProfileIdUnlocked(profileId: number): Promise<void> {
  const database = await getDatabase();
  const run: (sql: string, params?: (string | number | null)[]) => Promise<unknown> =
    (sql, params) => database.execute(sql, params ?? []);
  await runHardDeleteChildrenForProfile(run, profileId);
}

async function runHardDeleteChildrenForProfile(
  run: (sql: string, params?: (string | number | null)[]) => Promise<unknown>,
  profileId: number
): Promise<void> {
  const exec = (sql: string, label: string) =>
    execWithBusyRetry(() => run(sql, [profileId]), { label });

  await exec(
    `DELETE FROM session_tasks WHERE session_id IN (SELECT id FROM study_sessions WHERE profile_id = ?)`,
    'session_tasks(by session)'
  );
  await exec('DELETE FROM mood_logs WHERE profile_id = ?', 'mood_logs');
  await exec('DELETE FROM session_tasks WHERE profile_id = ?', 'session_tasks');
  await exec('DELETE FROM study_sessions WHERE profile_id = ?', 'study_sessions');
  await exec('DELETE FROM subjects WHERE profile_id = ?', 'subjects');
  await exec('DELETE FROM subject_groups WHERE profile_id = ?', 'subject_groups');
  await exec('DELETE FROM goals WHERE profile_id = ?', 'goals');
  await exec('DELETE FROM ai_challenges WHERE profile_id = ?', 'ai_challenges');
  await exec('DELETE FROM notification_log WHERE profile_id = ?', 'notification_log');
  await exec('DELETE FROM notification_settings WHERE profile_id = ?', 'notification_settings');
  await exec('DELETE FROM ai_feature_settings WHERE profile_id = ?', 'ai_feature_settings');
  await exec('DELETE FROM ai_cache WHERE profile_id = ?', 'ai_cache');
}

type ProfileRow = {
  id: number;
  sync_id: string;
  name: string;
  academic_level: string | null;
  owner_device_id: string | null;
  created_at: string;
  updated_at: string;
};

const nowIso = () => new Date().toISOString();

/** returns all profiles WHERE deleted_at IS NULL, ordered by created_at ASC */
export async function listProfiles(): Promise<Profile[]> {
  const database = await getDatabase();
  const rows = await database.select<ProfileRow[]>('SELECT * FROM profiles WHERE deleted_at IS NULL ORDER BY created_at ASC;');
  return rows.map(mapProfile);
}

/** Single profile by id when not deleted — used by AI Coach context fetch. */
export async function getProfileById(profileId: number): Promise<Profile | null> {
  const database = await getDatabase();
  const rows = await database.select<ProfileRow[]>(
    'SELECT * FROM profiles WHERE deleted_at IS NULL AND id = ? LIMIT 1;',
    [profileId]
  );
  return rows[0] ? mapProfile(rows[0]) : null;
}

/** inserts new profile, sets currentProfileId to new id */
export async function createProfile(name: string, academicLevel: string = 'Undergraduate'): Promise<number> {
  const database = await getDatabase();
  const normalizedName = normalizeText(name);
  if (!normalizedName) throw new Error('Profile name is required.');

  const deviceId = await getDeviceId();
  const now = nowIso();

  const result = await database.execute(
    'INSERT INTO profiles (sync_id, name, academic_level, owner_device_id, created_at, updated_at) VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, ?);',
    [normalizedName, academicLevel, deviceId, now, now]
  );

  const newId = Number(result.lastInsertId);
  await setCurrentProfileId(newId);
  return newId;
}

/** Counts of user-visible data for delete confirmation (BEHAVIOR-015). */
export async function getProfileDeletionStats(profileId: number): Promise<{
  studySessions: number;
  subjects: number;
  goals: number;
  moodLogs: number;
}> {
  const database = await getDatabase();
  const sessions = await database.select<Array<{ c: number }>>(
    'SELECT COUNT(*) as c FROM study_sessions WHERE profile_id = ?',
    [profileId]
  );
  const subjects = await database.select<Array<{ c: number }>>(
    'SELECT COUNT(*) as c FROM subjects WHERE profile_id = ?',
    [profileId]
  );
  const goals = await database.select<Array<{ c: number }>>(
    'SELECT COUNT(*) as c FROM goals WHERE profile_id = ?',
    [profileId]
  );
  const moodLogs = await database.select<Array<{ c: number }>>(
    'SELECT COUNT(*) as c FROM mood_logs WHERE profile_id = ?',
    [profileId]
  );
  return {
    studySessions: sessions[0]?.c ?? 0,
    subjects: subjects[0]?.c ?? 0,
    goals: goals[0]?.c ?? 0,
    moodLogs: moodLogs[0]?.c ?? 0
  };
}

/**
 * Hard-delete all child data for a profile, then soft-delete the profile (BEHAVIOR-016).
 * Default profile (sync_id = profile-default) cannot be deleted.
 */
export async function deleteProfile(profileId: number): Promise<void> {
  const database = await getDatabase();

  const row = await database.select<Array<{ sync_id: string }>>(
    'SELECT sync_id FROM profiles WHERE id = ? LIMIT 1',
    [profileId]
  );
  if (row[0]?.sync_id === 'profile-default') {
    throw new Error('The default profile cannot be deleted.');
  }

  const profiles = await listProfiles();
  if (profiles.length <= 1) {
    throw new Error('Cannot delete the last remaining profile.');
  }

  await withWriteLock(async () => {
    // Tombstone FIRST. This is the single statement that defines the
    // profile as "deleted" everywhere (UI lists, sync payloads, FK lookups).
    // Even if a later child-purge statement fails, the profile is already
    // logically gone and can be retried. We don't BEGIN/COMMIT because the
    // Tauri SQL plugin's pooled connections make multi-statement transactions
    // unreliable.
    const now = nowIso();
    await execWithBusyRetry(
      () => database.execute(
        'UPDATE profiles SET deleted_at = ?, updated_at = ? WHERE id = ?',
        [now, now, profileId]
      ),
      { label: 'profiles tombstone' }
    );
    const run: (sql: string, params?: (string | number | null)[]) => Promise<unknown> =
      (sql, params) => database.execute(sql, params ?? []);
    await runHardDeleteChildrenForProfile(run, profileId);
  });

  const currentId = await getCurrentProfileId();
  if (currentId === profileId) {
    const remaining = await listProfiles();
    if (remaining[0]?.id) {
      await setCurrentProfileId(remaining[0].id);
    }
  }
}

/** updates name and academic_level WHERE id = ? */
export async function updateProfile(profile: Profile): Promise<void> {
  const database = await getDatabase();
  const normalizedName = normalizeText(profile.name);
  if (!normalizedName) throw new Error('Profile name is required.');

  if (!profile.id) throw new Error('Profile ID is required for update.');
  // Never update owner_device_id via normal update
  await database.execute(
    'UPDATE profiles SET name = ?, academic_level = ?, updated_at = ? WHERE id = ?;',
    [normalizedName, profile.academicLevel ?? 'Undergraduate', nowIso(), profile.id]
  );
}

/** reads currentProfileId from app_settings, returns as integer, defaults to 1 */
export async function getCurrentProfileId(): Promise<number> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ value: string }>>(
    "SELECT value FROM app_settings WHERE key = 'currentProfileId' LIMIT 1;"
  );
  const parsed = Number(rows[0]?.value ?? 1);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
}

/** writes to app_settings, triggers store update (via the store itself usually) */
export async function setCurrentProfileId(profileId: number): Promise<void> {
  const database = await getDatabase();
  await database.execute(
    `INSERT INTO app_settings (key, value, updated_at) VALUES ('currentProfileId', ?, CURRENT_TIMESTAMP)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP;`,
    [String(profileId)]
  );
}

function mapProfile(row: ProfileRow): Profile {
  return {
    id: row.id,
    syncId: row.sync_id,
    name: row.name,
    academicLevel: row.academic_level ?? undefined,
    ownerDeviceId: row.owner_device_id ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}
