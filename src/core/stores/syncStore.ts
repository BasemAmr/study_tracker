import { writable } from 'svelte/store';
import type { WifiPeer } from '../sync/wifiTransport';

export interface PeerSyncStatus {
  kind: 'idle' | 'syncing' | 'synced' | 'failed';
  lastError?: string;
  lastSyncedAt?: Date;
  rowsSent?: number;
  rowsReceived?: number;
}

export type GlobalSyncStatus = 'idle' | 'syncing' | 'success' | 'error' | 'no_peers';

export interface GlobalSyncState {
  status: GlobalSyncStatus;
  lastSyncedAt?: Date;
  lastPeerName?: string;
  lastRowsReceived?: number;
  lastError?: string;
}

export interface SyncHistoryEntry {
  id?: number | null;
  peerDeviceId?: string | null;
  peerDeviceName?: string | null;
  transport: string;
  direction: 'push' | 'pull' | 'bidirectional';
  rowsSent: number;
  rowsReceived: number;
  success: boolean;
  errorMessage?: string | null;
  syncedAt?: string | null;
}

export interface SyncState {
  /** User-controlled config — the single source of truth for "is sync turned on?".
   * Indicator visibility keys off this flag, not on `serverRunning`, so the chip is
   * present as soon as the user opts in even before the server finishes booting. */
  syncEnabled: boolean;
  serverRunning: boolean;
  pairingCode: string;
  peers: WifiPeer[];
  peerStatus: Record<string, PeerSyncStatus>;
  unsyncedCount: number;
  history: SyncHistoryEntry[];
  globalStatus: GlobalSyncState;
}

const initialGlobalStatus: GlobalSyncState = {
  status: 'idle',
  lastSyncedAt: undefined,
  lastPeerName: undefined,
  lastRowsReceived: undefined,
  lastError: undefined
};

const initialState: SyncState = {
  syncEnabled: false,
  serverRunning: false,
  pairingCode: '',
  peers: [],
  peerStatus: {},
  unsyncedCount: 0,
  history: [],
  globalStatus: initialGlobalStatus
};

export const syncStore = writable<SyncState>(initialState);

export function updatePeerStatus(deviceId: string, status: Partial<PeerSyncStatus>) {
  syncStore.update(s => ({
    ...s,
    peerStatus: {
      ...s.peerStatus,
      [deviceId]: { ...(s.peerStatus[deviceId] || { kind: 'idle' }), ...status } as PeerSyncStatus
    }
  }));
}

export function setPeers(peers: WifiPeer[]) {
  syncStore.update(s => ({ ...s, peers }));
}

export function setServerRunning(serverRunning: boolean, pairingCode: string = '') {
  syncStore.update(s => ({
    ...s,
    serverRunning,
    pairingCode: pairingCode || s.pairingCode
  }));
}

export function addHistory(entry: SyncHistoryEntry) {
  syncStore.update(s => ({ ...s, history: [entry, ...s.history] }));
}

export function setHistory(history: SyncHistoryEntry[]) {
  syncStore.update(s => ({ ...s, history }));
}

export function setUnsyncedCount(unsyncedCount: number) {
  syncStore.update(s => ({ ...s, unsyncedCount }));
}

export function setSyncEnabled(syncEnabled: boolean) {
  syncStore.update(s => ({ ...s, syncEnabled }));
}

export function setGlobalSyncStatus(status: GlobalSyncStatus, metadata?: Partial<Omit<GlobalSyncState, 'status'>>) {
  syncStore.update(s => ({
    ...s,
    globalStatus: {
      status,
      lastSyncedAt: metadata?.lastSyncedAt || s.globalStatus.lastSyncedAt,
      lastPeerName: metadata?.lastPeerName || s.globalStatus.lastPeerName,
      lastRowsReceived: metadata?.lastRowsReceived || s.globalStatus.lastRowsReceived,
      lastError: metadata?.lastError || s.globalStatus.lastError
    }
  }));
  
  // Auto-transition from 'success' to 'idle' after 4 seconds
  if (status === 'success') {
    setTimeout(() => {
      syncStore.update(s => ({
        ...s,
        globalStatus: { ...s.globalStatus, status: 'idle' }
      }));
    }, 4000);
  }
}
