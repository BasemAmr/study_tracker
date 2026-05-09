import { getDatabase } from '../database';

export type NotificationLogOutcome = 'fired' | 'suppressed';

export type NotificationLogRow = {
  id: number;
  profileId: number;
  notificationId: number;
  outcome: NotificationLogOutcome;
  reason: string;
  createdAt: string;
};

type DbRow = {
  id: number;
  profile_id: number;
  notification_id: number;
  outcome: string;
  reason: string;
  created_at: string;
};

function map(r: DbRow): NotificationLogRow {
  return {
    id: r.id,
    profileId: r.profile_id,
    notificationId: r.notification_id,
    outcome: r.outcome as NotificationLogOutcome,
    reason: r.reason,
    createdAt: r.created_at
  };
}

export async function append(
  profileId: number,
  notificationId: number,
  outcome: NotificationLogOutcome,
  reason: string
): Promise<void> {
  const database = await getDatabase();
  await database.execute(
    `INSERT INTO notification_log (profile_id, notification_id, outcome, reason, created_at)
     VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)`,
    [profileId, notificationId, outcome, reason]
  );
}

export async function lastFireOfType(
  profileId: number,
  notificationId: number
): Promise<NotificationLogRow | null> {
  const database = await getDatabase();
  const rows = await database.select<DbRow[]>(
    `SELECT * FROM notification_log
     WHERE profile_id = ? AND notification_id = ? AND outcome = 'fired'
     ORDER BY created_at DESC LIMIT 1`,
    [profileId, notificationId]
  );
  return rows[0] ? map(rows[0]) : null;
}

export async function firedSince(
  profileId: number,
  notificationId: number,
  sinceIso: string
): Promise<NotificationLogRow[]> {
  const database = await getDatabase();
  const rows = await database.select<DbRow[]>(
    `SELECT * FROM notification_log
     WHERE profile_id = ? AND notification_id = ? AND outcome = 'fired' AND created_at >= ?
     ORDER BY created_at ASC`,
    [profileId, notificationId, sinceIso]
  );
  return rows.map(map);
}

/** Count of `fired` rows since `since` (inclusive), for weekly/goal dedupe windows. */
export async function countFiresSince(
  profileId: number,
  notificationId: number,
  since: Date
): Promise<number> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ c: number }>>(
    `SELECT COUNT(*) AS c FROM notification_log
     WHERE profile_id = ? AND notification_id = ? AND outcome = 'fired' AND datetime(created_at) >= datetime(?)`,
    [profileId, notificationId, since.toISOString()]
  );
  return rows[0]?.c ?? 0;
}

/** Any `fired` for this id after `afterIso` (exclusive), for re-engagement silence windows. */
export async function hasFiredSinceIso(
  profileId: number,
  notificationId: number,
  afterIso: string
): Promise<boolean> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ c: number }>>(
    `SELECT COUNT(*) AS c FROM notification_log
     WHERE profile_id = ? AND notification_id = ? AND outcome = 'fired' AND datetime(created_at) > datetime(?)`,
    [profileId, notificationId, afterIso]
  );
  return (rows[0]?.c ?? 0) > 0;
}
