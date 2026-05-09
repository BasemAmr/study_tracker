/** Analytics computation utilities */

import type { StudySession } from '../domain';
import { startOfDay, startOfWeek, dateRange, getHour } from './dateUtils';

export type DailyTotal = {
  date: string;
  minutes: number;
};

export type WeeklyTotal = {
  weekStart: string;
  minutes: number;
  sessionCount: number;
};

export type SubjectBreakdown = {
  name: string;
  minutes: number;
  sessionCount: number;
  percentage: number;
};

export type HourlyDistribution = {
  hour: number;
  minutes: number;
};

export type MoodDistribution = {
  mood: string;
  count: number;
  percentage: number;
};

/**
 * Compute daily totals for a date range.
 */
export function computeDailyTotals(
  sessions: StudySession[],
  startDate: Date,
  endDate: Date
): DailyTotal[] {
  const map = new Map<string, number>();
  const dates = dateRange(startDate, endDate);

  for (const d of dates) {
    map.set(d.toISOString().split('T')[0], 0);
  }

  for (const session of sessions) {
    const dateKey = session.startAt.split('T')[0];
    if (map.has(dateKey)) {
      map.set(dateKey, (map.get(dateKey) ?? 0) + session.durationMinutes);
    }
  }

  return Array.from(map.entries())
    .map(([date, minutes]) => ({ date, minutes }))
    .sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Compute weekly totals for a given number of weeks back.
 */
export function computeWeeklyTotals(
  sessions: StudySession[],
  weeksBack: number = 12
): WeeklyTotal[] {
  const now = new Date();
  const weeks: WeeklyTotal[] = [];

  for (let i = weeksBack - 1; i >= 0; i--) {
    const weekStart = startOfWeek(new Date(now.getTime() - i * 7 * 24 * 60 * 60 * 1000));
    const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000 - 1);

    const weekSessions = sessions.filter((s) => {
      const d = new Date(s.startAt);
      return d >= weekStart && d <= weekEnd;
    });

    weeks.push({
      weekStart: weekStart.toISOString().split('T')[0],
      minutes: weekSessions.reduce((sum, s) => sum + s.durationMinutes, 0),
      sessionCount: weekSessions.length
    });
  }

  return weeks;
}

/**
 * Compute subject breakdown with percentages.
 */
export function computeSubjectBreakdown(sessions: StudySession[]): SubjectBreakdown[] {
  const map = new Map<string, { minutes: number; count: number }>();
  let totalMinutes = 0;

  for (const session of sessions) {
    const name = session.subjectName ?? 'Uncategorized';
    const existing = map.get(name) ?? { minutes: 0, count: 0 };
    existing.minutes += session.durationMinutes;
    existing.count += 1;
    map.set(name, existing);
    totalMinutes += session.durationMinutes;
  }

  return Array.from(map.entries())
    .map(([name, data]) => ({
      name,
      minutes: data.minutes,
      sessionCount: data.count,
      percentage: totalMinutes > 0 ? Math.round((data.minutes / totalMinutes) * 100) : 0
    }))
    .sort((a, b) => b.minutes - a.minutes);
}

/**
 * Compute hourly distribution of study activity.
 */
export function computeHourlyDistribution(sessions: StudySession[]): HourlyDistribution[] {
  const hours: number[] = new Array(24).fill(0);

  for (const session of sessions) {
    const hour = getHour(session.startAt);
    hours[hour] += session.durationMinutes;
  }

  return hours.map((minutes, hour) => ({ hour, minutes }));
}

/**
 * Find peak study hour.
 */
export function findPeakHour(sessions: StudySession[]): number {
  const distribution = computeHourlyDistribution(sessions);
  let peakHour = 0;
  let maxMinutes = 0;

  for (const { hour, minutes } of distribution) {
    if (minutes > maxMinutes) {
      maxMinutes = minutes;
      peakHour = hour;
    }
  }

  return peakHour;
}

/**
 * Compute mood distribution.
 */
export function computeMoodDistribution(sessions: StudySession[]): MoodDistribution[] {
  const map = new Map<string, number>();
  let total = 0;

  for (const session of sessions) {
    if (session.mood) {
      map.set(session.mood, (map.get(session.mood) ?? 0) + 1);
      total++;
    }
  }

  return Array.from(map.entries())
    .map(([mood, count]) => ({
      mood,
      count,
      percentage: total > 0 ? Math.round((count / total) * 100) : 0
    }))
    .sort((a, b) => b.count - a.count);
}

/**
 * Compute rolling average of daily study time.
 */
export function computeRollingAverage(dailyTotals: DailyTotal[], windowDays: number): number {
  if (dailyTotals.length === 0) return 0;

  const recent = dailyTotals.slice(-windowDays);
  const totalMinutes = recent.reduce((sum, d) => sum + d.minutes, 0);
  return Math.round(totalMinutes / recent.length);
}

/**
 * Compute study/break ratio.
 */
export function computeStudyBreakRatio(sessions: StudySession[]): {
  studyMinutes: number;
  breakMinutes: number;
  ratio: string;
} {
  const studyMinutes = sessions.reduce((sum, s) => sum + s.durationMinutes, 0);
  const breakMinutes = sessions.reduce((sum, s) => sum + (s.breakMinutes ?? 0), 0);

  const ratio =
    breakMinutes > 0
      ? `${(studyMinutes / breakMinutes).toFixed(1)}:1`
      : studyMinutes > 0
        ? '∞:1'
        : '0:0';

  return { studyMinutes, breakMinutes, ratio };
}
