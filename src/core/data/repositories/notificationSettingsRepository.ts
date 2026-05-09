import { getDatabase } from '../database';

export type NotificationSettingsRow = {
  profileId: number;
  preStudyEnabled: boolean;
  streakEnabled: boolean;
  weeklyEnabled: boolean;
  goalEnabled: boolean;
  reengage3Enabled: boolean;
  reengage7Enabled: boolean;
  /** Legacy columns — kept in sync with the explicit timers below */
  slotATime: string;
  slotBTime: string;
  /** N-T-6 / BEHAVIOR-N3 — HH:mm local */
  preStudyTime: string;
  weeklySummaryTime: string;
  reengageTime: string;
  quietHoursStart: string;
  quietHoursEnd: string;
  reengageIntervalDays: number;
  /** Legacy hour-only mirror of `reengageTime` kept for SQLite round-trip compatibility */
  reengageHour: number;
  weeklySummaryDow: number;
  goalDow: number;
  goalTime: string;
  updatedAt: string;
};

type Row = {
  profile_id: number;
  pre_study_enabled: number;
  streak_enabled: number;
  weekly_enabled: number;
  goal_enabled: number;
  reengage_3_enabled: number;
  reengage_7_enabled: number;
  slot_a_time: string;
  slot_b_time: string;
  pre_study_time: string | null;
  weekly_summary_time: string | null;
  reengage_time: string | null;
  quiet_hours_start: string;
  quiet_hours_end: string;
  reengage_interval_days: number;
  reengage_hour: number;
  weekly_summary_dow?: number;
  goal_dow?: number;
  goal_time?: string;
  updated_at: string;
};

const DEFAULT_ROW: Omit<NotificationSettingsRow, 'profileId'> = {
  preStudyEnabled: false,
  streakEnabled: false,
  weeklyEnabled: false,
  goalEnabled: false,
  reengage3Enabled: false,
  reengage7Enabled: false,
  slotATime: '14:00',
  slotBTime: '19:00',
  preStudyTime: '14:00',
  weeklySummaryTime: '19:00',
  reengageTime: '14:00',
  quietHoursStart: '22:00',
  quietHoursEnd: '08:00',
  reengageIntervalDays: 3,
  reengageHour: 14,
  weeklySummaryDow: 7,
  goalDow: 3,
  goalTime: '19:00',
  updatedAt: ''
};

function hourFromHm(hm: string): number {
  const [h] = hm.split(':').map((x) => parseInt(x, 10));
  return Number.isFinite(h) ? Math.min(23, Math.max(0, h)) : 14;
}

function toBool(n: number): boolean {
  return n === 1;
}

function mapRow(r: Row): NotificationSettingsRow {
  const preStudyTime = r.pre_study_time || r.slot_a_time;
  const weeklySummaryTime = r.weekly_summary_time || r.slot_b_time;
  const reengageTime = r.reengage_time || `${String(r.reengage_hour).padStart(2, '0')}:00`;
  return {
    profileId: r.profile_id,
    preStudyEnabled: toBool(r.pre_study_enabled),
    streakEnabled: toBool(r.streak_enabled),
    weeklyEnabled: toBool(r.weekly_enabled),
    goalEnabled: toBool(r.goal_enabled),
    reengage3Enabled: toBool(r.reengage_3_enabled),
    reengage7Enabled: toBool(r.reengage_7_enabled),
    slotATime: r.slot_a_time,
    slotBTime: r.slot_b_time,
    preStudyTime,
    weeklySummaryTime,
    reengageTime,
    quietHoursStart: r.quiet_hours_start,
    quietHoursEnd: r.quiet_hours_end,
    reengageIntervalDays: r.reengage_interval_days,
    reengageHour: hourFromHm(reengageTime),
    weeklySummaryDow: r.weekly_summary_dow ?? 7,
    goalDow: r.goal_dow ?? 3,
    goalTime: r.goal_time ?? '19:00',
    updatedAt: r.updated_at
  };
}

/** Defaults match migration v11 seed (all toggles off, 14:00/19:00, quiet 22:00–08:00). */
export function getOrDefault(profileId: number, row: NotificationSettingsRow | null): NotificationSettingsRow {
  if (!row) {
    return { profileId, ...DEFAULT_ROW, updatedAt: new Date().toISOString() };
  }
  return row;
}

export async function getForProfile(profileId: number): Promise<NotificationSettingsRow | null> {
  const database = await getDatabase();
  const rows = await database.select<Row[]>(
    'SELECT * FROM notification_settings WHERE profile_id = ? LIMIT 1',
    [profileId]
  );
  return rows[0] ? mapRow(rows[0]) : null;
}

export async function upsert(row: NotificationSettingsRow): Promise<void> {
  const database = await getDatabase();
  const b = (x: boolean) => (x ? 1 : 0);
  const reengageHourParsed = hourFromHm(row.reengageTime);
  const slotATimeSynced = row.preStudyTime;
  const slotBTimeSynced = row.weeklySummaryTime;
  await database.execute(
    `INSERT INTO notification_settings (
      profile_id, pre_study_enabled, streak_enabled, weekly_enabled, goal_enabled,
      reengage_3_enabled, reengage_7_enabled, slot_a_time, slot_b_time,
      pre_study_time, weekly_summary_time, reengage_time,
      quiet_hours_start, quiet_hours_end, reengage_interval_days, reengage_hour,
      weekly_summary_dow, goal_dow, goal_time, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(profile_id) DO UPDATE SET
      pre_study_enabled = excluded.pre_study_enabled,
      streak_enabled = excluded.streak_enabled,
      weekly_enabled = excluded.weekly_enabled,
      goal_enabled = excluded.goal_enabled,
      reengage_3_enabled = excluded.reengage_3_enabled,
      reengage_7_enabled = excluded.reengage_7_enabled,
      slot_a_time = excluded.slot_a_time,
      slot_b_time = excluded.slot_b_time,
      pre_study_time = excluded.pre_study_time,
      weekly_summary_time = excluded.weekly_summary_time,
      reengage_time = excluded.reengage_time,
      quiet_hours_start = excluded.quiet_hours_start,
      quiet_hours_end = excluded.quiet_hours_end,
      reengage_interval_days = excluded.reengage_interval_days,
      reengage_hour = excluded.reengage_hour,
      weekly_summary_dow = excluded.weekly_summary_dow,
      goal_dow = excluded.goal_dow,
      goal_time = excluded.goal_time,
      updated_at = CURRENT_TIMESTAMP`,
    [
      row.profileId,
      b(row.preStudyEnabled),
      b(row.streakEnabled),
      b(row.weeklyEnabled),
      b(row.goalEnabled),
      b(row.reengage3Enabled),
      b(row.reengage7Enabled),
      slotATimeSynced,
      slotBTimeSynced,
      row.preStudyTime,
      row.weeklySummaryTime,
      row.reengageTime,
      row.quietHoursStart,
      row.quietHoursEnd,
      row.reengageIntervalDays,
      reengageHourParsed,
      row.weeklySummaryDow,
      row.goalDow,
      row.goalTime
    ]
  );
}
