/**
 * File Transport — export/import sync payloads as encrypted .studysync files
 *
 * Works on any platform (desktop + mobile). No network required.
 * The user moves the file manually via USB drive, email, cloud storage, etc.
 *
 * Encryption: AES-256-GCM with PBKDF2 key derivation from user passphrase.
 * Without the correct passphrase the file is unreadable.
 *
 * On Tauri/desktop: uses Tauri dialog + fs APIs via invoke
 * On Flutter/mobile: uses share_plus + file_picker (handled in Dart side)
 */

import { invoke } from '@tauri-apps/api/core';
import { getSettingByKey } from '../data/repositories/appSettingsRepository';
import {
  buildPayload,
  applyPayload,
  deserializePayload,
  serializePayload,
  updateSyncState,
  recordSyncHistory,
  type SyncPayload
} from './syncEngine';
import { getCurrentProfileSyncId } from './syncUtils';

export type FileTransportResult = {
  success: boolean;
  rowsExported?: number;
  rowsImported?: number;
  errorMessage?: string;
};

// ─── Passphrase helpers ───────────────────────────────────────────────────────

async function getPassphrase(): Promise<string> {
  const row = await getSettingByKey('syncPassphrase');
  return row?.value ?? '';
}

// ─── Export ───────────────────────────────────────────────────────────────────

/**
 * Build a sync payload and export it as an encrypted .studysync file.
 * Opens a Tauri save dialog on desktop.
 */
export async function exportSyncFile(
  sinceTimestamp = '1970-01-01T00:00:00.000Z'
): Promise<FileTransportResult> {
  console.log(`SYNC: [File] Starting export...`);
  try {
    const profileSyncId = await getCurrentProfileSyncId();
    const payload = await buildPayload(profileSyncId, sinceTimestamp);
    const json = serializePayload(payload);
    const passphrase = await getPassphrase();
    console.log(`SYNC: [File] Payload serialized, length: ${json.length}. Triggering Tauri save dialog...`);

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const fileName = `studysync-${timestamp}.studysync`;

    // Call Rust command to handle file dialog + encrypted write
    await invoke('sync_export_file', {
      json,
      passphrase,
      suggestedName: fileName
    });

    const rowCount = Object.values(payload.tables).reduce((acc, rows) => acc + (rows?.length ?? 0), 0);
    console.log(`SYNC: [File] Export successful. Rows exported: ${rowCount}`);

    await recordSyncHistory({
      peerDeviceId: null,
      peerDeviceName: 'File Export',
      transport: 'file',
      direction: 'push',
      rowsSent: rowCount,
      rowsReceived: 0,
      success: true
    });

    return { success: true, rowsExported: rowCount };
  } catch (err: any) {
    console.error(`SYNC: [File] Export failed: ${err}`);
    return { success: false, errorMessage: String(err?.message ?? err) };
  }
}

// ─── Import ───────────────────────────────────────────────────────────────────

/**
 * Open a file picker, read and decrypt a .studysync file, apply the payload.
 */
export async function importSyncFile(): Promise<FileTransportResult> {
  console.log(`SYNC: [File] Starting import...`);
  try {
    const passphrase = await getPassphrase();

    // Call Rust command to handle file dialog + encrypted read
    console.log(`SYNC: [File] Triggering Tauri open dialog...`);
    const json = await invoke<string>('sync_import_file', { passphrase });

    console.log(`SYNC: [File] File read and decrypted. Deserializing payload...`);
    const payload = deserializePayload(json);
    const result = await applyPayload(payload);

    const rowsReceived = result.inserted + result.updated;
    console.log(`SYNC: [File] Import complete. Rows imported: ${rowsReceived}`);

    await updateSyncState(
      payload.device_id ?? 'file-import',
      'file',
      'pull',
      rowsReceived
    );

    await recordSyncHistory({
      peerDeviceId: payload.device_id ?? null,
      peerDeviceName: payload.device_name ?? 'File Import',
      transport: 'file',
      direction: 'pull',
      rowsSent: 0,
      rowsReceived,
      success: result.errors.length === 0,
      errorMessage: result.errors.length > 0 ? result.errors.slice(0, 3).join('; ') : undefined
    });

    return {
      success: true,
      rowsImported: rowsReceived
    };
  } catch (err: any) {
    console.error(`SYNC: [File] Import failed: ${err}`);
    return { success: false, errorMessage: String(err?.message ?? err) };
  }
}

// ─── Full sync from payload string (used by other transports too) ─────────────

export async function applySyncPayloadJson(
  json: string,
  transport: string
): Promise<{ success: boolean; result?: ReturnType<typeof applyPayload> extends Promise<infer R> ? R : never; error?: string }> {
  try {
    const payload = deserializePayload(json);
    const result = await applyPayload(payload);

    await updateSyncState(payload.device_id, transport, 'pull', result.inserted + result.updated);

    return { success: true, result };
  } catch (err: any) {
    return { success: false, error: String(err?.message ?? err) };
  }
}
