/**
 * SyncEngine — transport-agnostic core
 *
 * buildPayload() / applyPayload() — LWW on updated_at, FK remapping (profile / subject / session).
 */

import { getDatabase } from '../data/database';
import { getSettingByKey, setSettingByKey } from '../data/repositories/appSettingsRepository';
import { hardDeleteAllDataForProfileIdUnlocked } from '../data/repositories/profileRepository';
import { syncTrigger } from './syncTrigger';
import { profileStore } from '../stores/profileStore';
import { toasts } from '../stores/toastStore';
import { getDeviceId, getDeviceName } from './syncIdentity';
import { withWriteLock, execWithBusyRetry } from '../data/writeLock';

export { getDeviceId, getDeviceName, setDeviceName, getPeerPairingCode, savePeerPairingCode, initializeOwnership } from './syncIdentity';

let _isSyncing = false;
export const isSyncing = () => _isSyncing;

// ─── Types ────────────────────────────────────────────────────────────────────

export type SyncTableName =
  | 'profiles'
  | 'subject_groups'
  | 'subjects'
  | 'study_sessions'
  | 'session_tasks'
  | 'goals'
  | 'mood_logs'
  | 'ai_challenges';

export type SyncPayload = {
  payload_version: 1;
  device_id: string;
  device_name: string;
  /** sync_id of the profile whose data is included */
  profile_sync_id: string | null;
  exported_at: string;
  since_timestamp: string;
  tables: Partial<Record<SyncTableName, Record<string, unknown>[]>>;
};

export type SyncResult = {
  inserted: number;
  updated: number;
  skipped: number;
  deferred: number;
  errors: string[];
};

export type ApplyPayloadOptions = {
  /** Device id of the peer (usually equals payload.device_id). */
  peerDeviceId?: string;
  /** First-sync decision for default profile. Defaults to merge. */
  mergeMode?: 'merge' | 'separate';
};

export type SyncHistoryEntry = {
  peerDeviceId: string | null;
  peerDeviceName: string | null;
  transport: string;
  direction: 'push' | 'pull' | 'bidirectional';
  rowsSent: number;
  rowsReceived: number;
  success: boolean;
  errorMessage?: string;
};

// ─── Table config (upsert) ────────────────────────────────────────────────────

type TableCfg = {
  upsertCols: string[];
  /** UNIQUE conflict target */
  conflictCol: 'sync_id' | 'id';
  idCol: 'sync_id' | 'id';
  upsertSql: (cols: string[]) => string;
};

const TABLE_CONFIG: Record<SyncTableName, TableCfg> = {
  study_sessions: {
    idCol: 'sync_id',
    upsertCols: [
      'sync_id', 'profile_id', 'start_at', 'end_at', 'duration_minutes',
      'subject_id', 'subject_name', 'topic', 'chapter_tag', 'mood', 'notes',
      'mode', 'break_minutes', 'background_image', 'created_at', 'updated_at', 'deleted_at'
    ],
    conflictCol: 'sync_id',
    upsertSql: (cols) =>
      `INSERT INTO study_sessions (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
       ON CONFLICT(sync_id) DO UPDATE SET
         start_at = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.start_at ELSE study_sessions.start_at END,
         end_at = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.end_at ELSE study_sessions.end_at END,
         duration_minutes = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.duration_minutes ELSE study_sessions.duration_minutes END,
         subject_id = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.subject_id ELSE study_sessions.subject_id END,
         subject_name = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.subject_name ELSE study_sessions.subject_name END,
         topic = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.topic ELSE study_sessions.topic END,
         chapter_tag = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.chapter_tag ELSE study_sessions.chapter_tag END,
         mood = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.mood ELSE study_sessions.mood END,
         notes = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.notes ELSE study_sessions.notes END,
         mode = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.mode ELSE study_sessions.mode END,
         break_minutes = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.break_minutes ELSE study_sessions.break_minutes END,
         background_image = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.background_image ELSE study_sessions.background_image END,
         deleted_at = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.deleted_at ELSE study_sessions.deleted_at END,
         updated_at = CASE WHEN excluded.updated_at > study_sessions.updated_at THEN excluded.updated_at ELSE study_sessions.updated_at END`
  },
  subjects: {
    idCol: 'sync_id',
    upsertCols: ['sync_id', 'profile_id', 'name', 'color', 'group_id', 'created_at', 'updated_at', 'deleted_at'],
    conflictCol: 'sync_id',
    upsertSql: (cols) =>
      `INSERT INTO subjects (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
       ON CONFLICT(sync_id) DO UPDATE SET
         name = CASE WHEN excluded.updated_at > subjects.updated_at THEN excluded.name ELSE subjects.name END,
         color = CASE WHEN excluded.updated_at > subjects.updated_at THEN excluded.color ELSE subjects.color END,
         group_id = CASE WHEN excluded.updated_at > subjects.updated_at THEN excluded.group_id ELSE subjects.group_id END,
         deleted_at = CASE WHEN excluded.updated_at > subjects.updated_at THEN excluded.deleted_at ELSE subjects.deleted_at END,
         updated_at = CASE WHEN excluded.updated_at > subjects.updated_at THEN excluded.updated_at ELSE subjects.updated_at END`
  },
  subject_groups: {
    idCol: 'sync_id',
    upsertCols: ['sync_id', 'profile_id', 'name', 'color', 'created_at', 'updated_at', 'deleted_at'],
    conflictCol: 'sync_id',
    upsertSql: (cols) =>
      `INSERT INTO subject_groups (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
       ON CONFLICT(sync_id) DO UPDATE SET
         name = CASE WHEN excluded.updated_at > subject_groups.updated_at THEN excluded.name ELSE subject_groups.name END,
         color = CASE WHEN excluded.updated_at > subject_groups.updated_at THEN excluded.color ELSE subject_groups.color END,
         deleted_at = CASE WHEN excluded.updated_at > subject_groups.updated_at THEN excluded.deleted_at ELSE subject_groups.deleted_at END,
         updated_at = CASE WHEN excluded.updated_at > subject_groups.updated_at THEN excluded.updated_at ELSE subject_groups.updated_at END`
  },
  session_tasks: {
    idCol: 'sync_id',
    upsertCols: ['sync_id', 'profile_id', 'session_id', 'title', 'completed', 'created_at', 'updated_at', 'deleted_at'],
    conflictCol: 'sync_id',
    upsertSql: (cols) =>
      `INSERT INTO session_tasks (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
       ON CONFLICT(sync_id) DO UPDATE SET
         title = CASE WHEN excluded.updated_at > session_tasks.updated_at THEN excluded.title ELSE session_tasks.title END,
         completed = CASE WHEN excluded.updated_at > session_tasks.updated_at THEN excluded.completed ELSE session_tasks.completed END,
         deleted_at = CASE WHEN excluded.updated_at > session_tasks.updated_at THEN excluded.deleted_at ELSE session_tasks.deleted_at END,
         updated_at = CASE WHEN excluded.updated_at > session_tasks.updated_at THEN excluded.updated_at ELSE session_tasks.updated_at END`
  },
  goals: {
    idCol: 'sync_id',
    upsertCols: ['sync_id', 'profile_id', 'name', 'target_minutes', 'active', 'created_at', 'updated_at', 'deleted_at'],
    conflictCol: 'sync_id',
    upsertSql: (cols) =>
      `INSERT INTO goals (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
       ON CONFLICT(sync_id) DO UPDATE SET
         name = CASE WHEN excluded.updated_at > goals.updated_at THEN excluded.name ELSE goals.name END,
         target_minutes = CASE WHEN excluded.updated_at > goals.updated_at THEN excluded.target_minutes ELSE goals.target_minutes END,
         active = CASE WHEN excluded.updated_at > goals.updated_at THEN excluded.active ELSE goals.active END,
         deleted_at = CASE WHEN excluded.updated_at > goals.updated_at THEN excluded.deleted_at ELSE goals.deleted_at END,
         updated_at = CASE WHEN excluded.updated_at > goals.updated_at THEN excluded.updated_at ELSE goals.updated_at END`
  },
  mood_logs: {
    idCol: 'sync_id',
    upsertCols: ['sync_id', 'profile_id', 'session_id', 'mood', 'note', 'created_at', 'updated_at', 'deleted_at'],
    conflictCol: 'sync_id',
    upsertSql: (cols) =>
      `INSERT INTO mood_logs (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
       ON CONFLICT(sync_id) DO UPDATE SET
         mood = CASE WHEN excluded.updated_at > mood_logs.updated_at THEN excluded.mood ELSE mood_logs.mood END,
         note = CASE WHEN excluded.updated_at > mood_logs.updated_at THEN excluded.note ELSE mood_logs.note END,
         deleted_at = CASE WHEN excluded.updated_at > mood_logs.updated_at THEN excluded.deleted_at ELSE mood_logs.deleted_at END,
         updated_at = CASE WHEN excluded.updated_at > mood_logs.updated_at THEN excluded.updated_at ELSE mood_logs.updated_at END`
  },
  ai_challenges: {
    idCol: 'id',
    upsertCols: [
      'id', 'profile_id', 'tier', 'title', 'description', 'icon', 'metric', 'target',
      'expires_at', 'difficulty', 'reward_badge_name', 'reward_badge_icon',
      'completed', 'raw_response', 'created_at', 'updated_at',
      'sub_targets_json', 'unit_min_minutes', 'status'
    ],
    conflictCol: 'id',
    upsertSql: (cols) =>
      `INSERT INTO ai_challenges (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
       ON CONFLICT(id) DO UPDATE SET
         tier = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.tier ELSE ai_challenges.tier END,
         title = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.title ELSE ai_challenges.title END,
         description = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.description ELSE ai_challenges.description END,
         icon = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.icon ELSE ai_challenges.icon END,
         metric = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.metric ELSE ai_challenges.metric END,
         target = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.target ELSE ai_challenges.target END,
         expires_at = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.expires_at ELSE ai_challenges.expires_at END,
         difficulty = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.difficulty ELSE ai_challenges.difficulty END,
         reward_badge_name = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.reward_badge_name ELSE ai_challenges.reward_badge_name END,
         reward_badge_icon = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.reward_badge_icon ELSE ai_challenges.reward_badge_icon END,
         completed = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.completed ELSE ai_challenges.completed END,
         raw_response = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.raw_response ELSE ai_challenges.raw_response END,
         sub_targets_json = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.sub_targets_json ELSE ai_challenges.sub_targets_json END,
         unit_min_minutes = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.unit_min_minutes ELSE ai_challenges.unit_min_minutes END,
         status = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.status ELSE ai_challenges.status END,
         updated_at = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.updated_at ELSE ai_challenges.updated_at END,
         profile_id = CASE WHEN excluded.updated_at > ai_challenges.updated_at THEN excluded.profile_id ELSE ai_challenges.profile_id END`
  },
  profiles: {
    idCol: 'sync_id',
    upsertCols: ['sync_id', 'name', 'academic_level', 'owner_device_id', 'created_at', 'updated_at', 'deleted_at'],
    conflictCol: 'sync_id',
    upsertSql: (cols) => {
      const updateCols = cols.filter((c) => c !== 'sync_id' && c !== 'created_at' && c !== 'owner_device_id');
      const updateClause = updateCols
        .map((c) => `${c} = excluded.${c}`)
        .join(', ');
      return `INSERT INTO profiles (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})
              ON CONFLICT(sync_id) DO UPDATE SET ${updateClause}`;
    }
  }
};

/** BEHAVIOR-021 apply order (FKs). Local-only: ai_challenge_history (not listed). */
const SYNC_TABLES: SyncTableName[] = [
  'profiles',
  'subject_groups',
  'subjects',
  'study_sessions',
  'session_tasks',
  'mood_logs',
  'goals',
  'ai_challenges'
];

const NEVER_SYNC_SETTINGS = [
  'currentProfileId',
  'syncDeviceId',
  'syncDeviceName',
  'wifiSyncPairingCode',
  'wifiSyncEnabled',
  'wifiLanPeerBookmarks',
  'cloudSyncEnabled',
  'lastSyncTimestamp'
];
void NEVER_SYNC_SETTINGS;

function buildTableSelectSql(table: SyncTableName): string {
  switch (table) {
    case 'profiles':
      return 'SELECT * FROM profiles WHERE sync_id IS NOT NULL';
    case 'subject_groups':
      return `SELECT t.*, p.sync_id AS profile_sync_id
        FROM subject_groups t JOIN profiles p ON t.profile_id = p.id
        WHERE t.sync_id IS NOT NULL`;
    case 'subjects':
      return `SELECT t.*, p.sync_id AS profile_sync_id, g.sync_id AS group_sync_id
        FROM subjects t
        JOIN profiles p ON t.profile_id = p.id
        LEFT JOIN subject_groups g ON t.group_id = g.id
        WHERE t.sync_id IS NOT NULL`;
    case 'goals':
      return `SELECT t.*, p.sync_id AS profile_sync_id
        FROM goals t JOIN profiles p ON t.profile_id = p.id
        WHERE t.sync_id IS NOT NULL`;
    case 'study_sessions':
      return `SELECT t.*, p.sync_id AS profile_sync_id, s.sync_id AS subject_sync_id
        FROM study_sessions t
        JOIN profiles p ON t.profile_id = p.id
        LEFT JOIN subjects s ON t.subject_id = s.id
        WHERE t.sync_id IS NOT NULL`;
    case 'session_tasks':
      return `SELECT t.*, p.sync_id AS profile_sync_id, ss.sync_id AS session_sync_id
        FROM session_tasks t
        JOIN profiles p ON t.profile_id = p.id
        JOIN study_sessions ss ON t.session_id = ss.id
        WHERE t.sync_id IS NOT NULL`;
    case 'mood_logs':
      return `SELECT t.*, p.sync_id AS profile_sync_id, ss.sync_id AS session_sync_id
        FROM mood_logs t
        JOIN profiles p ON t.profile_id = p.id
        LEFT JOIN study_sessions ss ON t.session_id = ss.id
        WHERE t.sync_id IS NOT NULL`;
    case 'ai_challenges':
      return `SELECT t.*, p.sync_id AS profile_sync_id
        FROM ai_challenges t JOIN profiles p ON t.profile_id = p.id
        WHERE t.id IS NOT NULL`;
    default:
      return 'SELECT 0 WHERE 0';
  }
}

function syncTimeExpr(column: string): string {
  return `(CASE
    WHEN typeof(${column}) = 'integer' THEN (${column} / CASE WHEN ${column} > 1000000000000 THEN 1000 ELSE 1 END)
    ELSE CAST(strftime('%s', replace(replace(${column}, 'T', ' '), 'Z', '')) AS INTEGER)
  END)`;
}

function syncSinceExpr(): string {
  return `CAST(strftime('%s', replace(replace(?, 'T', ' '), 'Z', '')) AS INTEGER)`;
}

/**
 * Parses any timestamp (ISO string, SQLite string, unix seconds, unix millis)
 * into Unix epoch milliseconds.
 */
function toSyncEpochMs(raw: unknown): number | null {
  if (raw === null || raw === undefined) return null;

  if (typeof raw === 'number') {
    return raw > 1000000000000 ? Math.floor(raw) : Math.floor(raw * 1000);
  }

  const value = String(raw).trim();
  if (!value) return null;

  const asNum = Number(value);
  if (Number.isFinite(asNum)) {
    return asNum > 1000000000000 ? Math.floor(asNum) : Math.floor(asNum * 1000);
  }

  try {
    const normalized = value.includes(' ') && !value.includes('T') ? value.replace(' ', 'T') : value;
    let withTz = normalized;
    if (!withTz.endsWith('Z') && !withTz.includes('+')) {
      const lastDash = withTz.lastIndexOf('-');
      const tIndex = withTz.indexOf('T');
      if (tIndex === -1 || lastDash <= tIndex) {
        withTz = `${withTz}Z`;
      }
    }
    const parsed = Date.parse(withTz);
    return Number.isFinite(parsed) ? Math.floor(parsed) : null;
  } catch {
    return null;
  }
}

function mapIncomingProfileSyncId(
  profileSyncId: string,
  mergeMode: 'merge' | 'separate',
  payload: SyncPayload,
  myDeviceId: string,
  legacyDefaultProfileSyncIds: Set<string> = new Set()
): string {
  if (mergeMode === 'merge' && legacyDefaultProfileSyncIds.has(profileSyncId)) {
    return 'profile-default';
  }
  if (mergeMode === 'separate' && payload.device_id && payload.device_id !== myDeviceId) {
    if (profileSyncId === 'profile-default') {
      return `profile-default-${payload.device_id}`;
    }
  }
  return profileSyncId;
}

/** Same display name + profile but different sync_id (parallel seed / first sync). Merge into one row by LWW. */
type DupMergeOutcome = 'proceed' | 'skip' | 'handled';

async function mergePerProfileNameDuplicateOnApply(
  database: Awaited<ReturnType<typeof getDatabase>>,
  table: 'subjects' | 'subject_groups',
  row: Record<string, unknown>
): Promise<DupMergeOutcome> {
  const name = String((row as { name?: unknown }).name ?? '').trim();
  const incomingSyncId = String((row as { sync_id?: unknown }).sync_id ?? '');
  const profileId = Number((row as { profile_id?: unknown }).profile_id);
  if (!name || !incomingSyncId || !Number.isFinite(profileId)) return 'proceed';

  const rows = await database.select<Array<{ id: number; sync_id: string; updated_at: string | number | null }>>(
    `SELECT id, sync_id, updated_at FROM ${table} WHERE profile_id = ? AND name = ? AND (deleted_at IS NULL OR deleted_at = '')`,
    [profileId, name]
  );

  const others = rows.filter((r) => r.sync_id !== incomingSyncId);
  if (others.length === 0) return 'proceed';

  const incomingMs = toSyncEpochMs((row as { updated_at: unknown }).updated_at);
  let maxLocal = Number.NEGATIVE_INFINITY;
  for (const r of others) {
    const ms = toSyncEpochMs(r.updated_at);
    if (ms !== null) maxLocal = Math.max(maxLocal, ms);
  }

  if (incomingMs === null || incomingMs <= maxLocal) {
    return 'skip';
  }

  let winner = others[0];
  let winnerMs = toSyncEpochMs(winner.updated_at) ?? Number.NEGATIVE_INFINITY;
  for (const r of others) {
    const ms = toSyncEpochMs(r.updated_at) ?? Number.NEGATIVE_INFINITY;
    if (ms > winnerMs) {
      winnerMs = ms;
      winner = r;
    }
  }

  const tomb = new Date().toISOString();

  const orphanSameSync = await database.select<Array<{ id: number }>>(
    `SELECT id FROM ${table} WHERE sync_id = ? AND id != ? LIMIT 1`,
    [incomingSyncId, winner.id]
  );
  if (orphanSameSync[0]) {
    await database.execute(`UPDATE ${table} SET deleted_at = ? WHERE id = ?`, [tomb, orphanSameSync[0].id]);
  }

  for (const r of others) {
    if (r.id !== winner.id) {
      await database.execute(`UPDATE ${table} SET deleted_at = ? WHERE id = ?`, [tomb, r.id]);
    }
  }

  if (table === 'subjects') {
    await database.execute(
      `UPDATE subjects SET sync_id = ?, color = ?, group_id = ?, updated_at = ?, deleted_at = ?, created_at = COALESCE(?, created_at) WHERE id = ?`,
      [
        incomingSyncId,
        (row as { color?: unknown }).color ?? null,
        (row as { group_id?: unknown }).group_id ?? null,
        (row as { updated_at: unknown }).updated_at,
        (row as { deleted_at?: unknown }).deleted_at ?? null,
        (row as { created_at?: unknown }).created_at ?? null,
        winner.id
      ]
    );
  } else {
    await database.execute(
      `UPDATE subject_groups SET sync_id = ?, color = ?, updated_at = ?, deleted_at = ?, created_at = COALESCE(?, created_at) WHERE id = ?`,
      [
        incomingSyncId,
        (row as { color?: unknown }).color ?? null,
        (row as { updated_at: unknown }).updated_at,
        (row as { deleted_at?: unknown }).deleted_at ?? null,
        (row as { created_at?: unknown }).created_at ?? null,
        winner.id
      ]
    );
  }

  return 'handled';
}

async function isLocalDefaultProfileCompletelyEmpty(database: Awaited<ReturnType<typeof getDatabase>>, localProfileId: number): Promise<boolean> {
  const q = (sql: string) => database.select<Array<{ c: number }>>(sql, [localProfileId]);
  const a = (await q('SELECT COUNT(*) as c FROM study_sessions WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]?.c ?? 0;
  const b = (await q('SELECT COUNT(*) as c FROM subjects WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]?.c ?? 0;
  const c = (await q('SELECT COUNT(*) as c FROM goals WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]?.c ?? 0;
  const d = (await q('SELECT COUNT(*) as c FROM mood_logs WHERE profile_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')'))[0]?.c ?? 0;
  return a + b + c + d === 0;
}

/** Max `updated_at` (epoch ms) among active synced child rows for a profile. */
async function getMaxChildUpdatedMsForProfile(
  database: Awaited<ReturnType<typeof getDatabase>>,
  profileId: number
): Promise<number | null> {
  const tablesWithoutDeletedAt = new Set(['ai_challenges']);
  const tables = [
    'study_sessions',
    'subjects',
    'subject_groups',
    'goals',
    'mood_logs',
    'session_tasks',
    'ai_challenges'
  ];
  let max: number | null = null;
  for (const t of tables) {
    const whereDeleted = tablesWithoutDeletedAt.has(t)
      ? 'profile_id = ?'
      : `profile_id = ? AND (deleted_at IS NULL OR deleted_at = '')`;
    const rows = await database.select<Array<{ m: string | number | null }>>(
      `SELECT MAX(updated_at) as m FROM ${t} WHERE ${whereDeleted}`,
      [profileId]
    );
    const ms = toSyncEpochMs(rows[0]?.m ?? null);
    if (ms != null && (max === null || ms > max)) max = ms;
  }
  return max;
}

/**
 * True if this device has meaningful local edits under the profile after the
 * last successful Wi‑Fi sync with the peer who is sending the tombstone
 * (offline add / edit while disconnected). If we never synced with that peer
 * over Wi‑Fi, compare child max vs remote tombstone `updated_at` instead.
 */
async function profileHasOfflineAddsSincePeerBaseline(
  database: Awaited<ReturnType<typeof getDatabase>>,
  localProfileId: number,
  peerDeviceId: string,
  remoteTombstoneUpdatedAt: unknown
): Promise<boolean> {
  const maxChildMs = await getMaxChildUpdatedMsForProfile(database, localProfileId);
  if (maxChildMs === null) return false;

  const lastWifi = await getSyncState(peerDeviceId, 'wifi');
  if (lastWifi) {
    const baselineMs = toSyncEpochMs(lastWifi);
    if (baselineMs !== null) {
      return maxChildMs > baselineMs;
    }
  }
  const tombMs = toSyncEpochMs(remoteTombstoneUpdatedAt);
  if (tombMs !== null) {
    // Equal timestamps: prefer keeping local alive data vs replayed tombstone / ms rounding ties.
    return maxChildMs >= tombMs;
  }
  return false;
}

// ─── Build payload ────────────────────────────────────────────────────────────

export async function buildPayload(
  profileSyncId: string | null,
  sinceTimestamp = '1970-01-01T00:00:00.000Z'
): Promise<SyncPayload> {
  const database = await getDatabase();
  const deviceId = await getDeviceId();
  const deviceName = await getDeviceName();
  const now = new Date().toISOString();

  let bufferedSince = sinceTimestamp;
  if (sinceTimestamp !== '1970-01-01T00:00:00.000Z') {
    const d = new Date(sinceTimestamp);
    d.setSeconds(d.getSeconds() - 1);
    bufferedSince = d.toISOString();
  }

  const tables: Partial<Record<SyncTableName, Record<string, unknown>[]>> = {};
  const isFullSync = sinceTimestamp === '1970-01-01T00:00:00.000Z';

  console.log(`SYNC: [Engine] Building payload since ${sinceTimestamp} (buffered: ${bufferedSince}) for device ${deviceId} (${deviceName})`);

  for (const table of SYNC_TABLES) {
    const base = buildTableSelectSql(table);
    let sql = base;
    const params: (string | null)[] = [];
    if (!isFullSync) {
      if (table === 'profiles') {
        sql += ` AND ${syncTimeExpr('updated_at')} > ${syncSinceExpr()}`;
      } else {
        sql += ` AND ${syncTimeExpr('t.updated_at')} > ${syncSinceExpr()}`;
      }
      params.push(bufferedSince);
    }

    try {
      const rows = await database.select<Record<string, unknown>[]>(sql, params);
      if (rows.length > 0) {
        tables[table] = rows;
      }
    } catch (err) {
      console.warn(`[SyncEngine] buildPayload: error reading ${table}:`, err);
    }
  }

  return {
    payload_version: 1,
    device_id: deviceId,
    device_name: deviceName,
    profile_sync_id: profileSyncId,
    exported_at: now,
    since_timestamp: sinceTimestamp,
    tables
  };
}

// ─── Apply payload ───────────────────────────────────────────────────────────

export async function applyPayload(
  payload: SyncPayload,
  options: ApplyPayloadOptions = {}
): Promise<SyncResult> {
  return withWriteLock(() => _applyPayloadLocked(payload, options));
}

async function _applyPayloadLocked(
  payload: SyncPayload,
  options: ApplyPayloadOptions
): Promise<SyncResult> {
  _isSyncing = true;
  const mergeMode = options.mergeMode ?? 'merge';
  const result: SyncResult = { inserted: 0, updated: 0, skipped: 0, deferred: 0, errors: [] };

  try {
    const myDeviceId = await getDeviceId();
    console.log(`SYNC: [Engine] Applying payload from ${payload.device_name} (since: ${payload.since_timestamp}, merge: ${mergeMode})`);

    if (!payload?.tables) {
      return result;
    }

    const database = await getDatabase();
    const activeProfileIdRow = await getSettingByKey('currentProfileId');
    const activeId = activeProfileIdRow?.value ? parseInt(activeProfileIdRow.value, 10) : 1;
    const legacyDefaultProfileSyncIds = new Set<string>();
    if (mergeMode === 'merge' && payload.device_id !== myDeviceId) {
      for (const profile of payload.tables.profiles ?? []) {
        const sourceId = Number((profile as { id?: unknown }).id);
        const syncId = String((profile as { sync_id?: unknown }).sync_id ?? '');
        if (sourceId === 1 && syncId && syncId !== 'profile-default') {
          legacyDefaultProfileSyncIds.add(syncId);
        }
      }
    }

    for (const table of SYNC_TABLES) {
      const rows = payload.tables[table];
      if (!rows || rows.length === 0) continue;
      const cfg = TABLE_CONFIG[table];
      if (!cfg) continue;

      for (const row of rows) {
        const idCol = cfg.idCol;
        const rowId = (row as Record<string, unknown>)[idCol];
        if (rowId === null || rowId === undefined || String(rowId).length === 0) {
          console.warn(`SYNC: [Engine] Skipped row: missing ${idCol} in ${table}`);
          result.skipped++;
          continue;
        }
        if ((row as any).updated_at === null || (row as any).updated_at === undefined) {
          console.warn(`SYNC: [Engine] Skipped row: missing updated_at in ${table}/${rowId}`);
          result.skipped++;
          continue;
        }

        try {
          const work = { ...row } as Record<string, unknown>;

          if (idCol === 'sync_id' && (work as { sync_id?: string }).sync_id === 'profile-default' && (work as { deleted_at?: string | null }).deleted_at) {
            console.log('SYNC: [Engine] Ignored remote delete of default profile (protected)');
            result.skipped++;
            continue;
          }

          if (table === 'profiles' && (work as { sync_id?: string }).sync_id === 'profile-default' && mergeMode === 'separate' && payload.device_id !== myDeviceId) {
            (work as { sync_id: string }).sync_id = `profile-default-${payload.device_id}`;
            (work as { name: string }).name = `${payload.device_name}'s Profile`;
          }

          if (table === 'profiles' && mergeMode === 'merge') {
            const syncId = String((work as { sync_id?: unknown }).sync_id ?? '');
            if (legacyDefaultProfileSyncIds.has(syncId)) {
              (work as { sync_id: string }).sync_id = 'profile-default';
            }
          }

          // Offline add wins: peer deleted this profile while we had local child
          // edits after our last Wi‑Fi sync with them (or after tombstone time if
          // we never synced). Suppress the remote tombstone so data is not lost.
          const pSyncIncoming = String((work as { sync_id?: unknown }).sync_id ?? '');
          if (
            table === 'profiles' &&
            (work as { deleted_at?: string | null }).deleted_at &&
            pSyncIncoming !== 'profile-default' &&
            payload.device_id !== myDeviceId
          ) {
            const localProf = await database.select<Array<{ id: number }>>(
              'SELECT id FROM profiles WHERE sync_id = ? LIMIT 1',
              [pSyncIncoming]
            );
            if (localProf[0]) {
              const peerForBaseline = options.peerDeviceId ?? payload.device_id;
              if (peerForBaseline) {
                const offline = await profileHasOfflineAddsSincePeerBaseline(
                  database,
                  localProf[0].id,
                  peerForBaseline,
                  (work as { updated_at: unknown }).updated_at
                );
                if (offline) {
                  console.log(
                    `SYNC: [Engine] Offline activity after last Wi‑Fi sync — resurrecting profile ${pSyncIncoming}; remote delete from ${payload.device_name} suppressed.`
                  );
                  // Keep key present so upsert includes `deleted_at = NULL` (omit breaks ON CONFLICT UPDATE).
                  (work as { deleted_at: string | null }).deleted_at = null;
                  (work as { updated_at: unknown }).updated_at = new Date().toISOString();
                  toasts.info(
                    `Profile "${String((work as { name?: unknown }).name ?? '…')}" was deleted on ${payload.device_name}, but this device had newer local data. The profile was kept so your changes are not lost.`
                  );
                }
              }
            }
          }

          const syncIdStr = idCol === 'sync_id' ? String((work as { sync_id: string }).sync_id) : String((work as { id: string }).id);

          // BEHAVIOR-022: Old sync files may be missing profile_sync_id. Instead of rejecting,
          // extract a profile sync_id from the payload or use the active profile's sync_id as fallback.
          // This ensures backward compatibility with exports created before profile_sync_id was consistently included.
          if (table !== 'profiles' && (work as { profile_sync_id?: string | null }).profile_sync_id == null) {
            let fallbackProfileSyncId: string | null = null;
            
            // Try to find a profile in the incoming payload
            if (payload.tables.profiles && payload.tables.profiles.length > 0) {
              fallbackProfileSyncId = String((payload.tables.profiles[0] as { sync_id?: unknown }).sync_id ?? '');
            }
            
            // If no profile in payload, look up the active profile's sync_id
            if (!fallbackProfileSyncId) {
              const activeProfileRow = await database.select<Array<{ sync_id: string | null }>>(
                'SELECT sync_id FROM profiles WHERE id = ? LIMIT 1',
                [activeId]
              );
              fallbackProfileSyncId = activeProfileRow[0]?.sync_id ?? null;
            }
            
            if (fallbackProfileSyncId) {
              console.info(`SYNC: [Engine] Fallback: row missing profile_sync_id, using ${fallbackProfileSyncId}`);
              (work as { profile_sync_id: string }).profile_sync_id = fallbackProfileSyncId;
            } else {
              console.warn(`SYNC: [Engine] Skipped row: missing profile_sync_id and no fallback available in ${table}/${syncIdStr}`);
              result.skipped++;
              continue;
            }
          }

          const existing = await database.select<Array<{ updated_at: string | number | null }>>(
            `SELECT updated_at FROM ${table} WHERE ${cfg.conflictCol} = ? LIMIT 1`,
            [syncIdStr]
          );

          // Adoption (BEHAVIOR-011): only map an empty singleton local profile to the canonical
          // merged default (`profile-default`). Never repurpose `profile-default` for another UUID —
          // that merged the second desktop profile onto the phone's default row while sessions
          // still resolved to that integer id via profile_sync_id.
          if (
            table === 'profiles' &&
            !existing[0] &&
            (work as { sync_id?: string }).sync_id &&
            mergeMode === 'merge' &&
            (work as { sync_id: string }).sync_id !== `profile-default-${payload.device_id}` &&
            String((work as { sync_id: string }).sync_id) === 'profile-default'
          ) {
            const pSync = String((work as { sync_id: string }).sync_id);
            const localProfiles = await database.select<Array<{ id: number }>>(
              'SELECT id FROM profiles WHERE deleted_at IS NULL ORDER BY id ASC;'
            );
            if (localProfiles.length === 1) {
              const localId = localProfiles[0].id;
              const empty = await isLocalDefaultProfileCompletelyEmpty(database, localId);
              if (empty) {
                await database.execute('UPDATE profiles SET sync_id = ? WHERE id = ?;', [pSync, localId]);
                const adopted = await database.select<Array<{ updated_at: string | number | null }>>(
                  'SELECT updated_at FROM profiles WHERE sync_id = ? LIMIT 1',
                  [pSync]
                );
                if (adopted[0]) {
                  const localMs = toSyncEpochMs(adopted[0].updated_at);
                  const incomingMs = toSyncEpochMs((work as { updated_at: unknown }).updated_at);
                  if (localMs !== null && incomingMs !== null) {
                    if (incomingMs <= localMs) {
                      result.skipped++;
                      continue;
                    }
                  }
                }
              }
            }
          }

          if (existing[0]) {
            const localMs = toSyncEpochMs(existing[0].updated_at);
            const incomingMs = toSyncEpochMs((work as { updated_at: unknown }).updated_at);
            if (localMs !== null && incomingMs !== null) {
              if (incomingMs <= localMs) {
                result.skipped++;
                continue;
              }
            }
          }

          const rowToUpsert: Record<string, unknown> = { ...work };
          delete (rowToUpsert as { id?: number }).id;

          if (table !== 'profiles' && (rowToUpsert as { profile_sync_id?: string }).profile_sync_id) {
            const rawPs = String((rowToUpsert as { profile_sync_id: string }).profile_sync_id);
            const remapped = mapIncomingProfileSyncId(rawPs, mergeMode, payload, myDeviceId, legacyDefaultProfileSyncIds);
            const profileRow = await database.select<{ id: number }[]>(
              'SELECT id FROM profiles WHERE sync_id = ? LIMIT 1',
              [remapped]
            );
            if (!profileRow[0]) {
              console.warn(`SYNC: [Engine] Skipped row: unknown profile_sync_id ${remapped} (${table})`);
              result.skipped++;
              continue;
            }
            (rowToUpsert as { profile_id: number }).profile_id = profileRow[0].id;
            delete (rowToUpsert as { profile_sync_id?: string }).profile_sync_id;
          } else if (table !== 'profiles') {
            (rowToUpsert as { profile_id: number }).profile_id = activeId;
            delete (rowToUpsert as { profile_sync_id?: string }).profile_sync_id;
          }

          if (table === 'study_sessions' && (rowToUpsert as { subject_sync_id?: string | null }).subject_sync_id) {
            const sSid = (rowToUpsert as { subject_sync_id: string }).subject_sync_id;
            const sub = await database.select<{ id: number }[]>(
              'SELECT id FROM subjects WHERE sync_id = ? LIMIT 1',
              [sSid]
            );
            if (sub[0]) {
              (rowToUpsert as { subject_id: number | null }).subject_id = sub[0].id;
            } else {
              (rowToUpsert as { subject_id: number | null }).subject_id = null;
            }
            delete (rowToUpsert as { subject_sync_id?: string }).subject_sync_id;
          } else {
            delete (rowToUpsert as { subject_sync_id?: string }).subject_sync_id;
          }

          if (table === 'subjects') {
            const groupSyncId = (rowToUpsert as { group_sync_id?: string | null }).group_sync_id;
            if (groupSyncId) {
              const group = await database.select<{ id: number }[]>(
                'SELECT id FROM subject_groups WHERE sync_id = ? LIMIT 1',
                [groupSyncId]
              );
              (rowToUpsert as { group_id: number | null }).group_id = group[0]?.id ?? null;
            } else {
              (rowToUpsert as { group_id: number | null }).group_id = null;
            }
            delete (rowToUpsert as { group_sync_id?: string | null }).group_sync_id;
          } else {
            delete (rowToUpsert as { group_sync_id?: string | null }).group_sync_id;
          }

          if (['session_tasks', 'mood_logs'].includes(table) && (rowToUpsert as { session_sync_id?: string | null }).session_sync_id) {
            const sYnc = (rowToUpsert as { session_sync_id: string }).session_sync_id;
            const sess = await database.select<{ id: number }[]>(
              'SELECT id FROM study_sessions WHERE sync_id = ? LIMIT 1',
              [sYnc]
            );
            if (sess[0]) {
              (rowToUpsert as { session_id: number | null }).session_id = sess[0].id;
            } else {
              console.warn(
                `SYNC: [Engine] Deferred row: session_sync_id ${sYnc} not yet received (${table}/${syncIdStr})`
              );
              result.deferred++;
              continue;
            }
            delete (rowToUpsert as { session_sync_id?: string }).session_sync_id;
          } else {
            delete (rowToUpsert as { session_sync_id?: string }).session_sync_id;
          }

          if (table === 'subjects' || table === 'subject_groups') {
            const dup = await mergePerProfileNameDuplicateOnApply(database, table, rowToUpsert);
            if (dup === 'skip') {
              result.skipped++;
              continue;
            }
            if (dup === 'handled') {
              result.updated++;
              continue;
            }
          }

          if (table === 'profiles' && existing[0]) {
            delete (rowToUpsert as { owner_device_id?: string }).owner_device_id;
          }

          if (idCol === 'id') {
            (rowToUpsert as { id: string }).id = String((work as { id: string }).id);
          }

          const cols = cfg.upsertCols.filter((col) => col in rowToUpsert || col === cfg.conflictCol);
          const values: (string | number | null)[] = cols.map((col) => {
            const v = rowToUpsert[col];
            if (v === undefined || v === null) return null;
            if (typeof v === 'boolean') return v ? 1 : 0;
            if (typeof v === 'number') return v;
            return String(v);
          });

          await execWithBusyRetry(
            () => database.execute(cfg.upsertSql(cols), values),
            { label: `upsert ${table}` }
          );
          result.updated++;

          if (table === 'profiles' && (rowToUpsert as { deleted_at?: string | null }).deleted_at) {
            const psid = String((rowToUpsert as { sync_id: string }).sync_id);
            if (psid === 'profile-default') {
              // protected above
            } else {
              const pr = await database.select<{ id: number }[]>(
                'SELECT id FROM profiles WHERE sync_id = ? LIMIT 1',
                [psid]
              );
              if (pr[0]) {
                await hardDeleteAllDataForProfileIdUnlocked(pr[0].id);
              }
            }
          }
        } catch (err: unknown) {
          const e = err as { message?: string };
          const rid = (row as Record<string, unknown>)[idCol];
          console.error(`SYNC: [Engine] Error upserting ${table}/${rid}:`, err);
          result.errors.push(`${table}/${rid}: ${String(e?.message ?? err)}`);
        }
      }
    }

    // ── Stranded profile recovery (BEHAVIOR-018) + toast
    try {
      const activeProfileIdRow2 = await getSettingByKey('currentProfileId');
      const activeProfileId = activeProfileIdRow2?.value ? parseInt(activeProfileIdRow2.value, 10) : 1;
      const activeProfile = await database.select<Array<{ id: number; deleted_at: string | null }>>(
        'SELECT id, deleted_at FROM profiles WHERE id = ? LIMIT 1',
        [activeProfileId]
      );
      if (!activeProfile[0] || activeProfile[0].deleted_at !== null) {
        const fallback = await database.select<Array<{ id: number; name: string }>>(
          'SELECT id, name FROM profiles WHERE deleted_at IS NULL ORDER BY id ASC LIMIT 1'
        );
        if (fallback[0]) {
          await setSettingByKey('currentProfileId', String(fallback[0].id));
          toasts.info(
            `The active profile was deleted from another device. Switched to ${fallback[0].name}.`
          );
          await profileStore.init();
        }
      }
    } catch (err) {
      console.error(`SYNC: [Engine] Stranded profile recovery error:`, err);
    }

    return result;
  } finally {
    _isSyncing = false;
  }
}

// ─── Sync state tracking ──────────────────────────────────────────────────────

export async function getSyncState(
  peerDeviceId: string,
  transport: string
): Promise<string | null> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ last_synced_at: string | null }>>(
    'SELECT last_synced_at FROM sync_state WHERE peer_device_id = ? AND transport = ? LIMIT 1;',
    [peerDeviceId, transport]
  );
  return rows[0]?.last_synced_at ?? null;
}

export async function updateSyncState(
  peerDeviceId: string,
  transport: string,
  direction: string,
  rowCount: number,
  clear: boolean = false
): Promise<void> {
  syncTrigger.suppress();
  try {
    const database = await getDatabase();

    if (clear) {
      await database.execute('DELETE FROM sync_state WHERE peer_device_id = ? AND transport = ?;', [peerDeviceId, transport]);
      return;
    }

    const now = new Date().toISOString();
    await database.execute(
      `INSERT INTO sync_state (peer_device_id, transport, last_synced_at, last_sync_direction, last_row_count)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(peer_device_id, transport) DO UPDATE SET
         last_synced_at = excluded.last_synced_at,
         last_sync_direction = excluded.last_sync_direction,
         last_row_count = excluded.last_row_count;`,
      [peerDeviceId, transport, now, direction, rowCount]
    );
  } finally {
    syncTrigger.unsuppress();
  }
}

export async function recordSyncHistory(entry: SyncHistoryEntry): Promise<void> {
  if (entry.success && entry.rowsSent === 0 && entry.rowsReceived === 0) {
    return;
  }

  syncTrigger.suppress();
  try {
    const database = await getDatabase();
    await database.execute(
      `INSERT INTO sync_history (peer_device_id, peer_device_name, transport, direction,
         rows_sent, rows_received, success, error_message, synced_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP);`,
      [
        entry.peerDeviceId,
        entry.peerDeviceName,
        entry.transport,
        entry.direction,
        entry.rowsSent,
        entry.rowsReceived,
        entry.success ? 1 : 0,
        entry.errorMessage ?? null
      ]
    );
  } finally {
    syncTrigger.unsuppress();
  }
}

export async function getSyncHistory(limit = 20): Promise<
  Array<{
    id: number;
    peerDeviceId: string | null;
    peerDeviceName: string | null;
    transport: string;
    direction: 'push' | 'pull' | 'bidirectional';
    rowsSent: number;
    rowsReceived: number;
    success: boolean;
    errorMessage: string | null;
    syncedAt: string;
  }>
> {
  const database = await getDatabase();
  const rows = await database.select<
    Array<{
      id: number;
      peer_device_id: string | null;
      peer_device_name: string | null;
      transport: string;
      direction: string;
      rows_sent: number;
      rows_received: number;
      success: number;
      error_message: string | null;
      synced_at: string;
    }>
  >('SELECT * FROM sync_history ORDER BY synced_at DESC LIMIT ?;', [limit]);

  return rows.map((r) => ({
    id: r.id,
    peerDeviceId: r.peer_device_id,
    peerDeviceName: r.peer_device_name,
    transport: r.transport,
    direction: r.direction as 'push' | 'pull' | 'bidirectional',
    rowsSent: r.rows_sent,
    rowsReceived: r.rows_received,
    success: r.success === 1,
    errorMessage: r.error_message,
    syncedAt: r.synced_at
  }));
}

export async function getUnsyncedCount(): Promise<number> {
  const database = await getDatabase();
  try {
    const stateRows = await database.select<Array<{ last_synced_at: string }>>(
      'SELECT last_synced_at FROM sync_state ORDER BY last_synced_at DESC LIMIT 1;'
    );
    const lastSyncedAt = stateRows[0]?.last_synced_at ?? '1970-01-01T00:00:00.000Z';

    const profileIdRow = await getSettingByKey('currentProfileId');
    const profileId = profileIdRow?.value ? parseInt(profileIdRow.value, 10) : 1;

    let totalUnsynced = 0;
    for (const table of SYNC_TABLES) {
      if (table === 'ai_challenges') {
        const countRows = await database.select<Array<{ count: number }>>(
          'SELECT COUNT(*) as count FROM ai_challenges WHERE id IS NOT NULL AND updated_at > ? AND profile_id = ?',
          [lastSyncedAt, profileId]
        );
        totalUnsynced += countRows[0]?.count ?? 0;
        continue;
      }
      if (table === 'profiles') {
        const countRows = await database.select<Array<{ count: number }>>(
          'SELECT COUNT(*) as count FROM profiles WHERE sync_id IS NOT NULL AND updated_at > ?',
          [lastSyncedAt]
        );
        totalUnsynced += countRows[0]?.count ?? 0;
        continue;
      }
      const countRows = await database.select<Array<{ count: number }>>(
        `SELECT COUNT(*) as count FROM ${table} WHERE sync_id IS NOT NULL AND updated_at > ? AND profile_id = ?`,
        [lastSyncedAt, profileId]
      );
      totalUnsynced += countRows[0]?.count ?? 0;
    }
    return totalUnsynced;
  } catch (err) {
    console.error('SYNC: [Engine] Failed to get unsynced count:', err);
    return 0;
  }
}

// ─── Payload serialization (for file / cloud transport) ─────────────────────

export function serializePayload(payload: SyncPayload): string {
  return JSON.stringify(payload);
}

export function deserializePayload(json: string): SyncPayload {
  const data = JSON.parse(json) as Record<string, unknown>;
  const version = (data?.payload_version ?? data?.version) as number | undefined;
  if (version !== 1) {
    throw new Error('Unsupported payload version: ' + version);
  }
  if (data.deviceId && !data.device_id) data.device_id = data.deviceId;
  if (data.deviceName && !data.device_name) data.device_name = data.deviceName;
  if (data.version && !data.payload_version) data.payload_version = 1;
  return data as unknown as SyncPayload;
}
