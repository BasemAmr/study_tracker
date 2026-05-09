import { isTauri } from '@tauri-apps/api/core';
import { bootstrapSchedulerShell, onSchedulerAction } from './notificationScheduler';
import { handleSchedulerAction } from './notificationDispatcher';

let booted = false;

/**
 * Enables permission flow, restores `pendingSchedules` timers, multiplexes `@tauri-apps/plugin-notification`
 * tap events (`actionPerformed`) into dispatcher deep links — never blocks startup.
 */
export async function bootstrapStudyNotifications(): Promise<void> {
  if (!isTauri() || booted) return;
  booted = true;

  await bootstrapSchedulerShell().catch((e) => {
    console.warn('[notifications] Scheduler shell skipped:', e);
  });

  try {
    onSchedulerAction((o) => {
      void handleSchedulerAction(o).catch((e) => console.error('[notifications] action handler:', e));
    });
  } catch (e) {
    console.warn('[notifications] onSchedulerAction registration failed:', e);
  }
}
