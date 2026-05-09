import { getDatabase } from '../data/database';
import { getSettingByKey, setSettingByKey } from '../data/repositories/appSettingsRepository';
export function syncMergeSettingKey(peerDeviceId: string): string {
  return `syncMergeDecision_${peerDeviceId}`;
}

export async function getSyncMergeDecision(peerDeviceId: string): Promise<'merge' | 'separate' | null> {
  const row = await getSettingByKey(syncMergeSettingKey(peerDeviceId));
  const v = row?.value?.trim();
  if (v === 'merge' || v === 'separate') return v;
  return null;
}

export async function setSyncMergeDecision(peerDeviceId: string, decision: 'merge' | 'separate'): Promise<void> {
  await setSettingByKey(syncMergeSettingKey(peerDeviceId), decision);
}

export async function hasAnySyncStateForPeer(
  peerDeviceId: string,
  transport: string = 'wifi'
): Promise<boolean> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ c: number }>>(
    'SELECT COUNT(*) as c FROM sync_state WHERE peer_device_id = ? AND transport = ?',
    [peerDeviceId, transport]
  );
  return (rows[0]?.c ?? 0) > 0;
}

const DATA_TABLES = [
  'subject_groups',
  'subjects',
  'goals',
  'study_sessions',
  'session_tasks',
  'mood_logs',
  'ai_challenges'
];

/** Intentionally excluded from sync payloads (device-local only; Tech Plan §2):
 * notification_settings · notification_log · ai_feature_settings · ai_cache — do NOT add these to DATA_TABLES. */

/** Rows in the incoming payload for profile-default (per BEHAVIOR-010, BEHAVIOR-011). */
export function countRemoteDefaultProfileDataInPayload(p: { tables?: Partial<Record<string, Record<string, unknown>[]>> }): number {
  if (!p.tables) return 0;
  let n = 0;
  for (const t of DATA_TABLES) {
    const rows = p.tables[t];
    if (!rows) continue;
    for (const row of rows) {
      if ((row as { profile_sync_id?: string })?.profile_sync_id === 'profile-default') n++;
    }
  }
  const prows = p.tables['profiles'] ?? [];
  for (const row of prows) {
    if (String((row as { sync_id?: string }).sync_id) === 'profile-default') n++;
  }
  return n;
}

/** Local default profile (sync_id) row counts; empty iff all four are zero. */
export async function countLocalDefaultProfileData(): Promise<{
  sessions: number;
  subjects: number;
  goals: number;
  moodLogs: number;
  profileId: number | null;
}> {
  const database = await getDatabase();
  const pr = await database.select<Array<{ id: number }>>(
    "SELECT id FROM profiles WHERE sync_id = 'profile-default' AND (deleted_at IS NULL OR deleted_at = '') LIMIT 1"
  );
  const profileId = pr[0]?.id ?? null;
  if (profileId == null) {
    return { sessions: 0, subjects: 0, goals: 0, moodLogs: 0, profileId: null };
  }
  const c = (sql: string) =>
    database.select<Array<{ c: number }>>(sql, [profileId]);
  const sessions = (await c('SELECT COUNT(*) as c FROM study_sessions WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]
    ?.c ?? 0;
  const subjects = (await c('SELECT COUNT(*) as c FROM subjects WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]
    ?.c ?? 0;
  const goals = (await c('SELECT COUNT(*) as c FROM goals WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]
    ?.c ?? 0;
  const moodLogs = (await c('SELECT COUNT(*) as c FROM mood_logs WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]
    ?.c ?? 0;
  return { sessions, subjects, goals, moodLogs, profileId };
}

export function isLocalDefaultProfileNotEmpty(agg: Awaited<ReturnType<typeof countLocalDefaultProfileData>>): boolean {
  return (agg.sessions + agg.subjects + agg.goals + agg.moodLogs) > 0;
}
