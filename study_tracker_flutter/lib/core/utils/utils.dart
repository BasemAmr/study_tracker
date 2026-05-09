import '../../domain/domain.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Date utilities (ported from dateUtils.ts)
// ─────────────────────────────────────────────────────────────────────────────

DateTime startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

DateTime startOfWeek(DateTime date) {
  // Week starts Saturday
  final weekday = date.weekday; // 1=Mon … 7=Sun
  // If Sat(6) -> sub 0, If Sun(7) -> sub 1, If Mon(1) -> sub 2
  final daysToSubtract = (weekday + 1) % 7;
  return startOfDay(date.subtract(Duration(days: daysToSubtract)));
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

DateTime daysAgo(int days) =>
    startOfDay(DateTime.now().subtract(Duration(days: days)));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<DateTime> dateRange(DateTime start, DateTime end) {
  final result = <DateTime>[];
  DateTime current = startOfDay(start);
  final endDay = startOfDay(end);
  while (!current.isAfter(endDay)) {
    result.add(current);
    current = current.add(const Duration(days: 1));
  }
  return result;
}

String todayDateString() {
  final now = DateTime.now();
  return '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
}

String _pad(int n) => n.toString().padLeft(2, '0');

// ─────────────────────────────────────────────────────────────────────────────
// Streak utilities (ported from streakUtils.ts)
// ─────────────────────────────────────────────────────────────────────────────

class StreakResult {
  final int currentStreak;
  final int longestStreak;

  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
  });
}

StreakResult calculateStreaks(List<DateTime> studyDates) {
  if (studyDates.isEmpty) {
    return const StreakResult(currentStreak: 0, longestStreak: 0);
  }

  // Deduplicate to unique days, sorted ascending
  final uniqueDays = <DateTime>[];
  final sorted = [...studyDates]..sort((a, b) => a.compareTo(b));
  for (final date in sorted) {
    final day = startOfDay(date);
    if (uniqueDays.isEmpty || !isSameDay(uniqueDays.last, day)) {
      uniqueDays.add(day);
    }
  }

  int longestStreak = 1;
  int currentRun = 1;

  for (int i = 1; i < uniqueDays.length; i++) {
    final diff = uniqueDays[i].difference(uniqueDays[i - 1]).inDays;
    if (diff == 1) {
      currentRun++;
    } else {
      currentRun = 1;
    }
    if (currentRun > longestStreak) longestStreak = currentRun;
  }

  // Current streak — last study day must be today or yesterday
  final today = startOfDay(DateTime.now());
  final lastStudyDay = uniqueDays.last;
  final daysSinceLast = today.difference(lastStudyDay).inDays;

  int currentStreak = 0;
  if (daysSinceLast <= 1) {
    currentStreak = 1;
    for (int i = uniqueDays.length - 2; i >= 0; i--) {
      final diff =
          uniqueDays[i + 1].difference(uniqueDays[i]).inDays;
      if (diff == 1) {
        currentStreak++;
      } else {
        break;
      }
    }
  }

  return StreakResult(
    currentStreak: currentStreak,
    longestStreak: longestStreak,
  );
}

Map<String, int> buildDailyMinutesMap(List<StudySession> sessions) {
  final map = <String, int>{};
  for (final s in sessions) {
    final d = s.startAt;
    final key = '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
    map[key] = (map[key] ?? 0) + s.durationMinutes;
  }
  return map;
}

// ─────────────────────────────────────────────────────────────────────────────
// Format utilities (ported from formatUtils.ts)
// ─────────────────────────────────────────────────────────────────────────────

String formatMinutes(int totalMinutes) {
  if (totalMinutes <= 0) return '0m';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String formatTimer(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '${_pad(h)}:${_pad(m)}:${_pad(s)}';
  }
  return '${_pad(m)}:${_pad(s)}';
}

String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = startOfDay(now).difference(startOfDay(date)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';
  return '${_monthAbbr(date.month)} ${date.day}, ${date.year}';
}

String formatHour(int hour) {
  if (hour == 0) return '12 AM';
  if (hour < 12) return '$hour AM';
  if (hour == 12) return '12 PM';
  return '${hour - 12} PM';
}

String _monthAbbr(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[month - 1];
}

String capitalize(String s) =>
    s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
