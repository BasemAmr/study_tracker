import { isTauri } from '@tauri-apps/api/core';
import {
  isPermissionGranted,
  onAction as onNotificationNativeAction,
  requestPermission,
  type Options as NativeNotificationOptions
} from '@tauri-apps/plugin-notification';
import type { PluginListener } from '@tauri-apps/api/core';
import { getSettingByKey, setSettingByKey } from '../data/repositories/appSettingsRepository';
import { NotificationId, type NotificationKind, type NotificationPayload } from './notificationKinds';
import { dispatchTimedNotification } from './notificationDispatcher';

export { NotificationId };
export type { NotificationKind, NotificationPayload } from './notificationKinds';

export const PENDING_SCHEDULES_KEY = 'pendingSchedules';

/** 1 Sun … 7 Sat (matches prior ScheduleInterval.weekday numbering). */
type ScheduleMode = 'once' | 'daily' | 'weekly' | 'interval';

type PersistedSchedule = {
  id: number;
  mode: ScheduleMode;
  /** ISO (local wall clock semantics — parsed with `new Date(iso)`). */
  nextFireAtIso: string;
  hourMinute?: string;
  weekday?: number;
  /** For 'interval' mode: hours between recurring fires. Must be > 0. */
  intervalHours?: number;
  payload: NotificationPayload;
};

/** In-memory slot for an armed timer plus the descriptor mirrored to KV. */
type Armed = {
  timeoutId: ReturnType<typeof setTimeout>;
  desc: PersistedSchedule;
};

const activeById = new Map<number, Armed>();

/** Optional listeners for OS click events (studytracker_notification extra). */
const actionSubs = new Set<(opts: NativeNotificationOptions) => void>();

let permissionPrimed = false;
let nativeActionListener: PluginListener | undefined;

async function ensurePermission(): Promise<void> {
  if (!isTauri() || permissionPrimed) return;
  try {
    let ok = await isPermissionGranted().catch(() => false);
    if (!ok) {
      await requestPermission().catch(() => undefined);
      ok = await isPermissionGranted().catch(() => false);
    }
    permissionPrimed = ok;
  } catch {
    permissionPrimed = false;
  }
}

async function snapshotToKv(): Promise<void> {
  const list = [...activeById.values()].map((a) => a.desc);
  await setSettingByKey(PENDING_SCHEDULES_KEY, JSON.stringify(list));
}

/** Parse HH:mm (24h). */
export function parseHourMinute(hourMinute: string): { hour: number; minute: number } {
  const [hRaw, mRaw] = hourMinute.trim().split(':');
  const hour = Number(hRaw);
  const minute = Number(mRaw);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) {
    throw new Error(`Invalid hourMinute "${hourMinute}"`);
  }
  return { hour, minute };
}

function combineDateAndHm(base: Date, hour: number, minute: number): Date {
  const d = new Date(base);
  d.setHours(hour, minute, 0, 0);
  return d;
}

function nextDailyTrigger(from: Date, hour: number, minute: number): Date {
  let d = combineDateAndHm(from, hour, minute);
  if (d.getTime() <= from.getTime()) {
    d = new Date(d.getTime() + 86400000);
  }
  return d;
}

function nextWeeklyTrigger(from: Date, scheduleWeekday: number, hour: number, minute: number): Date {
  const wantJs = scheduleWeekday - 1;
  const d = new Date(from);
  d.setHours(hour, minute, 0, 0);
  let add = (wantJs - d.getDay() + 7) % 7;
  if (add === 0 && d.getTime() <= from.getTime()) add = 7;
  d.setDate(d.getDate() + add);
  return d;
}

function cancelTimerOnly(id: number): void {
  const arm = activeById.get(id);
  if (!arm) return;
  clearTimeout(arm.timeoutId);
  activeById.delete(id);
}

function armSchedule(desc: PersistedSchedule): void {
  const delay = Math.max(0, new Date(desc.nextFireAtIso).getTime() - Date.now());
  const tid = setTimeout(() => void onTimerElapsed(desc.id).catch(console.error), delay);
  activeById.set(desc.id, { timeoutId: tid, desc });
}

async function persistAndMaybeSkip(): Promise<void> {
  if (!isTauri()) return;
  await snapshotToKv().catch((e) => console.warn('[notifications] persist skipped:', e));
}

/** Runs decision + toast; reprimes repeating schedules owned by this layer (see BEHAVIOR-N4 reroute notes). */
async function onTimerElapsed(id: number): Promise<void> {
  const armed = activeById.get(id);
  if (!armed) return;
  clearTimeout(armed.timeoutId);
  activeById.delete(id);
  await persistAndMaybeSkip();

  const { desc } = armed;
  let showedToast = false;
  try {
    const outcome = await dispatchTimedNotification(desc.id, desc.payload);
    showedToast = outcome.showedToast;
  } catch (e) {
    // fire_notification threw (e.g. OS permission denied). Log and fall through to re-arm
    // so the notification gets another chance at next occurrence rather than going silent forever.
    console.error('[notifications] dispatch threw — will re-arm for next occurrence:', e);
  }

  // Always re-arm repeating schedules regardless of whether this occurrence fired,
  // so a transient OS error doesn't permanently silence future notifications.
  if (!isTauri()) return;

  if (desc.mode === 'daily' && desc.hourMinute) {
    await scheduleDaily(desc.id, desc.hourMinute, desc.payload);
    return;
  }
  if (desc.mode === 'weekly' && desc.weekday !== undefined && desc.hourMinute) {
    await scheduleWeekly(desc.id, desc.weekday, desc.hourMinute, desc.payload);
    return;
  }
  // T6: Reschedule interval-based recurring check (e.g., surprise mission every 3 hours)
  // Always re-arm regardless of whether notification fired, so transient errors don't silence future occurrences.
  if (desc.mode === 'interval' && desc.intervalHours && desc.intervalHours > 0) {
    await scheduleRecurringInterval(desc.id, desc.intervalHours, desc.payload);
    return;
  }
  // BEHAVIOR-N4 one-shot recovery paths only re-arm when the notification actually fired.
  if (!showedToast) return;
  if (
    desc.mode === 'once' &&
    typeof desc.payload.hourMinute === 'string' &&
    isDailyPromotionKind(desc.payload.kind)
  ) {
    /** Quiet-hold finished as a one-shot; resume anchored daily recurrence (BEHAVIOR-N4 recovery). */
    await scheduleDaily(desc.id, desc.payload.hourMinute, desc.payload);
    return;
  }
  if (
    desc.mode === 'once' &&
    typeof desc.payload.hourMinute === 'string' &&
    typeof desc.payload.weekday === 'number' &&
    desc.payload.kind === 'weekly'
  ) {
    await scheduleWeekly(desc.id, desc.payload.weekday, desc.payload.hourMinute, desc.payload);
    return;
  }
}

function isDailyPromotionKind(k: unknown): k is NotificationKind {
  return k === 'pre_study' || k === 'streak' || k === 'goal';
}

/** BEHAVIOR-N6 — replace any prior timer attached to `id`. */
export async function cancel(id: NotificationId | number): Promise<void> {
  cancelTimerOnly(id);
  await persistAndMaybeSkip();
}

export async function cancelAll(): Promise<void> {
  for (const { timeoutId } of activeById.values()) clearTimeout(timeoutId);
  activeById.clear();
  await persistAndMaybeSkip();
}

export async function scheduleAt(id: NotificationId | number, when: Date, payload: NotificationPayload): Promise<void> {
  await cancel(id);
  await ensurePermission();
  if (!isTauri()) return;
  const desc: PersistedSchedule = {
    id: Number(id),
    mode: 'once',
    nextFireAtIso: when.toISOString(),
    payload
  };
  armSchedule(desc);
  await persistAndMaybeSkip();
}

export async function scheduleDaily(
  id: NotificationId | number,
  hourMinute: string,
  payload: NotificationPayload
): Promise<void> {
  await cancel(id);
  await ensurePermission();
  if (!isTauri()) return;
  const { hour, minute } = parseHourMinute(hourMinute);
  const when = nextDailyTrigger(new Date(), hour, minute);
  const desc: PersistedSchedule = {
    id: Number(id),
    mode: 'daily',
    nextFireAtIso: when.toISOString(),
    hourMinute,
    payload: { ...payload, hourMinute }
  };
  armSchedule(desc);
  await persistAndMaybeSkip();
}

export async function scheduleWeekly(
  id: NotificationId | number,
  scheduleWeekday: number,
  hourMinute: string,
  payload: NotificationPayload
): Promise<void> {
  await cancel(id);
  await ensurePermission();
  if (!isTauri()) return;
  const { hour, minute } = parseHourMinute(hourMinute);
  const when = nextWeeklyTrigger(new Date(), scheduleWeekday, hour, minute);
  const desc: PersistedSchedule = {
    id: Number(id),
    mode: 'weekly',
    nextFireAtIso: when.toISOString(),
    weekday: scheduleWeekday,
    hourMinute,
    payload: { ...payload, hourMinute, weekday: scheduleWeekday }
  };
  armSchedule(desc);
  await persistAndMaybeSkip();
}

/**
 * T6: Schedule a recurring notification at a fixed interval (e.g., every 3 hours).
 * Used for surprise mission check while the app window is open.
 * intervalHours: must be > 0 (e.g., 3, 6, 12, 24).
 * The dispatcher will reschedule the next occurrence when this fires.
 */
export async function scheduleRecurringInterval(
  id: NotificationId | number,
  intervalHours: number,
  payload: NotificationPayload
): Promise<void> {
  // Validate interval
  if (!Number.isFinite(intervalHours) || intervalHours <= 0) {
    console.error(`[notifications] invalid intervalHours=${intervalHours}`);
    return;
  }

  await cancel(id);
  await ensurePermission();
  if (!isTauri()) return;

  const when = new Date(Date.now() + intervalHours * 3600 * 1000); // now + intervalHours
  const desc: PersistedSchedule = {
    id: Number(id),
    mode: 'interval',
    nextFireAtIso: when.toISOString(),
    intervalHours,
    payload: { ...payload, intervalHours }
  };
  armSchedule(desc);
  await persistAndMaybeSkip();
}

/** Multiplexed subscription for `@tauri-apps/plugin-notification` action events. */
export function onSchedulerAction(cb: (opts: NativeNotificationOptions) => void): () => void {
  actionSubs.add(cb);
  void ensureNativeActionSubscriber();
  return () => {
    actionSubs.delete(cb);
  };
}

/** Public alias for multiplexed `@tauri-apps/plugin-notification` tap handling (F‑T‑2 surface). */
export const onAction = onSchedulerAction;

async function ensureNativeActionSubscriber(): Promise<void> {
  if (!isTauri() || nativeActionListener) return;
  nativeActionListener = await onNotificationNativeAction((n) => {
    for (const cb of actionSubs) {
      try {
        cb(n);
      } catch (e) {
        console.error('[notifications] onSchedulerAction subscriber error:', e);
      }
    }
  }).catch(() => undefined);
}

/**
 * Replay timers from KV (BEHAVIOR-N7 adjunct); superseded shortly after boot by rescheduleAllNotifications,
 * but survives edge cases before profile hydration.
 */
async function hydrateFromKv(): Promise<void> {
  if (!isTauri()) return;
  const row = await getSettingByKey(PENDING_SCHEDULES_KEY);
  if (!row?.value) return;

  let list: PersistedSchedule[];
  try {
    list = JSON.parse(row.value) as PersistedSchedule[];
  } catch {
    return;
  }
  if (!Array.isArray(list)) return;

  const now = Date.now();

  for (const raw of list) {
    if (!raw || typeof raw.id !== 'number') continue;
    const nextTs = new Date(raw.nextFireAtIso).getTime();
    /** Coalesce overdue repeating descriptors to the next real anchor instead of spraying immediate toasts on boot. */
    let normalized = raw;
    if (!Number.isFinite(nextTs)) continue;

    if (nextTs <= now && raw.mode === 'daily' && raw.hourMinute) {
      const hm = parseHourMinute(raw.hourMinute);
      normalized = {
        ...raw,
        nextFireAtIso: nextDailyTrigger(new Date(), hm.hour, hm.minute).toISOString()
      };
    } else if (nextTs <= now && raw.mode === 'weekly' && raw.weekday && raw.hourMinute) {
      const hm = parseHourMinute(raw.hourMinute);
      normalized = {
        ...raw,
        nextFireAtIso: nextWeeklyTrigger(new Date(), raw.weekday, hm.hour, hm.minute).toISOString()
      };
    } else if (nextTs <= now && raw.mode === 'once') {
      continue;
    }

    cancelTimerOnly(normalized.id);
    armSchedule(normalized);
  }
  await snapshotToKv();
}

export async function bootstrapSchedulerShell(): Promise<void> {
  if (!isTauri()) return;
  await ensurePermission();
  await ensureNativeActionSubscriber();
  await hydrateFromKv().catch(() => undefined);
}
