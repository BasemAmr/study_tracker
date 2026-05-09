import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/domain.dart';

enum AnalyticsRange { days7, days14, days30 }
enum AnalyticsGranularity { hour, day }

class MoodStat {
  final String emoji;
  final String label;
  final double percentage;
  final int count;

  MoodStat({
    required this.emoji,
    required this.label,
    required this.percentage,
    required this.count,
  });
}

class SubjectStat {
  final String name;
  final int minutes;
  final double percentage;

  SubjectStat({
    required this.name,
    required this.minutes,
    required this.percentage,
  });
}

class RecentOutput {
  final String code;
  final String title;
  final String dateString;
  final String durationString;
  final String tag;
  final bool isHighlight;

  RecentOutput({
    required this.code,
    required this.title,
    required this.dateString,
    required this.durationString,
    required this.tag,
    this.isHighlight = false,
  });
}

class AnalyticsProvider extends ChangeNotifier {
  final SessionRepository _sessionRepo;
  StreamSubscription<List<StudySession>>? _sessionsSubscription;
  Timer? _recomputeDebounce;
  List<StudySession> _allSessions = const [];

  AnalyticsProvider(this._sessionRepo) {
    _sessionsSubscription = _sessionRepo.watchAllSessions().listen((sessions) {
      _allSessions = sessions;
      _scheduleRecompute();
    });
  }

  AnalyticsRange _range = AnalyticsRange.days30;
  AnalyticsGranularity _granularity = AnalyticsGranularity.day;

  AnalyticsRange get range => _range;
  AnalyticsGranularity get granularity => _granularity;

  bool isLoading = false;

  // Overview Stats
  int totalMinutes = 0;
  int dailyAvgMinutes = 0;
  int peakSessionMinutes = 0;
  int peakHour = 0;

  // Ratio
  double studyRatio = 0;
  double breakRatio = 0;

  List<double> dailyTrendData = const [];
  List<String> dailyTrendLabels = const [];

  List<double> peakHoursData = const [];
  List<String> peakHoursLabels = const [];

  List<MoodStat> moodDistribution = const [];

  List<SubjectStat> subjectBreakdown = const [];

  List<RecentOutput> recentOutputs = const [];

  DateTime? consistencyStartDate;
  List<int> consistencyLevels = const [];

  void setRange(AnalyticsRange newRange) {
    _range = newRange;
    _scheduleRecompute();
  }

  void setGranularity(AnalyticsGranularity newGranularity) {
    _granularity = newGranularity;
    _scheduleRecompute();
  }

  void _scheduleRecompute() {
    _recomputeDebounce?.cancel();
    _recomputeDebounce = Timer(const Duration(milliseconds: 120), _recompute);
  }

  void _recompute() async {
    isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final days = switch (_range) {
        AnalyticsRange.days7 => 7,
        AnalyticsRange.days14 => 14,
        AnalyticsRange.days30 => 30,
      };
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

      final sessions = _allSessions.where((s) {
        return !s.startAt.isBefore(start) && !s.startAt.isAfter(now);
      }).toList();

      totalMinutes = sessions.fold(0, (sum, s) => sum + s.durationMinutes);
      dailyAvgMinutes = days > 0 ? (totalMinutes / days).round() : 0;
      peakSessionMinutes = sessions.isEmpty
          ? 0
          : sessions.map((s) => s.durationMinutes).reduce(max);

      final byHour = <int, int>{};
      for (final s in sessions) {
        byHour[s.startAt.hour] = (byHour[s.startAt.hour] ?? 0) + s.durationMinutes;
      }
      peakHour = byHour.entries.isEmpty
          ? 0
          : byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      final breakTotal = sessions.fold(0, (sum, s) => sum + s.breakMinutes);
      final totalTime = max(1, totalMinutes + breakTotal);
      studyRatio = (totalMinutes / totalTime) * 100;
      breakRatio = (breakTotal / totalTime) * 100;

      _computeDailyTrend(sessions, start, days);
      _computePeakHours(sessions);
      _computeMoodDistribution(sessions);
      _computeSubjectBreakdown(sessions);
      _computeRecentOutputs(sessions);

      final heatmapSessions = _allSessions
          .map((s) => {
                'startAtMs': s.startAt.millisecondsSinceEpoch,
                'durationMinutes': s.durationMinutes,
              })
          .toList(growable: false);
      final heatmapArgs = {
        'sessions': heatmapSessions,
        'nowMs': now.millisecondsSinceEpoch,
      };
      final heatmapData = await compute(_buildConsistencyHeatmap, heatmapArgs);
      consistencyStartDate = heatmapData['startDate'] as DateTime;
      consistencyLevels = heatmapData['levels'] as List<int>;
    } catch (_) {
      totalMinutes = 0;
      dailyAvgMinutes = 0;
      peakSessionMinutes = 0;
      peakHour = 0;
      studyRatio = 0;
      breakRatio = 0;
      dailyTrendData = const [];
      dailyTrendLabels = const [];
      peakHoursData = const [];
      peakHoursLabels = const [];
      moodDistribution = const [];
      subjectBreakdown = const [];
      recentOutputs = const [];
      consistencyStartDate = null;
      consistencyLevels = const [];
    }

    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _recomputeDebounce?.cancel();
    _sessionsSubscription?.cancel();
    super.dispose();
  }

  void _computeDailyTrend(List<StudySession> sessions, DateTime start, int days) {
    final minutesByDay = <DateTime, int>{};
    for (int i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      minutesByDay[d] = 0;
    }

    for (final s in sessions) {
      final d = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
      if (minutesByDay.containsKey(d)) {
        minutesByDay[d] = (minutesByDay[d] ?? 0) + s.durationMinutes;
      }
    }

    final orderedDays = minutesByDay.keys.toList()..sort();
    dailyTrendData = orderedDays.map((d) => (minutesByDay[d] ?? 0).toDouble()).toList();
    dailyTrendLabels = orderedDays.map((d) => _weekdayLabel(d.weekday)).toList();
  }

  void _computePeakHours(List<StudySession> sessions) {
    final hourBuckets = <int, int>{for (int i = 0; i < 24; i++) i: 0};
    for (final s in sessions) {
      hourBuckets[s.startAt.hour] = (hourBuckets[s.startAt.hour] ?? 0) + s.durationMinutes;
    }

    const selectedHours = [6, 9, 12, 15, 18, 21, 0, 3];
    peakHoursData = selectedHours.map((h) => (hourBuckets[h] ?? 0).toDouble()).toList();
    peakHoursLabels = selectedHours.map(_hourLabel).toList();
  }

  void _computeMoodDistribution(List<StudySession> sessions) {
    final counts = <String, int>{
      'Deep Flow': 0,
      'Resistance': 0,
      'Fatigue': 0,
    };

    for (final s in sessions) {
      final mood = (s.mood ?? '').toLowerCase();
      if (mood.contains('focus') || mood.contains('productive') || mood.contains('flow') || mood.contains('calm')) {
        counts['Deep Flow'] = (counts['Deep Flow'] ?? 0) + 1;
      } else if (mood.contains('stress') || mood.contains('distract') || mood.contains('resist')) {
        counts['Resistance'] = (counts['Resistance'] ?? 0) + 1;
      } else {
        counts['Fatigue'] = (counts['Fatigue'] ?? 0) + 1;
      }
    }

    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      moodDistribution = const [];
      return;
    }

    moodDistribution = [
      MoodStat(emoji: '😎', label: 'Deep Flow', percentage: (counts['Deep Flow']! / total), count: counts['Deep Flow']!),
      MoodStat(emoji: '🤔', label: 'Resistance', percentage: (counts['Resistance']! / total), count: counts['Resistance']!),
      MoodStat(emoji: '😴', label: 'Fatigue', percentage: (counts['Fatigue']! / total), count: counts['Fatigue']!),
    ];
  }

  void _computeSubjectBreakdown(List<StudySession> sessions) {
    final bySubject = <String, int>{};
    for (final s in sessions) {
      final key = (s.subjectName?.trim().isNotEmpty ?? false)
          ? s.subjectName!.trim()
          : 'General';
      bySubject[key] = (bySubject[key] ?? 0) + s.durationMinutes;
    }
    final total = bySubject.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      subjectBreakdown = const [];
      return;
    }

    final sorted = bySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    subjectBreakdown = sorted.take(6).map((e) {
      return SubjectStat(
        name: e.key,
        minutes: e.value,
        percentage: e.value / total,
      );
    }).toList();
  }

  void _computeRecentOutputs(List<StudySession> sessions) {
    final sorted = [...sessions]..sort((a, b) => b.startAt.compareTo(a.startAt));
    recentOutputs = sorted.take(8).map((s) {
      final subject = (s.subjectName?.trim().isNotEmpty ?? false) ? s.subjectName!.trim() : 'General Study';
      final topic = (s.topic?.trim().isNotEmpty ?? false) ? s.topic!.trim() : subject;
      final code = subject
          .split(' ')
          .where((e) => e.isNotEmpty)
          .take(2)
          .map((e) => e[0].toUpperCase())
          .join()
          .padRight(2, 'G')
          .substring(0, 2);

      return RecentOutput(
        code: code,
        title: topic,
        dateString: 'COMPLETED ${s.startAt.year}-${s.startAt.month.toString().padLeft(2, '0')}-${s.startAt.day.toString().padLeft(2, '0')}',
        durationString: _formatMinutes(s.durationMinutes),
        tag: (s.mood ?? 'FOCUS').toUpperCase(),
        isHighlight: s.durationMinutes >= 90,
      );
    }).toList();
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  String _hourLabel(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'P' : 'A';
    return '$h$suffix';
  }

  String _formatMinutes(int totalMins) {
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

Map<String, dynamic> _buildConsistencyHeatmap(Map<String, dynamic> args) {
  final rawSessions = (args['sessions'] as List).cast<Map<String, Object?>>();
  final now = DateTime.fromMillisecondsSinceEpoch(args['nowMs'] as int);

  if (rawSessions.isEmpty) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 364));
    return {
      'startDate': start,
      'levels': List<int>.filled(365, 0),
    };
  }

  final sorted = [...rawSessions]
    ..sort((a, b) => (a['startAtMs'] as int).compareTo(b['startAtMs'] as int));
  final first = DateTime.fromMillisecondsSinceEpoch(sorted.first['startAtMs'] as int);
  final start = DateTime(first.year, first.month, first.day);

  final byDayMinutes = <DateTime, int>{};
  for (final s in rawSessions) {
    final startAt = DateTime.fromMillisecondsSinceEpoch(s['startAtMs'] as int);
    final d = DateTime(startAt.year, startAt.month, startAt.day);
    byDayMinutes[d] = (byDayMinutes[d] ?? 0) + (s['durationMinutes'] as int);
  }

  final levels = List<int>.generate(365, (index) {
    final d = start.add(Duration(days: index));
    final mins = byDayMinutes[d] ?? 0;
    if (mins <= 0) return 0;
    if (mins <= 30) return 1;
    if (mins <= 60) return 2;
    if (mins <= 120) return 3;
    return 4;
  });

  return {
    'startDate': start,
    'levels': levels,
  };
}

final analyticsProvider = ChangeNotifierProvider<AnalyticsProvider>((ref) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  return AnalyticsProvider(ref.watch(sessionRepositoryProvider));
});
