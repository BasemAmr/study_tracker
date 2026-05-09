import {
  Trophy, Sprout, BookOpen, GraduationCap, Medal, Award, Crown,
  Clock, Timer, Hourglass, Star, TrendingUp, Flame, CalendarDays,
  CalendarCheck, Zap, Brain, Sunrise, Moon, Target, Coffee,
  CheckCircle2, Lightbulb, ZapOff, Anchor, Mountain, Rocket,
  Search, PenTool, Layout, Layers, ShieldCheck, Heart, Sparkles,
  ZapIcon
} from 'lucide-svelte';
import type { StudySession } from '../../core/domain';
import { calculateStreaks } from '../../core/utils/streakUtils';

export type AchievementCategory = 'daily' | 'weekly' | 'monthly' | 'all_time' | 'repetitive' | 'secret';
export type AchievementTier = 'bronze' | 'silver' | 'gold' | 'legend';

export interface AchievementDefinition {
  id: string;
  title: string;
  description: string;
  category: AchievementCategory;
  tier?: AchievementTier;
  repeatable: boolean;
  icon: any;
  check: (sessions: StudySession[]) => {
    unlocked: boolean;
    progress: number; // 0 to 1
    completions?: number; // for repeatable
  };
}

// Helpers
const totalMinutes = (ss: StudySession[]) => ss.reduce((sum, s) => sum + s.durationMinutes, 0);
const activeDayMinutes = 120;

const isCompletedSession = (session: StudySession) => {
  if (session.mode === 'pomodoro') {
    return session.durationMinutes >= 25;
  }

  if (session.mode === 'long_session' || session.mode === 'manual') {
    return session.durationMinutes >= 30;
  }

  return session.durationMinutes > 0;
};

const getCompletedSessions = (sessions: StudySession[]) => sessions.filter(isCompletedSession);

const getLocalISO = (d: Date) => {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const getSessionsForDay = (ss: StudySession[], dateStr: string) => {
  return ss.filter(s => s.startAt.startsWith(dateStr));
};

const getSessionsForWeek = (ss: StudySession[], date: Date) => {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -1 : 6);
  const saturday = new Date(d.setDate(diff));
  saturday.setHours(0, 0, 0, 0);
  const friday = new Date(saturday);
  friday.setDate(friday.getDate() + 6);
  friday.setHours(23, 59, 59, 999);

  return ss.filter(s => {
    const sd = new Date(s.startAt);
    return sd >= saturday && sd <= friday;
  });
};

const countActiveDays = (sessions: StudySession[]) => {
  const totals = new Map<string, number>();

  for (const session of sessions) {
    const day = getLocalISO(new Date(session.startAt));
    totals.set(day, (totals.get(day) ?? 0) + session.durationMinutes);
  }

  return Array.from(totals.values()).filter((minutes) => minutes >= activeDayMinutes).length;
};

const countActiveDaysInWeek = (sessions: StudySession[], date: Date) => countActiveDays(getSessionsForWeek(sessions, date));

const isWeekendDay = (date: Date) => {
  const day = date.getDay();
  return day === 4 || day === 5;
};

const getSessionsForMonth = (ss: StudySession[], date: Date) => {
  const month = date.getMonth();
  const year = date.getFullYear();
  return ss.filter(s => {
    const sd = new Date(s.startAt);
    return sd.getMonth() === month && sd.getFullYear() === year;
  });
};

export const badgeDefinitions: AchievementDefinition[] = [
  // ─── DAILY LOOPS ──────────────────────────────────────────
  {
    id: 'daily_starter',
    title: 'Starter',
    description: 'Complete your first session today',
    category: 'daily',
    repeatable: true,
    icon: Sprout,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const completed = getCompletedSessions(ss);
      const daily = getSessionsForDay(completed, today);
      const uniqueDays = new Set(completed.map(s => getLocalISO(new Date(s.startAt))));
      return { 
        unlocked: daily.length >= 1, 
        progress: daily.length >= 1 ? 1 : 0,
        completions: uniqueDays.size
      };
    }
  },
  {
    id: 'deep_work_daily',
    title: 'Deep Work',
    description: 'Study for 60 minutes today',
    category: 'daily',
    repeatable: true,
    icon: Target,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const mins = totalMinutes(getSessionsForDay(getCompletedSessions(ss), today));
      return { unlocked: mins >= 60, progress: Math.min(mins / 60, 1) };
    }
  },
  {
    id: 'sprint_daily',
    title: 'Sprint',
    description: 'Study for 2 hours today',
    category: 'daily',
    repeatable: true,
    icon: Timer,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const mins = totalMinutes(getSessionsForDay(getCompletedSessions(ss), today));
      return { unlocked: mins >= 120, progress: Math.min(mins / 120, 1) };
    }
  },
  {
    id: 'pomo_5_daily',
    title: 'Pomo-5',
    description: 'Complete 5 Pomodoro sessions today',
    category: 'daily',
    repeatable: true,
    icon: Clock,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const completed = getCompletedSessions(ss);
      const countToday = getSessionsForDay(completed, today).filter(s => s.mode === 'pomodoro').length;
      const days = new Set(completed.map(s => getLocalISO(new Date(s.startAt))));
      let totalDays = 0;
      days.forEach(d => { if (getSessionsForDay(completed, d).filter(s => s.mode === 'pomodoro').length >= 5) totalDays++; });
      return { unlocked: countToday >= 5, progress: Math.min(countToday / 5, 1), completions: totalDays };
    }
  },
  {
    id: 'midnight_oil',
    title: 'Midnight Oil',
    description: 'Study between 12 AM and 3 AM',
    category: 'daily',
    repeatable: true,
    icon: Moon,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const daily = getSessionsForDay(getCompletedSessions(ss), today);
      const isNight = daily.some(s => {
        const hour = new Date(s.startAt).getHours();
        return hour >= 0 && hour < 3;
      });
      return { unlocked: isNight, progress: isNight ? 1 : 0 };
    }
  },
  {
    id: 'early_riser',
    title: 'Early Riser',
    description: 'Start a session before 7 AM',
    category: 'daily',
    repeatable: true,
    icon: Sunrise,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const daily = getSessionsForDay(getCompletedSessions(ss), today);
      const isEarly = daily.some(s => new Date(s.startAt).getHours() < 7);
      return { unlocked: isEarly, progress: isEarly ? 1 : 0 };
    }
  },
  {
    id: 'subject_explorer',
    title: 'Subject Explorer',
    description: 'Study 2 different subjects today',
    category: 'daily',
    repeatable: true,
    icon: BookOpen,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const subjects = new Set(getSessionsForDay(getCompletedSessions(ss), today).map(s => s.subjectId).filter(Boolean));
      return { unlocked: subjects.size >= 2, progress: Math.min(subjects.size / 2, 1) };
    }
  },
  {
    id: 'no_zero_day',
    title: 'No Zero Day',
    description: 'Log at least 1 minute of study',
    category: 'daily',
    repeatable: true,
    icon: CheckCircle2,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const mins = totalMinutes(getSessionsForDay(getCompletedSessions(ss), today));
      return { unlocked: mins >= 1, progress: mins >= 1 ? 1 : 0 };
    }
  },
  {
    id: 'task_finisher',
    title: 'Task Finisher',
    description: 'Complete all tasks in a session',
    category: 'daily',
    repeatable: true,
    icon: ShieldCheck,
    check: (ss) => {
      const today = getLocalISO(new Date());
      const daily = getSessionsForDay(getCompletedSessions(ss), today);
      const allDone = daily.some(s => s.tasks && s.tasks.length > 0 && s.tasks.every(t => t.completed));
      return { unlocked: allDone, progress: allDone ? 1 : 0 };
    }
  },

  // ─── WEEKLY QUESTS ──────────────────────────────────────────
  {
    id: 'perfect_week',
    title: 'Perfect Week',
    description: 'Study 2+ hours every day for a week',
    category: 'weekly',
    repeatable: true,
    icon: Star,
    check: (ss) => {
      const week = getSessionsForWeek(ss, new Date());
      const days = countActiveDays(week);
      return { unlocked: days >= 7, progress: Math.min(days / 7, 1) };
    }
  },
  {
    id: 'weekend_warrior',
    title: 'Weekend Warrior',
    description: 'Study on both Thursday and Friday',
    category: 'weekly',
    repeatable: true,
    icon: Mountain,
    check: (ss) => {
      const week = getSessionsForWeek(ss, new Date());
      const days = new Set(
        week
          .filter((session) => session.durationMinutes >= activeDayMinutes)
          .map((session) => new Date(session.startAt).getDay())
      );
      const ok = days.has(4) && days.has(5);
      return { unlocked: ok, progress: (days.has(4) ? 0.5 : 0) + (days.has(5) ? 0.5 : 0) };
    }
  },
  {
    id: 'time_investor_weekly',
    title: 'Time Investor',
    description: 'Study for 10+ hours this week',
    category: 'weekly',
    repeatable: true,
    icon: Timer,
    check: (ss) => {
      const week = getSessionsForWeek(ss, new Date());
      const mins = totalMinutes(week);
      return { unlocked: mins >= 600, progress: Math.min(mins / 600, 1) };
    }
  },

  // ─── MONTHLY MILESTONES ─────────────────────────────────────
  {
    id: 'monthly_master',
    title: 'Monthly Master',
    description: '25 active days in one month',
    category: 'monthly',
    repeatable: true,
    icon: Crown,
    check: (ss) => {
      const month = getSessionsForMonth(getCompletedSessions(ss), new Date());
      const days = countActiveDays(month);
      return { unlocked: days >= 25, progress: Math.min(days / 25, 1) };
    }
  },
  {
    id: 'forty_hour_club',
    title: 'Forty Hour Club',
    description: '40+ hours in one month',
    category: 'monthly',
    repeatable: true,
    icon: Rocket,
    check: (ss) => {
      const month = getSessionsForMonth(ss, new Date());
      const mins = totalMinutes(month);
      return { unlocked: mins >= 2400, progress: Math.min(mins / 2400, 1) };
    }
  },

  // ─── LIFETIME / TIERS ───────────────────────────────────────
  // SESSIONS
  {
    id: 'sessions_bronze',
    title: 'Bronze Scholar',
    description: 'Study for 100 total hours',
    category: 'all_time',
    tier: 'bronze',
    repeatable: false,
    icon: Medal,
    check: (ss) => {
      const hours = totalMinutes(ss) / 60;
      return { unlocked: hours >= 100, progress: Math.min(hours / 100, 1) };
    }
  },
  {
    id: 'sessions_silver',
    title: 'Silver Scholar',
    description: 'Study for 300 total hours',
    category: 'all_time',
    tier: 'silver',
    repeatable: false,
    icon: Medal,
    check: (ss) => {
      const hours = totalMinutes(ss) / 60;
      return { unlocked: hours >= 300, progress: Math.min(hours / 300, 1) };
    }
  },
  {
    id: 'sessions_gold',
    title: 'Gold Scholar',
    description: 'Study for 500 total hours',
    category: 'all_time',
    tier: 'gold',
    repeatable: false,
    icon: Medal,
    check: (ss) => {
      const hours = totalMinutes(ss) / 60;
      return { unlocked: hours >= 500, progress: Math.min(hours / 500, 1) };
    }
  },
  {
    id: 'sessions_legend',
    title: 'Legendary Scholar',
    description: 'Study for 1000 total hours',
    category: 'all_time',
    tier: 'legend',
    repeatable: false,
    icon: Crown,
    check: (ss) => {
      const hours = totalMinutes(ss) / 60;
      return { unlocked: hours >= 1000, progress: Math.min(hours / 1000, 1) };
    }
  },

  // HOURS
  {
    id: 'hours_bronze',
    title: '100 Hour Milestone',
    description: 'Study for 100 total hours',
    category: 'all_time',
    tier: 'bronze',
    repeatable: false,
    icon: Clock,
    check: (ss) => {
      const mins = totalMinutes(ss);
      return { unlocked: mins >= 6000, progress: Math.min(mins / 6000, 1) };
    }
  },

  // STREAKS
  {
    id: 'streak_week',
    title: 'Steady Rhythm',
    description: '7-day study streak with 2+ hour days',
    category: 'all_time',
    tier: 'bronze',
    repeatable: false,
    icon: Flame,
    check: (ss) => {
      const dates = getCompletedSessions(ss)
        .filter((session) => session.durationMinutes >= activeDayMinutes)
        .map(s => new Date(s.startAt))
        .sort((a, b) => a.getTime() - b.getTime());
      const { longestStreak } = calculateStreaks(dates);
      return { unlocked: longestStreak >= 7, progress: Math.min(longestStreak / 7, 1) };
    }
  },

  // ─── BEHAVIORAL / SECRETS ──────────────────────────────────
  {
    id: 'phoenix',
    title: 'Phoenix',
    description: 'Resume study after a 3+ day gap',
    category: 'secret',
    repeatable: true,
    icon: Sparkles,
    check: (ss) => {
      if (ss.length < 2) return { unlocked: false, progress: 0 };
      const sorted = ss.map(s => new Date(s.startAt).getTime()).sort((a, b) => a - b);
      let found = false;
      for (let i = 1; i < sorted.length; i++) {
        const diff = (sorted[i] - sorted[i - 1]) / (1000 * 60 * 60 * 24);
        if (diff >= 3) { found = true; break; }
      }
      return { unlocked: found, progress: found ? 1 : 0 };
    }
  },
  {
    id: 'triple_threat',
    title: 'Triple Threat',
    description: 'Session + Pomodoro + 1h focus in one day',
    category: 'secret',
    repeatable: true,
    icon: Zap,
    check: (ss) => {
      const days = new Set(ss.map(s => getLocalISO(new Date(s.startAt))));
      let ok = false;
      for (const day of days) {
        const daily = getSessionsForDay(ss, day);
        const hasPomo = daily.some(s => s.mode === 'pomodoro');
        const hasLong = daily.some(s => s.mode === 'long_session');
        const mins = totalMinutes(daily);
        if (hasPomo && hasLong && mins >= 60) { ok = true; break; }
      }
      return { unlocked: ok, progress: ok ? 1 : 0 };
    }
  },
  {
    id: 'overkill',
    title: 'Overkill',
    description: 'Study 5+ hours in a single day',
    category: 'secret',
    repeatable: true,
    icon: ZapIcon,
    check: (ss) => {
      const days = new Set(ss.map(s => getLocalISO(new Date(s.startAt))));
      let ok = false;
      for (const day of days) {
        if (totalMinutes(getSessionsForDay(ss, day)) >= 300) { ok = true; break; }
      }
      return { unlocked: ok, progress: ok ? 1 : 0 };
    }
  }
];
