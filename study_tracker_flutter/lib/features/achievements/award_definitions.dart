import '../../domain/domain.dart';

enum AwardCategory { daily, weekly, monthly, allTime, secret }
enum AwardTier { bronze, silver, gold, legend }

class AwardCheckResult {
  final bool unlocked;
  final double progress;
  final int? completions;

  const AwardCheckResult({
    required this.unlocked,
    required this.progress,
    this.completions,
  });
}

typedef AwardCheck = AwardCheckResult Function(List<StudySession> sessions);

class AwardDefinition {
  final String id;
  final String title;
  final String description;
  final AwardCategory category;
  final AwardTier? tier;
  final bool repeatable;
  final String icon;
  final AwardCheck check;

  const AwardDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.repeatable,
    required this.icon,
    required this.check,
    this.tier,
  });
}

const int _activeDayMinutes = 120;

bool _isCompletedSession(StudySession s) {
  return s.durationMinutes > 0;
}

List<StudySession> _completed(List<StudySession> sessions) => sessions.where(_isCompletedSession).toList();

String _isoDay(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

List<StudySession> _forDay(List<StudySession> sessions, String day) {
  return sessions.where((s) => _isoDay(s.startAt) == day).toList();
}

int _totalMinutes(List<StudySession> sessions) => sessions.fold(0, (sum, s) => sum + s.durationMinutes);

List<StudySession> _weekSessions(List<StudySession> sessions, DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final day = d.weekday % 7;
  final saturday = d.subtract(Duration(days: day == 0 ? 1 : day + 1));
  final start = DateTime(saturday.year, saturday.month, saturday.day);
  final end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
  return sessions.where((s) => !s.startAt.isBefore(start) && !s.startAt.isAfter(end)).toList();
}

int _countActiveDays(List<StudySession> sessions) {
  final totals = <String, int>{};
  for (final s in sessions) {
    final day = _isoDay(s.startAt);
    totals[day] = (totals[day] ?? 0) + s.durationMinutes;
  }
  return totals.values.where((mins) => mins >= _activeDayMinutes).length;
}

List<StudySession> _monthSessions(List<StudySession> sessions, DateTime date) {
  return sessions.where((s) => s.startAt.year == date.year && s.startAt.month == date.month).toList();
}

int _longestStreakFromSessions(List<StudySession> sessions) {
  final days = sessions
      .where((s) => s.durationMinutes >= _activeDayMinutes)
      .map((s) => DateTime(s.startAt.year, s.startAt.month, s.startAt.day))
      .toSet()
      .toList()
    ..sort();

  if (days.isEmpty) return 0;
  var longest = 1;
  var current = 1;
  for (var i = 1; i < days.length; i++) {
    final diff = days[i].difference(days[i - 1]).inDays;
    if (diff == 1) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }
  }
  return longest;
}

final List<AwardDefinition> awardDefinitions = [
  AwardDefinition(
    id: 'daily_starter',
    title: 'Starter',
    description: 'Complete your first session today',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'sprout',
    check: (ss) {
      final completed = _completed(ss);
      final today = _isoDay(DateTime.now());
      final todayCount = _forDay(completed, today).length;
      final uniqueDays = completed.map((s) => _isoDay(s.startAt)).toSet().length;
      return AwardCheckResult(unlocked: todayCount >= 1, progress: todayCount >= 1 ? 1 : 0, completions: uniqueDays);
    },
  ),
  AwardDefinition(
    id: 'deep_work_daily',
    title: 'Deep Work',
    description: 'Study for 60 minutes today',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'target',
    check: (ss) {
      final mins = _totalMinutes(_forDay(_completed(ss), _isoDay(DateTime.now())));
      return AwardCheckResult(unlocked: mins >= 60, progress: (mins / 60).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'sprint_daily',
    title: 'Sprint',
    description: 'Study for 2 hours today',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'timer',
    check: (ss) {
      final mins = _totalMinutes(_forDay(_completed(ss), _isoDay(DateTime.now())));
      return AwardCheckResult(unlocked: mins >= 120, progress: (mins / 120).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'pomo_5_daily',
    title: 'Pomo-5',
    description: 'Complete 5 Pomodoro sessions today',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'clock',
    check: (ss) {
      final completed = _completed(ss);
      final today = _isoDay(DateTime.now());
      final countToday = _forDay(completed, today).where((s) => s.mode == StudySessionMode.pomodoro).length;
      final days = completed.map((s) => _isoDay(s.startAt)).toSet();
      var totalDays = 0;
      for (final day in days) {
        if (_forDay(completed, day).where((s) => s.mode == StudySessionMode.pomodoro).length >= 5) totalDays++;
      }
      return AwardCheckResult(unlocked: countToday >= 5, progress: (countToday / 5).clamp(0, 1), completions: totalDays);
    },
  ),
  AwardDefinition(
    id: 'midnight_oil',
    title: 'Midnight Oil',
    description: 'Study between 12 AM and 3 AM',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'moon',
    check: (ss) {
      final todaySessions = _forDay(_completed(ss), _isoDay(DateTime.now()));
      final ok = todaySessions.any((s) => s.startAt.hour >= 0 && s.startAt.hour < 3);
      return AwardCheckResult(unlocked: ok, progress: ok ? 1 : 0);
    },
  ),
  AwardDefinition(
    id: 'early_riser',
    title: 'Early Riser',
    description: 'Start a session before 7 AM',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'wb_sunny',
    check: (ss) {
      final todaySessions = _forDay(_completed(ss), _isoDay(DateTime.now()));
      final ok = todaySessions.any((s) => s.startAt.hour < 7);
      return AwardCheckResult(unlocked: ok, progress: ok ? 1 : 0);
    },
  ),
  AwardDefinition(
    id: 'subject_explorer',
    title: 'Subject Explorer',
    description: 'Study 2 different subjects today',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'book',
    check: (ss) {
      final subjects = _forDay(_completed(ss), _isoDay(DateTime.now()))
          .map((s) => s.subjectId)
          .whereType<int>()
          .toSet()
          .length;
      return AwardCheckResult(unlocked: subjects >= 2, progress: (subjects / 2).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'no_zero_day',
    title: 'No Zero Day',
    description: 'Log at least 1 minute of study',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'check_circle',
    check: (ss) {
      final mins = _totalMinutes(_forDay(_completed(ss), _isoDay(DateTime.now())));
      final ok = mins >= 1;
      return AwardCheckResult(unlocked: ok, progress: ok ? 1 : 0);
    },
  ),
  AwardDefinition(
    id: 'task_finisher',
    title: 'Task Finisher',
    description: 'Complete all tasks in a session',
    category: AwardCategory.daily,
    repeatable: true,
    icon: 'shield_check',
    check: (ss) {
      final today = _forDay(_completed(ss), _isoDay(DateTime.now()));
      final ok = today.any((s) => s.tasks.isNotEmpty && s.tasks.every((t) => t.completed));
      return AwardCheckResult(unlocked: ok, progress: ok ? 1 : 0);
    },
  ),
  AwardDefinition(
    id: 'perfect_week',
    title: 'Perfect Week',
    description: 'Study 2+ hours every day for a week',
    category: AwardCategory.weekly,
    repeatable: true,
    icon: 'star',
    check: (ss) {
      final days = _countActiveDays(_weekSessions(ss, DateTime.now()));
      return AwardCheckResult(unlocked: days >= 7, progress: (days / 7).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'weekend_warrior',
    title: 'Weekend Warrior',
    description: 'Study on both Thursday and Friday',
    category: AwardCategory.weekly,
    repeatable: true,
    icon: 'mountain',
    check: (ss) {
      final week = _weekSessions(ss, DateTime.now());
      final days = week
          .where((s) => s.durationMinutes >= _activeDayMinutes)
          .map((s) => s.startAt.weekday)
          .toSet();
      final hasThu = days.contains(DateTime.thursday);
      final hasFri = days.contains(DateTime.friday);
      final progress = (hasThu ? 0.5 : 0.0) + (hasFri ? 0.5 : 0.0);
      return AwardCheckResult(unlocked: hasThu && hasFri, progress: progress);
    },
  ),
  AwardDefinition(
    id: 'time_investor_weekly',
    title: 'Time Investor',
    description: 'Study for 10+ hours this week',
    category: AwardCategory.weekly,
    repeatable: true,
    icon: 'hourglass',
    check: (ss) {
      final mins = _totalMinutes(_weekSessions(ss, DateTime.now()));
      return AwardCheckResult(unlocked: mins >= 600, progress: (mins / 600).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'monthly_master',
    title: 'Monthly Master',
    description: '25 active days in one month',
    category: AwardCategory.monthly,
    repeatable: true,
    icon: 'crown',
    check: (ss) {
      final days = _countActiveDays(_monthSessions(_completed(ss), DateTime.now()));
      return AwardCheckResult(unlocked: days >= 25, progress: (days / 25).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'forty_hour_club',
    title: 'Forty Hour Club',
    description: '40+ hours in one month',
    category: AwardCategory.monthly,
    repeatable: true,
    icon: 'rocket',
    check: (ss) {
      final mins = _totalMinutes(_monthSessions(ss, DateTime.now()));
      return AwardCheckResult(unlocked: mins >= 2400, progress: (mins / 2400).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'sessions_bronze',
    title: 'Bronze Scholar',
    description: 'Study for 100 total hours',
    category: AwardCategory.allTime,
    tier: AwardTier.bronze,
    repeatable: false,
    icon: 'medal',
    check: (ss) {
      final hours = _totalMinutes(ss) / 60.0;
      return AwardCheckResult(unlocked: hours >= 100, progress: (hours / 100).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'sessions_silver',
    title: 'Silver Scholar',
    description: 'Study for 300 total hours',
    category: AwardCategory.allTime,
    tier: AwardTier.silver,
    repeatable: false,
    icon: 'medal',
    check: (ss) {
      final hours = _totalMinutes(ss) / 60.0;
      return AwardCheckResult(unlocked: hours >= 300, progress: (hours / 300).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'sessions_gold',
    title: 'Gold Scholar',
    description: 'Study for 500 total hours',
    category: AwardCategory.allTime,
    tier: AwardTier.gold,
    repeatable: false,
    icon: 'medal',
    check: (ss) {
      final hours = _totalMinutes(ss) / 60.0;
      return AwardCheckResult(unlocked: hours >= 500, progress: (hours / 500).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'sessions_legend',
    title: 'Legendary Scholar',
    description: 'Study for 1000 total hours',
    category: AwardCategory.allTime,
    tier: AwardTier.legend,
    repeatable: false,
    icon: 'crown',
    check: (ss) {
      final hours = _totalMinutes(ss) / 60.0;
      return AwardCheckResult(unlocked: hours >= 1000, progress: (hours / 1000).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'hours_bronze',
    title: '100 Hour Milestone',
    description: 'Study for 100 total hours',
    category: AwardCategory.allTime,
    tier: AwardTier.bronze,
    repeatable: false,
    icon: 'clock',
    check: (ss) {
      final mins = _totalMinutes(ss);
      return AwardCheckResult(unlocked: mins >= 6000, progress: (mins / 6000).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'streak_week',
    title: 'Steady Rhythm',
    description: '7-day study streak with 2+ hour days',
    category: AwardCategory.allTime,
    tier: AwardTier.bronze,
    repeatable: false,
    icon: 'local_fire_department',
    check: (ss) {
      final streak = _longestStreakFromSessions(_completed(ss));
      return AwardCheckResult(unlocked: streak >= 7, progress: (streak / 7).clamp(0, 1));
    },
  ),
  AwardDefinition(
    id: 'phoenix',
    title: 'Phoenix',
    description: 'Resume study after a 3+ day gap',
    category: AwardCategory.secret,
    repeatable: true,
    icon: 'sparkles',
    check: (ss) {
      if (ss.length < 2) return const AwardCheckResult(unlocked: false, progress: 0);
      final sorted = ss.map((s) => s.startAt.millisecondsSinceEpoch).toList()..sort();
      var found = false;
      for (var i = 1; i < sorted.length; i++) {
        final diffDays = (sorted[i] - sorted[i - 1]) / (1000 * 60 * 60 * 24);
        if (diffDays >= 3) {
          found = true;
          break;
        }
      }
      return AwardCheckResult(unlocked: found, progress: found ? 1 : 0);
    },
  ),
  AwardDefinition(
    id: 'triple_threat',
    title: 'Triple Threat',
    description: 'Session + Pomodoro + 1h focus in one day',
    category: AwardCategory.secret,
    repeatable: true,
    icon: 'bolt',
    check: (ss) {
      final days = ss.map((s) => _isoDay(s.startAt)).toSet();
      var ok = false;
      for (final day in days) {
        final daily = _forDay(ss, day);
        final hasPomo = daily.any((s) => s.mode == StudySessionMode.pomodoro);
        final hasLong = daily.any((s) => s.mode == StudySessionMode.longSession);
        final mins = _totalMinutes(daily);
        if (hasPomo && hasLong && mins >= 60) {
          ok = true;
          break;
        }
      }
      return AwardCheckResult(unlocked: ok, progress: ok ? 1 : 0);
    },
  ),
  AwardDefinition(
    id: 'overkill',
    title: 'Overkill',
    description: 'Study 5+ hours in a single day',
    category: AwardCategory.secret,
    repeatable: true,
    icon: 'zap',
    check: (ss) {
      final days = ss.map((s) => _isoDay(s.startAt)).toSet();
      var ok = false;
      for (final day in days) {
        if (_totalMinutes(_forDay(ss, day)) >= 300) {
          ok = true;
          break;
        }
      }
      return AwardCheckResult(unlocked: ok, progress: ok ? 1 : 0);
    },
  ),
];
