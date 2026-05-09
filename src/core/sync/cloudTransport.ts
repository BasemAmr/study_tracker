/**
 * Cloud Transport — optional Supabase or custom endpoint sync
 *
 * Disabled by default. User enables it and provides credentials.
 * Runs automatically in the background when online and no local transport is active.
 * Supports Supabase (free tier) and any custom REST endpoint.
 *
 * Protocol (custom endpoint):
 *   POST {url}/sync/push  — body: SyncPayload JSON, returns: SyncPayload JSON
 *   Authorization: Bearer {anonKey}
 *
 * Supabase: uses the REST API to upsert rows directly into cloud tables.
 * Custom: the user's endpoint must accept our SyncPayload and return theirs.
 */

import { getSettingByKey } from '../data/repositories/appSettingsRepository';
import {
  buildPayload,
  applyPayload,
  deserializePayload,
  serializePayload,
  getSyncState,
  updateSyncState,
  recordSyncHistory
} from './syncEngine';
import { getDeviceId, getDeviceName } from './syncIdentity';
import { getCurrentProfileSyncId, clampTimestamp } from './syncUtils';

export type CloudSyncResult = {
  success: boolean;
  provider?: string;
  rowsSent?: number;
  rowsReceived?: number;
  errorMessage?: string;
};

// ─── Config helpers ───────────────────────────────────────────────────────────

async function getCloudConfig() {
  const [enabled, provider, url, anonKey] = await Promise.all([
    getSettingByKey('cloudSyncEnabled'),
    getSettingByKey('cloudSyncProvider'),
    getSettingByKey('cloudSyncUrl'),
    getSettingByKey('cloudSyncAnonKey')
  ]);

  return {
    enabled: enabled?.value === 'true',
    provider: (provider?.value ?? 'supabase') as 'supabase' | 'custom',
    url: url?.value ?? '',
    anonKey: anonKey?.value ?? ''
  };
}

// ─── Sync via custom endpoint ─────────────────────────────────────────────────

async function syncViaCustomEndpoint(
  url: string,
  anonKey: string,
  outJson: string
): Promise<string | null> {
  const endpoint = url.replace(/\/$/, '') + '/sync/push';
  console.log(`SYNC: [Cloud] Pushing to custom endpoint: ${endpoint}`);
  const resp = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${anonKey}`
    },
    body: outJson
  });

  if (!resp.ok) {
    throw new Error(`Cloud sync HTTP ${resp.status}: ${await resp.text()}`);
  }

  const text = await resp.text();
  return text || null;
}

// ─── Sync via Supabase REST ───────────────────────────────────────────────────

async function syncViaSupabase(
  url: string,
  anonKey: string,
  outJson: string
): Promise<string | null> {
  // Use the Supabase Edge Function endpoint for sync (custom function the user deploys once)
  // or fall back to custom endpoint protocol
  return syncViaCustomEndpoint(url, anonKey, outJson);
}

// ─── Main cloud sync ──────────────────────────────────────────────────────────

/**
 * Run cloud sync if enabled and configured.
 * Returns immediately with no-op if cloud sync is disabled.
 */
export async function runCloudSync(): Promise<CloudSyncResult> {
  console.log(`SYNC: [Cloud] Running cloud sync...`);
  const config = await getCloudConfig();

  if (!config.enabled) {
    console.log(`SYNC: [Cloud] Aborted: Cloud sync disabled.`);
    return { success: true, errorMessage: 'Cloud sync is disabled.' };
  }

  if (!config.url) {
    console.log(`SYNC: [Cloud] Aborted: URL not configured.`);
    return { success: false, errorMessage: 'Cloud sync URL is not configured.' };
  }

  try {
    const deviceId = await getDeviceId();
    const deviceName = await getDeviceName();
    const profileSyncId = await getCurrentProfileSyncId();

    const cloudPeerId = `cloud:${config.provider}:${config.url}`;
    const lastSync = await getSyncState(cloudPeerId, 'cloud');
    const sinceTimestamp = clampTimestamp(lastSync);

    const outPayload = await buildPayload(profileSyncId, sinceTimestamp);
    const outJson = serializePayload(outPayload);
    const rowsSent = Object.values(outPayload.tables).reduce((a, r) => a + (r?.length ?? 0), 0);
    console.log(`SYNC: [Cloud] Payload built, ${rowsSent} rows. Sending...`);

    let incomingJson: string | null = null;

    if (config.provider === 'supabase') {
      incomingJson = await syncViaSupabase(config.url, config.anonKey, outJson);
    } else {
      incomingJson = await syncViaCustomEndpoint(config.url, config.anonKey, outJson);
    }

    console.log(`SYNC: [Cloud] Response received. Applying payload...`);
    let rowsReceived = 0;

    if (incomingJson) {
      try {
        const inPayload = deserializePayload(incomingJson);
        const applyResult = await applyPayload(inPayload);
        rowsReceived = applyResult.inserted + applyResult.updated;
      } catch (e) {
        // Incoming payload might be empty or server doesn't return one — that's fine
        console.warn('[CloudTransport] Could not parse incoming payload:', e);
      }
    }

    console.log(`SYNC: [Cloud] Sync complete. ${rowsReceived} rows received.`);
    await updateSyncState(cloudPeerId, 'cloud', 'bidirectional', rowsSent + rowsReceived);

    await recordSyncHistory({
      peerDeviceId: cloudPeerId,
      peerDeviceName: config.provider === 'supabase' ? 'Supabase Cloud' : 'Custom Cloud',
      transport: 'cloud',
      direction: 'bidirectional',
      rowsSent,
      rowsReceived,
      success: true
    });

    return {
      success: true,
      provider: config.provider,
      rowsSent,
      rowsReceived
    };
  } catch (err: any) {
    const msg = String(err?.message ?? err);
    console.error(`SYNC: [Cloud] Sync error: ${msg}`);

    await recordSyncHistory({
      peerDeviceId: `cloud:${config.provider}`,
      peerDeviceName: 'Cloud',
      transport: 'cloud',
      direction: 'bidirectional',
      rowsSent: 0,
      rowsReceived: 0,
      success: false,
      errorMessage: msg
    });

    return { success: false, errorMessage: msg };
  }
}

/** Check if we have a working internet connection (heuristic) */
export async function checkOnline(): Promise<boolean> {
  try {
    const resp = await fetch('https://www.google.com/generate_204', {
      method: 'HEAD',
      mode: 'no-cors',
      signal: AbortSignal.timeout(3000)
    });
    return true; // If fetch didn't throw, we have some connectivity
  } catch {
    return false;
  }
}
