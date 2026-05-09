/**
 * WiFi LAN Transport — local HTTP sync via mDNS discovery
 *
 * The desktop (Tauri) runs a local axum HTTP server on port 47821
 * and advertises itself via mDNS as _studysync._tcp.
 *
 * Discovery: the Svelte frontend calls Tauri commands that use mdns-sd
 * to find nearby StudyTracker desktops hosting on the same LAN ( multicast;
 * isolated guest Wi‑Fi or blocked mDNS yields zero peers).
 *
 * Pairing: first connection requires the user to enter a 6-digit code
 * shown on the host device. The code is stored in app_settings and
 * invalidated after first use.
 *
 * Sync flow (bidirectional):
 *   1. Client discovers host via mDNS
 *   2. Client calls POST /sync/handshake with its device_id + name + pairing_code
 *   3. Host validates pairing code (first time) or known peer (subsequent)
 *   4. Host responds with its own payload (changes since last sync with this peer)
 *   5. Client sends its payload to POST /sync/exchange
 *   6. Both update sync_state
 */

import { invoke } from '@tauri-apps/api/core';
import { get } from 'svelte/store';
import { ask, message } from '@tauri-apps/plugin-dialog';
import { deleteSettingByKey, getSettingByKey, setSettingByKey } from '../data/repositories/appSettingsRepository';
import {
  buildPayload,
  applyPayload,
  deserializePayload,
  serializePayload,
  getSyncState,
  updateSyncState,
  recordSyncHistory,
  isSyncing,
  type SyncPayload
} from './syncEngine';
import {
  getSyncMergeDecision,
  setSyncMergeDecision,
  hasAnySyncStateForPeer,
  countLocalDefaultProfileData,
  countRemoteDefaultProfileDataInPayload,
  isLocalDefaultProfileNotEmpty
} from './syncMerge';
import {
  getDeviceId,
  getDeviceName,
  getPeerPairingCode,
  savePeerPairingCode
} from './syncIdentity';
import { getCurrentProfileSyncId, clampTimestamp, generatePairingCode } from './syncUtils';
import { addHistory, syncStore, updatePeerStatus, setServerRunning, setPeers, setGlobalSyncStatus } from '../stores/syncStore';
import { profileStore } from '../stores/profileStore';
import { syncTrigger } from './syncTrigger';
import { getDatabase } from '../data/database';

/** Serialize pop+apply so two timers cannot overlap (SQLITE_BUSY / "database is locked"). */
let processServerQueueTail: Promise<void> = Promise.resolve();

/** First-time default-profile merge (BEHAVIOR-010) + apply. */
export async function applyIncomingPayloadWithFirstSyncFlow(
  peer: { deviceId: string; deviceName: string },
  inPayload: SyncPayload
): Promise<{ result: Awaited<ReturnType<typeof applyPayload>>; userCancelled: boolean }> {
  const myId = await getDeviceId();
  if (inPayload.device_id === myId) {
    return { result: await applyPayload(inPayload), userCancelled: false };
  }
  let mergeMode: 'merge' | 'separate' = 'merge';
  const prior = await getSyncMergeDecision(peer.deviceId);
  if (prior) {
    mergeMode = prior;
  } else {
    const isFirst = !(await hasAnySyncStateForPeer(peer.deviceId, 'wifi'));
    if (isFirst) {
      const hasRemoteDefault = (inPayload.tables?.profiles ?? []).some(
        (r) => String((r as { sync_id?: string }).sync_id) === 'profile-default'
      );
      const local = await countLocalDefaultProfileData();
      const remoteN = countRemoteDefaultProfileDataInPayload(inPayload);
      if (hasRemoteDefault && isLocalDefaultProfileNotEmpty(local) && remoteN > 0) {
        const res = await message(
          `First sync with ${peer.deviceName} detected.\n\nBoth devices have a Default Profile with data.\nHow would you like to handle this?`,
          {
            title: 'First sync',
            kind: 'info',
            buttons: {
              yes: 'Merge into one profile',
              no: "Keep separate",
              cancel: 'Cancel sync'
            }
          }
        );
        if (res === 'Cancel') {
          return {
            result: { inserted: 0, updated: 0, skipped: 0, deferred: 0, errors: [] },
            userCancelled: true
          };
        }
        mergeMode = res === 'Yes' ? 'merge' : 'separate';
        await setSyncMergeDecision(peer.deviceId, mergeMode);
      } else {
        await setSyncMergeDecision(peer.deviceId, 'merge');
      }
    }
  }
  const result = await applyPayload(inPayload, { peerDeviceId: peer.deviceId, mergeMode });
  return { result, userCancelled: false };
}


export type WifiPeer = {
  deviceId: string;
  deviceName: string;
  host: string;
  port: number;
  lastSyncedAt: string | null;
  /** Resolved without mDNS (Windows often fails to browse Android NSD peers). */
  fromLanBookmark?: boolean;
};

export type WifiSyncResult = {
  success: boolean;
  peerName?: string;
  rowsSent?: number;
  rowsReceived?: number;
  errorMessage?: string;
};

// ─── Server control (desktop only) ──────────────────────────────────────────

/** Start the local sync HTTP server (Tauri calls Rust plugin) */
export async function startWifiServer(): Promise<{ port: number; pairingCode: string }> {
  const passphrase = (await getSettingByKey('syncPassphrase'))?.value ?? '';
  const currentCodeRaw = (await getSettingByKey('wifiSyncPairingCode'))?.value ?? '';
  const currentCode = currentCodeRaw.trim();

  // Reuse persisted code if valid; otherwise generate once and persist.
  const hasValidPersistedCode = /^\d{6}$/.test(currentCode);
  const pairingCode = hasValidPersistedCode ? currentCode : generatePairingCode();
  if (!hasValidPersistedCode) {
    await setSettingByKey('wifiSyncPairingCode', pairingCode);
    console.log(`SYNC: [WiFi] Generated and persisted new pairing code.`);
  } else {
    console.log(`SYNC: [WiFi] Reusing persisted pairing code.`);
  }

  const port = Number((await getSettingByKey('wifiSyncPort'))?.value ?? 47821);
  const deviceId = await getDeviceId();
  const deviceName = await getDeviceName();

  console.log(`SYNC: [WiFi] Starting server on port ${port} with pairing code ${pairingCode}...`);

  await invoke('sync_wifi_start_server', {
    port,
    pairingCode,
    passphrase,
    deviceId,
    deviceName
  });

  setServerRunning(true, pairingCode);
  await hydrateLanPeersFromBookmarks();
  return { port, pairingCode };
}

/** Stop the local sync HTTP server */
export async function stopWifiServer(): Promise<void> {
  console.log(`SYNC: [WiFi] Stopping server...`);
  await invoke('sync_wifi_stop_server');
  setServerRunning(false, '');
  setPeers([]);
}

/** Regenerate pairing code (invalidates old one) */
export async function regeneratePairingCode(): Promise<string> {
  const code = generatePairingCode();
  await setSettingByKey('wifiSyncPairingCode', code);
  await invoke('sync_wifi_update_pairing_code', { code });
  setServerRunning(true, code);
  return code;
}

/** Reset pairing code persistence and force a fresh host code. */
export async function resetPairingCode(): Promise<string> {
  await deleteSettingByKey('wifiSyncPairingCode');
  return await regeneratePairingCode();
}

// ─── Discovery ──────────────────────────────────────────────────────────────

/** One in-flight Rust discover at a time (overlapping invokes stalled / 0 results on Windows). */
let discoverPeersInFlight: Promise<WifiPeer[]> | null = null;

/** Discover nearby StudyTracker devices on the LAN via mDNS */
export async function discoverPeers(): Promise<WifiPeer[]> {
  if (!discoverPeersInFlight) {
    discoverPeersInFlight = runDiscoverPeers().finally(() => {
      discoverPeersInFlight = null;
    });
  }
  return discoverPeersInFlight;
}

const WIFI_LAN_BOOKMARK_KEY = 'wifiLanPeerBookmarks';

type LanBookmark = {
  deviceId: string;
  deviceName: string;
  host: string;
  port: number;
};

async function loadLanBookmarks(): Promise<LanBookmark[]> {
  const raw = (await getSettingByKey(WIFI_LAN_BOOKMARK_KEY))?.value ?? '[]';
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    const out: LanBookmark[] = [];
    for (const x of parsed) {
      const o = x as Partial<LanBookmark>;
      if (
        o.deviceId &&
        o.deviceName != null &&
        o.host &&
        typeof o.port === 'number'
      ) {
        out.push({
          deviceId: String(o.deviceId),
          deviceName: String(o.deviceName),
          host: String(o.host),
          port: o.port
        });
      }
    }
    return out;
  } catch {
    return [];
  }
}

async function saveLanBookmarks(list: LanBookmark[]): Promise<void> {
  await setSettingByKey(WIFI_LAN_BOOKMARK_KEY, JSON.stringify(list));
}

/**
 * Probe a peer that is hosting StudyTracker on the LAN (GET /sync/status).
 * Bypasses unreliable mDNS on Windows/Android cross-discovery.
 *
 * Important: LAN probes must run via Tauri `invoke`, not `fetch`. The desktop UI is served from
 * `localhost` origins; fetching `http://<phone-LAN>:47821/` is cross-origin and most LAN hosts
 * (e.g. Flutter) omit CORS headers, so the browser blocks the response entirely.
 */
function isInvalidTcpPort(p: number) {
  return !Number.isFinite(p) || p < 1 || p > 65535;
}

export type ProbeLanDetailed =
  | { ok: true; deviceId: string; deviceName: string }
  | { ok: false; diagnostic: string };

async function probeLanPeerDetailed(host: string, port: number): Promise<ProbeLanDetailed> {
  const h = host.trim();
  const p = port;
  if (!h || isInvalidTcpPort(p)) {
    return { ok: false, diagnostic: 'Invalid host or port.' };
  }

  try {
    const r = await invoke<{
      ok: boolean;
      deviceId?: string;
      deviceName?: string;
      diagnostic?: string;
    }>('sync_wifi_probe_status', { host: h, port: p });

    if (r.ok && r.deviceId) {
      return { ok: true, deviceId: r.deviceId, deviceName: r.deviceName ?? 'Device' };
    }
    return {
      ok: false,
      diagnostic: r.diagnostic ?? 'Probe returned no matching device id.'
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, diagnostic: `sync_wifi_probe_status failed: ${msg}` };
  }
}

/** @deprecated prefer probeLanPeerDetailed — kept for callers that only need success/fail */
export async function probeLanPeer(host: string, port: number): Promise<{ deviceId: string; deviceName: string } | null> {
  const r = await probeLanPeerDetailed(host, port);
  return r.ok ? { deviceId: r.deviceId, deviceName: r.deviceName } : null;
}

export type AddLanBookmarkOutcome =
  | { ok: true; bookmark: LanBookmark }
  | { ok: false; detail: string };

/**
 * Persist a reachable peer by IPv4/host + port so it appears in discovery without mDNS.
 */
export async function addLanBookmarkPeer(hostInput: string, portInput?: number): Promise<AddLanBookmarkOutcome> {
  const host = hostInput.trim();
  const port = portInput ?? Number((await getSettingByKey('wifiSyncPort'))?.value ?? 47821);
  if (!host || isInvalidTcpPort(port)) {
    console.warn('[WiFi] Invalid host/port for LAN bookmark.');
    return { ok: false, detail: 'Enter a valid host and port.' };
  }

  const probe = await probeLanPeerDetailed(host, port);
  if (!probe.ok) {
    console.warn('[WiFi] probeLanPeer failed for', host, port, probe.diagnostic);
    return { ok: false, detail: probe.diagnostic };
  }

  const list = await loadLanBookmarks();
  const merged = [...list.filter((b) => b.deviceId !== probe.deviceId), { ...probe, host, port }];
  await saveLanBookmarks(merged);
  console.log('[WiFi] Saved LAN bookmark for', probe.deviceId, host, port);
  return {
    ok: true,
    bookmark: { deviceId: probe.deviceId, deviceName: probe.deviceName, host, port }
  };
}

export async function removeLanBookmarkPeer(deviceId: string): Promise<void> {
  const list = (await loadLanBookmarks()).filter((b) => b.deviceId !== deviceId);
  await saveLanBookmarks(list);
}

/** Merge bookmarks (applied first), then overwrite by mDNS hits for same `device_id` (fresh host). */
async function mergedPeersFromBookmarksAndMdns(
  rawMdns: Array<{ device_id: string; device_name: string; host: string; port: number }>,
  myDeviceId: string
): Promise<WifiPeer[]> {
  const bookmarks = await loadLanBookmarks();
  const byId = new Map<string, WifiPeer>();

  for (const b of bookmarks) {
    if (b.deviceId === myDeviceId) continue;
    const lastSyncedAt = await getSyncState(b.deviceId, 'wifi');
    byId.set(b.deviceId, {
      deviceId: b.deviceId,
      deviceName: b.deviceName,
      host: b.host,
      port: b.port,
      lastSyncedAt,
      fromLanBookmark: true
    });
  }

  for (const p of rawMdns) {
    if (p.device_id === myDeviceId) continue;
    const lastSyncedAt = await getSyncState(p.device_id, 'wifi');
    byId.set(p.device_id, {
      deviceId: p.device_id,
      deviceName: p.device_name,
      host: p.host,
      port: p.port,
      lastSyncedAt,
      fromLanBookmark: false
    });
  }

  return [...byId.values()];
}

type RawMdnsPeer = {
  device_id: string;
  device_name: string;
  host: string;
  port: number;
};

async function buildMergedPeerList(rawMdns: RawMdnsPeer[]): Promise<WifiPeer[]> {
  const myDeviceId = await getDeviceId();
  return mergedPeersFromBookmarksAndMdns(rawMdns, myDeviceId);
}

/**
 * Populate the peers list from saved LAN bookmarks only (no mDNS).
 * Called when hosting starts so users see bookmarks immediately; discovery can take ~12s or fail on Windows.
 */
export async function hydrateLanPeersFromBookmarks(): Promise<WifiPeer[]> {
  try {
    const peers = await buildMergedPeerList([]);
    setPeers(peers);
    return peers;
  } catch (e) {
    console.warn('[WiFi] hydrateLanPeersFromBookmarks failed:', e);
    return [];
  }
}

async function runDiscoverPeers(): Promise<WifiPeer[]> {
  console.log(`SYNC: [WiFi] Starting mDNS discovery (_studysync._tcp.local.)…`);

  async function finishWith(rawMdns: RawMdnsPeer[], mdnsLogged: boolean) {
    const peers = await buildMergedPeerList(rawMdns);
    const nBookmark = peers.filter((p) => p.fromLanBookmark).length;
    if (mdnsLogged && rawMdns.length === 0 && nBookmark > 0) {
      console.log(
        `SYNC: [WiFi] mDNS returned 0 services; listing ${nBookmark} saved LAN peer(s). Enter the phone’s IPv4 below if empty.`
      );
    } else if (nBookmark > 0) {
      console.log(`SYNC: [WiFi] ${peers.length} peer(s) total, ${nBookmark} from saved LAN IPs.`);
    }
    setPeers(peers);
    
    // Set global sync status based on peer discovery results
    if (peers.length === 0) {
      setGlobalSyncStatus('no_peers');
    }
    
    return peers;
  }

  const hasTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
  if (!hasTauri) {
    console.warn('SYNC: [WiFi] Discovery skipped: Tauri runtime not detected; applying LAN bookmarks only.');
    return finishWith([], false);
  }
  try {
    const rawPeers = await invoke<RawMdnsPeer[]>('sync_wifi_discover_peers', {});
    console.log(`SYNC: [WiFi] Discovery complete (mDNS raw). Found ${rawPeers.length} advertised services.`);
    return await finishWith(rawPeers, true);
  } catch (error) {
    console.error('SYNC: [WiFi] Discovery failed:', error);
    console.warn(
      'SYNC: [WiFi] Applying LAN bookmarks only (mDNS unavailable — common after hot-reload or on Windows/Android).'
    );
    return await finishWith([], true);
  }
}

// ─── Sync with a specific peer ────────────────────────────────────────────────

/**
 * Perform a bidirectional sync with a discovered peer.
 * pairingCode is only needed on first connection.
 */
export async function syncWithPeer(
  peer: WifiPeer,
  pairingCode?: string
): Promise<WifiSyncResult> {
  try {
    const myDeviceId = await getDeviceId();
    const myDeviceName = await getDeviceName();
    const profileSyncId = await getCurrentProfileSyncId();

    let actualPairingCode = pairingCode;
    if (!actualPairingCode) {
      actualPairingCode = await getPeerPairingCode(peer.deviceId) ?? '';
    }
    if (!actualPairingCode) {
      actualPairingCode = (await getSettingByKey('wifiSyncPairingCode'))?.value ?? '';
      if (actualPairingCode) {
        console.log(`SYNC: [WiFi] Using host pairing code fallback for peer ${peer.deviceId}`);
      }
    }
    if (!actualPairingCode) {
      return { success: false, errorMessage: 'No pairing code stored' };
    }

    // Determine since_timestamp for this peer
    const lastSync = await getSyncState(peer.deviceId, 'wifi');
    const sinceTimestamp = clampTimestamp(lastSync);

    // Build our outgoing payload
    console.log(`SYNC: [WiFi] Initiating sync with peer: ${peer.deviceName} at ${peer.host}:${peer.port}`);
    updatePeerStatus(peer.deviceId, { kind: 'syncing' });
    setGlobalSyncStatus('syncing');

    const outPayload = await buildPayload(profileSyncId, sinceTimestamp);
    const outJson = serializePayload(outPayload);
    const rowsSent = Object.values(outPayload.tables).reduce((a, r) => a + (r?.length ?? 0), 0);
    console.log(`SYNC: [WiFi] Client payload built. Rows to send: ${rowsSent}. Sending exchange to Rust...`);

    // Call Rust command to do the HTTP exchange
    const { incomingJson, error, remoteTimestamp } = await invoke<{
      incomingJson: string | null;
      error: string | null;
      remoteTimestamp: number | null;
    }>('sync_wifi_exchange', {
      host: peer.host,
      port: peer.port,
      myDeviceId,
      myDeviceName,
      pairingCode: actualPairingCode,
      payload: outJson
    });

    const localNow = Date.now();
    if (remoteTimestamp != null && Number.isFinite(remoteTimestamp)) {
      const skew = remoteTimestamp - localNow;
      if (Math.abs(skew) > 60_000) {
        console.warn(
          `[Sync] Clock skew detected: ${skew}ms from ${peer.deviceName}`
        );
      }
    }

    if (error) {
      const errorMsg = typeof error === 'string' ? error : 'Unknown error';

      // Recover from stale peer-specific code by retrying once with current host code.
      if (/HTTP\s*401|Invalid pairing code/i.test(errorMsg)) {
        const hostCode = (await getSettingByKey('wifiSyncPairingCode'))?.value?.trim() ?? '';
        if (hostCode && hostCode !== actualPairingCode) {
          console.warn(`SYNC: [WiFi] Pairing rejected for ${peer.deviceId}; retrying with host code fallback.`);
          return await syncWithPeer(peer, hostCode);
        }
      }

      console.error(`SYNC: [WiFi] Sync exchange failed: ${errorMsg}`);
      updatePeerStatus(peer.deviceId, { kind: 'failed', lastError: errorMsg });
      setGlobalSyncStatus('error', { lastError: errorMsg });

      const historyEntry = {
        peerDeviceId: peer.deviceId,
        peerDeviceName: peer.deviceName,
        transport: 'wifi',
        direction: 'bidirectional' as const,
        rowsSent: 0,
        rowsReceived: 0,
        success: false,
        errorMessage: errorMsg
      };
      await recordSyncHistory(historyEntry);
      addHistory({ ...historyEntry, syncedAt: new Date().toISOString() });

      return { success: false, errorMessage: errorMsg };
    }

    let rowsReceived = 0;

    if (incomingJson) {
      console.log(`SYNC: [WiFi] Received response from host. Applying payload...`);
      const inPayload = deserializePayload(incomingJson);
      const { result: applyResult, userCancelled } = await applyIncomingPayloadWithFirstSyncFlow(
        { deviceId: peer.deviceId, deviceName: peer.deviceName },
        inPayload
      );
      if (userCancelled) {
        updatePeerStatus(peer.deviceId, { kind: 'failed', lastError: 'Sync cancelled' });
        return { success: false, errorMessage: 'Sync cancelled' };
      }
      rowsReceived = applyResult.inserted + applyResult.updated;
      if ((inPayload.tables.profiles?.length ?? 0) > 0) {
        await profileStore.init();
      }
    }

    // Save pairing code for future auto-sync
    if (actualPairingCode) {
      await savePeerPairingCode(peer.deviceId, actualPairingCode);
    }

    console.log(`SYNC: [WiFi] Client sync complete. Rows received: ${rowsReceived}`);
    if (rowsSent > 0 || rowsReceived > 0) {
      await updateSyncState(peer.deviceId, 'wifi', 'bidirectional', rowsSent + rowsReceived);
    }

    const historyEntry = {
      peerDeviceId: peer.deviceId,
      peerDeviceName: peer.deviceName,
      transport: 'wifi',
      direction: 'bidirectional' as const,
      rowsSent,
      rowsReceived,
      success: true
    };
    await recordSyncHistory(historyEntry);
    addHistory({ ...historyEntry, syncedAt: new Date().toISOString() });

    updatePeerStatus(peer.deviceId, {
      kind: 'synced',
      rowsSent,
      rowsReceived,
      lastSyncedAt: new Date()
    });

    setGlobalSyncStatus('success', {
      lastSyncedAt: new Date(),
      lastPeerName: peer.deviceName,
      lastRowsReceived: rowsReceived
    });

    return {
      success: true,
      peerName: peer.deviceName,
      rowsSent,
      rowsReceived
    };
  } catch (err: any) {
    const errorMsg = String(err?.message ?? err);
    updatePeerStatus(peer.deviceId, { kind: 'failed', lastError: errorMsg });
    setGlobalSyncStatus('error', { lastError: errorMsg });
    return { success: false, errorMessage: errorMsg };
  }
}

/** Clear the sync memory for a peer to force a full re-sync next time. */
export async function resetSyncState(peer: WifiPeer): Promise<void> {
  await updateSyncState(peer.deviceId, 'wifi', 'bidirectional', 0, true);
  console.log(`SYNC: [WiFi] Sync state cleared for peer ${peer.deviceId}`);
}

/** 
 * Poll the server for incoming payloads and process them.
 * Called from `initPayloadPump` while the WiFi server is running.
 */
export async function processServerQueue(): Promise<void> {
  if (isSyncing()) return;
  const prev = processServerQueueTail;
  let release!: () => void;
  processServerQueueTail = new Promise<void>((resolve) => {
    release = resolve;
  });
  await prev;
  try {
    if (isSyncing()) return;
    try {
      const incomingJson = await invoke<string | null>('sync_wifi_pop_incoming_payload');
      if (!incomingJson) return;

      const payload = deserializePayload(incomingJson);
      const incomingRowCount = Object.values(payload.tables ?? {}).reduce(
        (a, r) => a + (r?.length ?? 0),
        0
      );
      console.log(`SYNC: [WiFi] Processing incoming payload from server queue (rows: ${incomingRowCount})...`);

      // Empty exchange (just a watermark ping). Skip apply / refresh / history
      // entirely — this is the #1 source of busy-wait DB churn.
      if (incomingRowCount === 0) {
        return;
      }

      const { result: applyResult, userCancelled } = await applyIncomingPayloadWithFirstSyncFlow(
        { deviceId: payload.device_id, deviceName: payload.device_name },
        payload
      );
      if (userCancelled) {
        console.log(`SYNC: [WiFi] User cancelled first-sync merge; incoming payload not applied.`);
        return;
      }
      console.log(`SYNC: [WiFi] Applied incoming payload: +${applyResult.inserted} ~${applyResult.updated}`);
      if ((payload.tables.profiles?.length ?? 0) > 0) {
        await profileStore.init();
      }

      const rowsReceived = applyResult.inserted + applyResult.updated;
      if (rowsReceived > 0) {
        await updateSyncState(payload.device_id, 'wifi', 'bidirectional', rowsReceived);
        await refreshServerPayload(payload.since_timestamp);

        const historyEntry = {
          peerDeviceId: payload.device_id,
          peerDeviceName: payload.device_name,
          transport: 'wifi',
          direction: 'bidirectional' as const,
          rowsSent: 0,
          rowsReceived,
          success: true
        };
        await recordSyncHistory(historyEntry);
        addHistory({ ...historyEntry, syncedAt: new Date().toISOString() });
      }
    } catch (err) {
      console.error(`SYNC: [WiFi] Server queue processing failed:`, err);
    }
  } finally {
    release();
  }
}

/** Pre-set the server's outgoing payload so the phone gets data immediately */
export async function refreshServerPayload(sinceOverride?: string): Promise<void> {
  try {
    const profileSyncId = await getCurrentProfileSyncId();

    let since = sinceOverride;
    if (!since) {
      // Find the latest successful sync time among all peers as a baseline watermark
      const database = await getDatabase();
      const stateRows = await database.select<Array<{ last_synced_at: string }>>(
        'SELECT last_synced_at FROM sync_state ORDER BY last_synced_at DESC LIMIT 1;'
      );
      since = stateRows[0]?.last_synced_at || '1970-01-01T00:00:00.000Z';
    }

    console.log(`SYNC: [WiFi] Refreshing server payload (since: ${since})`);
    const payload = await buildPayload(profileSyncId, since);
    const serialized = serializePayload(payload);
    await invoke('sync_wifi_set_outgoing_payload', { payload: serialized });

    const rows = Object.values(payload.tables).reduce((a, r) => a + (r?.length ?? 0), 0);
    console.log(`SYNC: [WiFi] Server payload refreshed. Total rows ready: ${rows}`);
  } catch (err) {
    console.error(`SYNC: [WiFi] Failed to refresh server payload:`, err);
  }
}

/** Start the background payload pump.
 *
 * Idempotent: calling twice (e.g. after Vite HMR re-runs App.svelte's onMount,
 * or after StrictMode-style double mount) tears down the previous pump first
 * so we never end up with parallel queue intervals stacking on top of each other.
 */
export function initPayloadPump() {
  const w = window as unknown as { __studytrackerPumpDispose?: () => void };
  if (w.__studytrackerPumpDispose) {
    console.log('SYNC: [WiFi] Disposing previous payload pump (HMR/re-init).');
    try { w.__studytrackerPumpDispose(); } catch { /* ignore */ }
    w.__studytrackerPumpDispose = undefined;
  }

  console.log('SYNC: [WiFi] Initializing payload pump...');

  refreshServerPayload();
  let queueBusy = false;
  const queueInterval = window.setInterval(() => {
    if (queueBusy) return;
    if (!get(syncStore).serverRunning) return;
    queueBusy = true;
    void processServerQueue().finally(() => {
      queueBusy = false;
    });
  }, 2500);

  // Refresh on every data change (do NOT run mDNS here — overlapping discover_peers invokes starved scans / 0 peers on Windows.)
  const unsubscribe = syncTrigger.subscribe(async () => {
    console.log('SYNC: [WiFi] Data change detected, refreshing + pushing...');
    await refreshServerPayload();

    const peers = get(syncStore).peers;
    for (const peer of peers) {
      const savedCode = await getPeerPairingCode(peer.deviceId);
      const hostCode = (await getSettingByKey('wifiSyncPairingCode'))?.value ?? '';
      const effectiveCode = savedCode || hostCode;
      if (effectiveCode) {
        console.log(`SYNC: [WiFi] Auto-syncing with paired peer ${peer.deviceName}...`);
        await syncWithPeer(peer, effectiveCode);
      }
    }
  });

  const dispose = () => {
    window.clearInterval(queueInterval);
    unsubscribe();
  };
  w.__studytrackerPumpDispose = dispose;
  return dispose;
}
