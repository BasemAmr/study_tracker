/** BEHAVIOR-N6 — stable notification ids (cancel same id before rescheduling). */
export enum NotificationId {
  PreStudy = 1001,
  Streak = 1002,
  Weekly = 1003,
  Goal = 1004,
  Reengagement3 = 1005,
  Reengagement7 = 1006,
  SurpriseCheck = 1007,           // Internal: triggers the tick to check/renew surprise mission
  SurpriseAvailable = 1008        // User-facing: "New surprise mission available"
}

/** Canonical classifier stored in payloads and routed through the decision engine. */
export type NotificationKind =
  | 'pre_study'
  | 'streak'
  | 'weekly'
  | 'goal'
  | 'reengage_3'
  | 'reengage_7';

export type NotificationPayload = Record<string, unknown>;
