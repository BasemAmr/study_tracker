import { getDatabase } from '../database';
import type { SessionFilter, SessionSummary, StudySession } from '../../domain';
import { normalizeNullableText, normalizeText } from '../sql';
import { getCurrentProfileId } from './profileRepository';
import { syncTrigger } from '../../sync/syncTrigger';

type SessionRow = {
  id: number;
  start_at: string;
  end_at: string;
  duration_minutes: number;
  subject_id: number | null;
  subject_name: string | null;
  topic: string | null;
  chapter_tag: string | null;
  mood: string | null;
  notes: string | null;
  mode: StudySession['mode'];
  break_minutes: number;
  created_at: string;
  updated_at: string;
};

function validateSession(session: StudySession): StudySession {
  const startAt = normalizeText(session.startAt ?? '');
  const endAt = normalizeText(session.endAt ?? '');

  if (!startAt || !endAt) {
    throw new Error('Session start and end times are required.');
  }

  if (session.durationMinutes <= 0) {
    throw new Error('Session duration must be positive.');
  }

  if (!session.mode) {
    throw new Error('Session mode is required.');
  }

  return {
    ...session,
    startAt,
    endAt,
    subjectName: normalizeNullableText(session.subjectName),
    topic: normalizeNullableText(session.topic),
    chapterTag: normalizeNullableText(session.chapterTag),
    mood: normalizeNullableText(session.mood),
    notes: normalizeNullableText(session.notes)
  };
}

export async function createSession(session: StudySession): Promise<number> {
  const normalized = validateSession(session);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();

  const result = await database.execute(
    `INSERT INTO study_sessions (
      profile_id,
      start_at, end_at, duration_minutes, subject_id, subject_name, topic, chapter_tag,
      mood, notes, mode, break_minutes, sync_id, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, lower(hex(randomblob(16))), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);`,
    [
      profileId,
      normalized.startAt,
      normalized.endAt,
      normalized.durationMinutes,
      normalized.subjectId ?? null,
      normalized.subjectName ?? null,
      normalized.topic ?? null,
      normalized.chapterTag ?? null,
      normalized.mood ?? null,
      normalized.notes ?? null,
      normalized.mode,
      normalized.breakMinutes ?? 0
    ]
  );

  syncTrigger.notifyChange();
  return Number(result.lastInsertId);
}

export async function updateSession(session: StudySession): Promise<void> {
  if (!session.id) {
    throw new Error('Session id is required for updates.');
  }

  const normalized = validateSession(session);
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();

  await database.execute(
    `UPDATE study_sessions SET
      start_at = ?, end_at = ?, duration_minutes = ?, subject_id = ?, subject_name = ?, topic = ?,
      chapter_tag = ?, mood = ?, notes = ?, mode = ?, break_minutes = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ? AND profile_id = ?;`,
    [
      normalized.startAt,
      normalized.endAt,
      normalized.durationMinutes,
      normalized.subjectId ?? null,
      normalized.subjectName ?? null,
      normalized.topic ?? null,
      normalized.chapterTag ?? null,
      normalized.mood ?? null,
      normalized.notes ?? null,
      normalized.mode,
      normalized.breakMinutes ?? 0,
      normalized.id as number,
      profileId
    ]
  );
  syncTrigger.notifyChange();
}

export async function deleteSession(id: number): Promise<void> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  await database.execute('UPDATE study_sessions SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND profile_id = ?;', [id, profileId]);
  syncTrigger.notifyChange();
}

export async function getSessionById(id: number): Promise<StudySession | null> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const rows = await database.select<SessionRow[]>('SELECT * FROM study_sessions WHERE deleted_at IS NULL AND id = ? AND profile_id = ? LIMIT 1;', [id, profileId]);
  return rows[0] ? mapSession(rows[0]) : null;
}

/** Profile-scoped list (notifications + cross-profile reads use this). */
export async function listSessionsForProfile(profileId: number, filter: SessionFilter = {}): Promise<StudySession[]> {
  const database = await getDatabase();
  const where: string[] = ['deleted_at IS NULL'];
  const params: Array<string | number> = [];

  const limit = filter.limit ?? 50;
  const offset = filter.offset ?? 0;

  where.push('profile_id = ?');
  params.push(profileId);

  if (filter.subjectId !== undefined) {
    where.push('subject_id = ?');
    params.push(filter.subjectId);
  }

  if (filter.mode) {
    where.push('mode = ?');
    params.push(filter.mode);
  }

  if (filter.startFrom) {
    where.push('start_at >= ?');
    params.push(filter.startFrom);
  }

  if (filter.startTo) {
    where.push('start_at <= ?');
    params.push(filter.startTo);
  }

  if (filter.query) {
    where.push('(subject_name LIKE ? OR topic LIKE ? OR notes LIKE ?)');
    const query = `%${normalizeText(filter.query)}%`;
    params.push(query, query, query);
  }

  const sql = `SELECT * FROM study_sessions ${where.length ? `WHERE ${where.join(' AND ')}` : ''} ORDER BY start_at DESC LIMIT ? OFFSET ?;`;
  params.push(limit, offset);

  const rows = await database.select<SessionRow[]>(sql, params);
  return rows.map(mapSession);
}

export async function listSessions(filter: SessionFilter = {}): Promise<StudySession[]> {
  const profileId = await getCurrentProfileId();
  return listSessionsForProfile(profileId, filter);
}

export async function getRecentSessions(limit = 5): Promise<StudySession[]> {
  return listSessions({ limit });
}

export async function getSessionSummary(): Promise<SessionSummary> {
  const database = await getDatabase();
  const profileId = await getCurrentProfileId();
  const totals = await database.select<Array<{ total_sessions: number; total_minutes: number; average_minutes: number }>>(
    'SELECT COUNT(*) AS total_sessions, COALESCE(SUM(duration_minutes), 0) AS total_minutes, COALESCE(AVG(duration_minutes), 0) AS average_minutes FROM study_sessions WHERE deleted_at IS NULL AND profile_id = ?;',
    [profileId]
  );
  const recentSessions = await getRecentSessions(5);

  return {
    totalSessions: totals[0]?.total_sessions ?? 0,
    totalMinutes: totals[0]?.total_minutes ?? 0,
    averageMinutes: totals[0]?.average_minutes ?? 0,
    recentSessions
  };
}

/** Used by notifications: any non-deleted session starting on the same local calendar day as `when`. */
export async function hasSessionOnLocalCalendarDay(profileId: number, when: Date): Promise<boolean> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ c: number }>>(
    `SELECT COUNT(*) AS c FROM study_sessions
     WHERE profile_id = ?
       AND deleted_at IS NULL
       AND date(start_at, 'localtime') = date(?, 'localtime')`,
    [profileId, when.toISOString()]
  );
  return (rows[0]?.c ?? 0) > 0;
}

export async function getLastSessionStartAtIso(profileId: number): Promise<string | null> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ start_at: string }>>(
    `SELECT start_at FROM study_sessions
     WHERE profile_id = ? AND deleted_at IS NULL
     ORDER BY start_at DESC LIMIT 1`,
    [profileId]
  );
  return rows[0]?.start_at ?? null;
}

export async function sumDurationMinutesBetween(
  profileId: number,
  startIsoInclusive: string,
  endIsoInclusive: string
): Promise<number> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ m: number }>>(
    `SELECT COALESCE(SUM(duration_minutes), 0) AS m FROM study_sessions
     WHERE profile_id = ?
       AND deleted_at IS NULL
       AND datetime(start_at) >= datetime(?)
       AND datetime(start_at) <= datetime(?)`,
    [profileId, startIsoInclusive, endIsoInclusive]
  );
  return rows[0]?.m ?? 0;
}

export async function sessionCountBetween(
  profileId: number,
  startIsoInclusive: string,
  endIsoInclusive: string
): Promise<number> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ c: number }>>(
    `SELECT COUNT(*) AS c FROM study_sessions
     WHERE profile_id = ?
       AND deleted_at IS NULL
       AND datetime(start_at) >= datetime(?)
       AND datetime(start_at) <= datetime(?)`,
    [profileId, startIsoInclusive, endIsoInclusive]
  );
  return rows[0]?.c ?? 0;
}

/** Most-studied display name last `daysBack` sliding window (excluding empty names → "study"). */
export async function getDominantSubjectLastDays(profileId: number, daysBack: number): Promise<{ name: string; count: number } | null> {
  const db = await getDatabase();
  const now = new Date();
  const since = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  since.setDate(since.getDate() - daysBack);
  const rows = await db.select<Array<{ sn: string; c: number }>>(
    `SELECT COALESCE(NULLIF(trim(subject_name), ''), 'General') AS sn, COUNT(*) AS c
     FROM study_sessions
     WHERE profile_id = ?
       AND deleted_at IS NULL
       AND datetime(start_at) >= datetime(?)
     GROUP BY sn
     ORDER BY c DESC
     LIMIT 1`,
    [profileId, since.toISOString()]
  );
  const r = rows[0];
  if (!r || !r.sn) return null;
  return { name: r.sn, count: r.c };
}

/** Sorted local calendar dates 'YYYY-MM-DD' with ≥1 minute logged (notifications / streak aggregation). */
export async function distinctStudyLocalDayKeysAscending(profileId: number): Promise<string[]> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ d: string }>>(
    `SELECT DISTINCT date(start_at, 'localtime') AS d
     FROM study_sessions
     WHERE profile_id = ? AND deleted_at IS NULL AND duration_minutes > 0
     ORDER BY d ASC`,
    [profileId]
  );
  return rows.map((x) => x.d);
}

/** Highest subject by minutes in `[start,end]` range. */
export async function topSubjectMinutesInRange(
  profileId: number,
  startIsoInclusive: string,
  endIsoInclusive: string
): Promise<{ name: string; minutes: number } | null> {
  const database = await getDatabase();
  const rows = await database.select<Array<{ sn: string; m: number }>>(
    `SELECT COALESCE(NULLIF(trim(subject_name), ''), 'Sessions') AS sn,
            SUM(duration_minutes) AS m
     FROM study_sessions
     WHERE profile_id = ?
       AND deleted_at IS NULL
       AND datetime(start_at) >= datetime(?)
       AND datetime(start_at) <= datetime(?)
     GROUP BY sn
     ORDER BY m DESC
     LIMIT 1`,
    [profileId, startIsoInclusive, endIsoInclusive]
  );
  const r = rows[0];
  if (!r) return null;
  return { name: r.sn, minutes: r.m };
}

function mapSession(row: any): StudySession {
  const sessionRow = row as SessionRow;
  return {
    id: sessionRow.id,
    startAt: sessionRow.start_at,
    endAt: sessionRow.end_at,
    durationMinutes: sessionRow.duration_minutes,
    subjectId: sessionRow.subject_id,
    subjectName: sessionRow.subject_name,
    topic: sessionRow.topic,
    chapterTag: sessionRow.chapter_tag,
    mood: sessionRow.mood,
    notes: sessionRow.notes,
    mode: sessionRow.mode,
    breakMinutes: sessionRow.break_minutes,
    createdAt: sessionRow.created_at,
    updatedAt: sessionRow.updated_at
  };
}
