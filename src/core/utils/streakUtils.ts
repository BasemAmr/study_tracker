/** Streak calculation utilities */

import { startOfDay, isSameDay } from './dateUtils';

export type StreakResult = {
  currentStreak: number;
  longestStreak: number;
};

/**
 * Calculate current and longest streak from a list of study dates.
 * A day counts as a study day if study time meets the minimum threshold.
 * Dates must be sorted in ascending order.
 */
export function calculateStreaks(
  studyDates: Date[],
  minimumMinutesPerDay: number = 1
): StreakResult {
  if (studyDates.length === 0) {
    return { currentStreak: 0, longestStreak: 0 };
  }

  // Deduplicate to unique days
  const uniqueDays: Date[] = [];
  for (const date of studyDates) {
    const day = startOfDay(date);
    if (uniqueDays.length === 0 || !isSameDay(uniqueDays[uniqueDays.length - 1], day)) {
      uniqueDays.push(day);
    }
  }

  let longestStreak = 1;
  let currentRun = 1;

  for (let i = 1; i < uniqueDays.length; i++) {
    const prev = uniqueDays[i - 1];
    const curr = uniqueDays[i];
    const diffMs = curr.getTime() - prev.getTime();
    const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 1) {
      currentRun++;
    } else {
      currentRun = 1;
    }

    longestStreak = Math.max(longestStreak, currentRun);
  }

  // Current streak: check if the last study day is today or yesterday
  const today = startOfDay(new Date());
  const lastStudyDay = uniqueDays[uniqueDays.length - 1];
  const daysSinceLastStudy = Math.round(
    (today.getTime() - lastStudyDay.getTime()) / (1000 * 60 * 60 * 24)
  );

  let currentStreak = 0;
  if (daysSinceLastStudy <= 1) {
    currentStreak = 1;
    for (let i = uniqueDays.length - 2; i >= 0; i--) {
      const prev = uniqueDays[i];
      const curr = uniqueDays[i + 1];
      const diffMs = curr.getTime() - prev.getTime();
      const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));

      if (diffDays === 1) {
        currentStreak++;
      } else {
        break;
      }
    }
  }

  return { currentStreak, longestStreak };
}

/**
 * Build a map of date-string → total minutes from session data.
 * Uses LOCAL calendar date to match what the user sees (not UTC).
 */
export function buildDailyMinutesMap(
  sessions: Array<{ startAt: string; durationMinutes: number }>
): Map<string, number> {
  const map = new Map<string, number>();

  for (const session of sessions) {
    // Parse the stored timestamp and convert to local date string YYYY-MM-DD
    const d = new Date(session.startAt);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const dateKey = `${year}-${month}-${day}`;
    map.set(dateKey, (map.get(dateKey) ?? 0) + session.durationMinutes);
  }

  return map;
}
