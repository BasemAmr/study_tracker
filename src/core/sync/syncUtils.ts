/**
 * Sync utilities — shared helpers used by multiple transports
 */

import { getDatabase } from '../data/database';
import { getSettingByKey } from '../data/repositories/appSettingsRepository';

/** Get the sync_id of the currently active profile, or null if not found */
export async function getCurrentProfileSyncId(): Promise<string | null> {
  const database = await getDatabase();
  const row = await getSettingByKey('currentProfileId');
  const profileId = Number(row?.value ?? 1);
  const rows = await database.select<Array<{ sync_id: string | null }>>(
    'SELECT sync_id FROM profiles WHERE id = ? LIMIT 1;',
    [profileId]
  );
  return rows[0]?.sync_id ?? null;
}

/** Get the local device ID */
export async function getLocalDeviceId(): Promise<string> {
  const row = await getSettingByKey('syncDeviceId');
  return row?.value ?? 'unknown';
}

/** Clamp a date string to an ISO timestamp; return epoch if invalid */
export function clampTimestamp(ts: string | null | undefined): string {
  if (!ts) return '1970-01-01T00:00:00.000Z';
  
  // Handle SQLite space format: replace space with T
  const normalized = ts.includes(' ') && !ts.includes('T') ? ts.replace(' ', 'T') : ts;
  
  try {
    const date = new Date(normalized);
    if (isNaN(date.getTime())) return '1970-01-01T00:00:00.000Z';
    return date.toISOString();
  } catch {
    return '1970-01-01T00:00:00.000Z';
  }
}

/** Generate a 6-digit pairing code */
export function generatePairingCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/** Format a row count for display */
export function formatRowCount(n: number): string {
  if (n === 0) return 'no changes';
  if (n === 1) return '1 row';
  return `${n} rows`;
}

/** Format a timestamp for display */
export function formatSyncTime(isoString: string | null | undefined): string {
  if (!isoString) return 'Never';
  try {
    const d = new Date(isoString);
    const now = new Date();
    const diffMs = now.getTime() - d.getTime();
    const diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return 'Just now';
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffH = Math.floor(diffMin / 60);
    if (diffH < 24) return `${diffH}h ago`;
    return d.toLocaleDateString();
  } catch {
    return 'Unknown';
  }
}
