import { getDatabase } from '../database';

export async function get(profileId: number, feature: string, key: string): Promise<string | null> {
  const database = await getDatabase();
  const rows = await database.select<{ payload_json: string }[]>(
    'SELECT payload_json FROM ai_cache WHERE profile_id = ? AND feature = ? AND cache_key = ? LIMIT 1',
    [profileId, feature, key]
  );
  return rows[0]?.payload_json ?? null;
}

export async function set(profileId: number, feature: string, key: string, payloadJson: string): Promise<void> {
  const database = await getDatabase();
  await database.execute(
    `INSERT INTO ai_cache (profile_id, feature, cache_key, payload_json, updated_at)
     VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
     ON CONFLICT(profile_id, feature, cache_key) DO UPDATE SET
       payload_json = excluded.payload_json,
       updated_at = CURRENT_TIMESTAMP`,
    [profileId, feature, key, payloadJson]
  );
}

export async function purgeOlderThan(days: number): Promise<void> {
  if (days <= 0) return;
  const database = await getDatabase();
  await database.execute(`DELETE FROM ai_cache WHERE updated_at < datetime('now', ?)`, [`-${Math.floor(days)} days`]);
}
