/**
 * SyncTrigger — Desktop version of the Phone's SyncTrigger.
 * Used to broadcast when local data has changed so the sync engine
 * can refresh its outgoing payload.
 */

import { isSyncing } from './syncEngine';

type SyncListener = () => void;

class SyncTrigger {
  private static instance: SyncTrigger;
  private listeners = new Set<SyncListener>();
  private debounceTimer: any = null;
  private isSuppressed = false;
  
  private constructor() {}

  static getInstance(): SyncTrigger {
    if (!SyncTrigger.instance) {
      SyncTrigger.instance = new SyncTrigger();
    }
    return SyncTrigger.instance;
  }

  suppress() { this.isSuppressed = true; }
  unsuppress() { this.isSuppressed = false; }

  /** Notify that data has changed. Debounces the actual trigger. */
  notifyChange() {
    if (isSyncing() || this.isSuppressed) return;
    
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      console.log('SYNC: [Trigger] Data change notified, triggering listeners...');
      this.listeners.forEach(l => l());
    }, 5000); // 5s debounce as requested
  }

  subscribe(listener: SyncListener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

export const syncTrigger = SyncTrigger.getInstance();
