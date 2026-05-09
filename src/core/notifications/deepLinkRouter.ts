import { isTauri } from '@tauri-apps/api/core';
import { navigate, type Route } from '../stores/router';
import { NotificationId } from './notificationKinds';

/** BEHAVIOR-N5 — tap targets documented in Foundation tickets (Goals → achievements tab here). */
export function routeForNotificationId(id: number): Route {
  switch (id) {
    case NotificationId.PreStudy:
      return 'sessions';
    case NotificationId.Streak:
    case NotificationId.Reengagement3:
    case NotificationId.Reengagement7:
      return 'dashboard';
    case NotificationId.Weekly:
      return 'analytics';
    case NotificationId.Goal:
      return 'achievements';
    default:
      return 'dashboard';
  }
}

export async function navigateNotificationDeepLink(notificationId?: number): Promise<void> {
  if (notificationId === undefined || notificationId === null || Number.isNaN(notificationId)) return;
  navigate(routeForNotificationId(notificationId));
  if (!isTauri()) return;
  try {
    const { getCurrentWindow } = await import('@tauri-apps/api/window');
    const win = getCurrentWindow();
    await win.show().catch(() => undefined);
    await win.setFocus().catch(() => undefined);
  } catch {
    /** Window API unavailable (pure web build) — route change alone suffices. */
  }
}
