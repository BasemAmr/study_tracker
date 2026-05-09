import '../../domain/domain.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Analytics computation (ported from analyticsUtils.ts)
// ─────────────────────────────────────────────────────────────────────────────

import 'utils.dart';

class DailyTotal {
  final String date; // YYYY-MM-DD
  final int minutes;
  const DailyTotal({required this.date, required this.minutes});
}

class WeeklyTotal {
  final String weekStart;
  final int minutes;
  final int sessionCount;
  const WeeklyTotal({
    required this.weekStart,
    required this.minutes,
    required this.sessionCount,
  });
}

class SubjectBreakdown {
  final String name;
  final int minutes;
  final int sessionCount;
  final int percentage;
  const SubjectBreakdown({
    required this.name,
    required this.minutes,
    required this.sessionCount,
    required this.percentage,
  });
}

class HourlyDistribution {
  final int hour;
  final int minutes;
  const HourlyDistribution({required this.hour, required this.minutes});
}

class MoodDistribution {
  final String mood;
  final int count;
  final int percentage;
  const MoodDistribution({
    required this.mood,
    required this.count,
    required this.percentage,
  });
}

class StudyBreakRatio {
  final int studyMinutes;
  final int breakMinutes;
  final String ratio;
  const StudyBreakRatio({
    required this.studyMinutes,
    required this.breakMinutes,
    required this.ratio,
  });
}

/// Compute daily totals filling in zero-days for the full range.
List<DailyTotal> computeDailyTotals(
  List<StudySession> sessions,
  DateTime startDate,
  DateTime endDate,
) {
  final map = <String, int>{};
  for (final d in dateRange(startDate, endDate)) {
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    map[key] = 0;
  }
  for (final s in sessions) {
    final d = s.startAt;
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (map.containsKey(key)) {
      map[key] = map[key]! + s.durationMinutes;
    }
  }
  return map.entries
      .map((e) => DailyTotal(date: e.key, minutes: e.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

/// Compute weekly totals for N weeks back.
List<WeeklyTotal> computeWeeklyTotals(
    List<StudySession> sessions, int weeksBack) {
  final now = DateTime.now();
  final result = <WeeklyTotal>[];

  for (int i = weeksBack - 1; i >= 0; i--) {
    final ws = startOfWeek(now.subtract(Duration(days: i * 7)));
    final we = ws.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
    final filtered = sessions
        .where((s) => !s.startAt.isBefore(ws) && !s.startAt.isAfter(we))
        .toList();
    result.add(WeeklyTotal(
      weekStart:
          '${ws.year}-${ws.month.toString().padLeft(2, '0')}-${ws.day.toString().padLeft(2, '0')}',
      minutes: filtered.fold(0, (sum, s) => sum + s.durationMinutes),
      sessionCount: filtered.length,
    ));
  }
  return result;
}

/// Compute subject breakdown with percentages.
List<SubjectBreakdown> computeSubjectBreakdown(List<StudySession> sessions) {
  final map = <String, (int minutes, int count)>{};
  int total = 0;
  for (final s in sessions) {
    final name = s.subjectName ?? 'Uncategorized';
    final prev = map[name] ?? (0, 0);
    map[name] = (prev.$1 + s.durationMinutes, prev.$2 + 1);
    total += s.durationMinutes;
  }
  return map.entries
      .map((e) => SubjectBreakdown(
            name: e.key,
            minutes: e.value.$1,
            sessionCount: e.value.$2,
            percentage:
                total > 0 ? ((e.value.$1 / total) * 100).round() : 0,
          ))
      .toList()
    ..sort((a, b) => b.minutes.compareTo(a.minutes));
}

/// Compute 24-hour distribution.
List<HourlyDistribution> computeHourlyDistribution(
    List<StudySession> sessions) {
  final hours = List<int>.filled(24, 0);
  for (final s in sessions) {
    hours[s.startAt.hour] += s.durationMinutes;
  }
  return List.generate(
      24, (i) => HourlyDistribution(hour: i, minutes: hours[i]));
}

/// Compute mood distribution.
List<MoodDistribution> computeMoodDistribution(List<StudySession> sessions) {
  final map = <String, int>{};
  int total = 0;
  for (final s in sessions) {
    if (s.mood != null && s.mood!.isNotEmpty) {
      map[s.mood!] = (map[s.mood!] ?? 0) + 1;
      total++;
    }
  }
  return map.entries
      .map((e) => MoodDistribution(
            mood: e.key,
            count: e.value,
            percentage: total > 0 ? ((e.value / total) * 100).round() : 0,
          ))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
}

/// Study/break ratio.
StudyBreakRatio computeStudyBreakRatio(List<StudySession> sessions) {
  final study = sessions.fold(0, (s, e) => s + e.durationMinutes);
  final brk = sessions.fold(0, (s, e) => s + e.breakMinutes);
  final ratio = brk > 0
      ? '${(study / brk).toStringAsFixed(1)}:1'
      : study > 0
          ? '∞:1'
          : '0:0';
  return StudyBreakRatio(
      studyMinutes: study, breakMinutes: brk, ratio: ratio);
}

/// Rolling average.
int computeRollingAverage(List<DailyTotal> dailyTotals, int windowDays) {
  if (dailyTotals.isEmpty) return 0;
  final recent = dailyTotals.length > windowDays
      ? dailyTotals.sublist(dailyTotals.length - windowDays)
      : dailyTotals;
  final total = recent.fold(0, (s, d) => s + d.minutes);
  return (total / recent.length).round();
}
