import { getDatabase } from '../data/database';
import { getDeviceId } from '../sync/syncIdentity';
import { syncTrigger } from '../sync/syncTrigger';

const NOT_DELETED = '(deleted_at IS NULL OR deleted_at = \'\')';

/** True only on a fresh-ish DB: single default profile, original name, no user study data. */
export async function isPristineDbForSyncSeed(): Promise<boolean> {
  const db = await getDatabase();
  const pc = await db.select<Array<{ c: number }>>(
    `SELECT COUNT(*) as c FROM profiles WHERE ${NOT_DELETED}`
  );
  if ((pc[0]?.c ?? 0) !== 1) return false;

  const row = await db.select<Array<{ sync_id: string; name: string }>>(
    `SELECT sync_id, name FROM profiles WHERE ${NOT_DELETED} LIMIT 1`
  );
  if (!row[0]) return false;
  if (String(row[0].sync_id) !== 'profile-default') return false;
  if (String(row[0].name).trim() !== 'Default Profile') return false;

  const tables = ['study_sessions', 'subjects', 'subject_groups', 'goals', 'mood_logs', 'session_tasks'] as const;
  for (const t of tables) {
    const r = await db.select<Array<{ c: number }>>(`SELECT COUNT(*) as c FROM ${t} WHERE ${NOT_DELETED}`);
    if ((r[0]?.c ?? 0) !== 0) return false;
  }
  return true;
}

function nowIso(): string {
  return new Date().toISOString();
}

async function seedProfileBundle(profileId: number, label: string): Promise<void> {
  const db = await getDatabase();
  const ts = nowIso();
  const gRes = await db.execute(
    `INSERT INTO subject_groups (profile_id, name, color, sync_id, created_at, updated_at)
     VALUES (?, ?, ?, lower(hex(randomblob(16))), ?, ?);`,
    [profileId, `Dev group (${label})`, '#63946d', ts, ts]
  );
  const groupId = Number(gRes.lastInsertId);

  const sRes = await db.execute(
    `INSERT INTO subjects (profile_id, name, color, group_id, sync_id, created_at, updated_at)
     VALUES (?, ?, ?, ?, lower(hex(randomblob(16))), ?, ?);`,
    [profileId, `Dev subject (${label})`, '#5a7a5a', groupId, ts, ts]
  );
  const subjectId = Number(sRes.lastInsertId);

  const start = new Date();
  start.setHours(start.getHours() - 1);
  const end = new Date();
  end.setMinutes(end.getMinutes() - 15);
  const startAt = start.toISOString();
  const endAt = end.toISOString();

  await db.execute(
    `INSERT INTO study_sessions (
      profile_id, start_at, end_at, duration_minutes, subject_id, subject_name, topic,
      mode, break_minutes, sync_id, created_at, updated_at
    ) VALUES (?, ?, ?, 45, ?, ?, ?, 'manual', 0, lower(hex(randomblob(16))), ?, ?);`,
    [
      profileId,
      startAt,
      endAt,
      subjectId,
      `Dev subject (${label})`,
      `Dev session (${label})`,
      ts,
      ts
    ]
  );
}

export type SyncSeedRole = 'desktop' | 'phone';

/**
 * Inserts the manual “before sync” scenario using this machine’s clock (ISO timestamps).
 * Only call when `isPristineDbForSyncSeed()` is true.
 */
export async function seedSyncTestScenario(role: SyncSeedRole): Promise<void> {
  const db = await getDatabase();
  const deviceId = await getDeviceId();
  const ts = nowIso();

  const defaultName = role === 'desktop' ? 'Edit First' : 'Edit Second LLW';
  const secondName = role === 'desktop' ? 'new profile from desktop' : 'new profile from phone';

  // Note: no BEGIN/COMMIT — tauri-plugin-sql uses a connection pool, so
  // BEGIN and COMMIT can land on different connections. Statements run
  // independently; this is a dev seeder so partial failure is fine.
  await db.execute(
    `UPDATE profiles SET name = ?, academic_level = 'Postgraduate', updated_at = ? WHERE sync_id = 'profile-default';`,
    [defaultName, ts]
  );

  const pRes = await db.execute(
    `INSERT INTO profiles (sync_id, name, academic_level, owner_device_id, created_at, updated_at)
     VALUES (lower(hex(randomblob(16))), ?, 'Postgraduate', ?, ?, ?);`,
    [secondName, deviceId, ts, ts]
  );
  const secondId = Number(pRes.lastInsertId);

  const defRow = await db.select<Array<{ id: number }>>(
    `SELECT id FROM profiles WHERE sync_id = 'profile-default' LIMIT 1;`
  );
  const defaultId = defRow[0]?.id ?? 1;

  await seedProfileBundle(defaultId, 'default');
  await seedProfileBundle(secondId, 'second');

  await db.execute(
    `INSERT INTO app_settings (key, value, updated_at) VALUES ('currentProfileId', ?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;`,
    [String(defaultId), ts]
  );

  syncTrigger.notifyChange();
}
