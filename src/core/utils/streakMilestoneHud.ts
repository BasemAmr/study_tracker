/**
 * Gamified streak tier + next checkpoint for dashboard status hub.
 * Milestones ladder matches Flutter `streak_milestone_hud.dart`.
 */
const TARGETS = [3, 7, 14, 30, 90] as const;

function checkpointFlavor(days: number): string {
  switch (days) {
    case 3:
      return 'Kindling crest';
    case 7:
      return 'Scholar pulse';
    case 14:
      return 'Rhythm crest';
    case 30:
      return 'Month forge';
    case 90:
      return 'Season legend';
    default:
      return 'Milestone';
  }
}

function tierTitleForStreak(streak: number): string {
  if (streak <= 0) return 'Cold start';
  if (streak < 3) return 'First spark';
  if (streak < 7) return 'Kindling climb';
  if (streak < 14) return 'Scholar pulse';
  if (streak < 30) return 'Deep rhythm';
  if (streak < 90) return 'Marathon mind';
  return 'Hall of legends';
}

function nextTarget(streak: number): number | null {
  for (const t of TARGETS) {
    if (streak < t) return t;
  }
  return null;
}

function prevTarget(streak: number): number {
  let p = 0;
  for (const t of TARGETS) {
    if (streak >= t) p = t;
    else break;
  }
  return p;
}

export interface StreakMilestoneHudModel {
  tierTitle: string;
  chaseLine: string;
  /** 0–1 toward next milestone, or 1 when at max ladder */
  progress01: number;
  nextCheckpointDays: number | null;
  daysToNext: number | null;
  personalBest: number;
}

export function computeStreakMilestoneHud(
  currentStreak: number,
  personalBest: number
): StreakMilestoneHudModel {
  const tierTitle = tierTitleForStreak(currentStreak);
  const next = nextTarget(currentStreak);
  const prev = prevTarget(currentStreak);

  let progress01: number;
  if (next === null) {
    progress01 = 1;
  } else {
    progress01 =
      next === prev ? 0 : Math.min(1, Math.max(0, (currentStreak - prev) / (next - prev)));
  }

  let chaseLine: string;
  if (next === null) {
    chaseLine =
      personalBest >= 90
        ? `Personal peak: ${personalBest}-day runway. Rest, then forge a new saga.`
        : `You've cleared every crest on the ladder. Aim for ${Math.max(currentStreak, personalBest)}+ as your encore.`;
  } else if (currentStreak <= 0) {
    chaseLine = `Study today — your first crest is ${checkpointFlavor(next)} at ${next} days in a row.`;
  } else {
    const delta = next - currentStreak;
    chaseLine =
      delta <= 0
        ? `${checkpointFlavor(next)} is in reach — log today to cement it.`
        : `${delta} more day${delta === 1 ? '' : 's'} to ${checkpointFlavor(next)} (${next}-day crest).`;
  }

  const daysToNext = next === null ? null : Math.max(0, next - currentStreak);

  return {
    tierTitle,
    chaseLine,
    progress01,
    nextCheckpointDays: next,
    daysToNext,
    personalBest
  };
}
