import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/ai_challenge_service.dart';
import '../../core/utils/utils.dart';
import 'settings_provider.dart';
import '../../data/repositories/ai_challenge_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/domain.dart';

import '../utils/streak_milestone_hud.dart';

enum WellbeingState { proud, flow, burnout, idle }

class DashboardData {
  final int deepWorkMinutes;
  final int focusScore;
  final int currentStreak;
  final int personalBestStreak;
  final StreakHudProgress streakHud;
  final int dailyGoalMinutes;

  final String activeMissionTitle;
  final String activeMissionSubtitle;
  final double activeMissionProgress;

  final List<int> consistencyData;
  final WellbeingState currentState;

  final String deepWorkVolume;
  final String deepWorkVolumeComparison;

  final String avgFocusSession;
  final String avgFocusSessionComparison;

  final int completionRate;
  final String completionRateStatus;
  final bool missionUsesAi;
  final int totalMinutes;

  const DashboardData({
    required this.deepWorkMinutes,
    required this.focusScore,
    required this.currentStreak,
    required this.personalBestStreak,
    required this.streakHud,
    required this.dailyGoalMinutes,
    required this.activeMissionTitle,
    required this.activeMissionSubtitle,
    required this.activeMissionProgress,
    required this.consistencyData,
    required this.currentState,
    required this.deepWorkVolume,
    required this.deepWorkVolumeComparison,
    required this.avgFocusSession,
    required this.avgFocusSessionComparison,
    required this.completionRate,
    required this.completionRateStatus,
    required this.missionUsesAi,
    required this.totalMinutes,
  });
}

final dashboardProvider = StreamProvider.autoDispose<DashboardData>((ref) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final challengeRepo = ref.watch(aiChallengeRepositoryProvider);
  final aiService = ref.watch(aiChallengeServiceProvider);

  return sessionRepo.watchAllSessions().asyncMap((allSessions) async {
    final settings = await settingsRepo.getStructured();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final weekStart = startOfWeek(now);
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));

    final todaySessions = allSessions
        .where((s) => !s.startAt.isBefore(todayStart) && s.startAt.isBefore(tomorrowStart))
        .toList();

    final weekSessions = allSessions
        .where((s) => !s.startAt.isBefore(weekStart) && s.startAt.isBefore(now))
        .toList();

    final lastWeekSessions = allSessions
        .where((s) => !s.startAt.isBefore(lastWeekStart) && s.startAt.isBefore(weekStart))
        .toList();

    final deepWorkMinutes = todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final breakMinutesToday = todaySessions.fold<int>(0, (sum, s) => sum + s.breakMinutes);
    final denom = max(1, deepWorkMinutes + breakMinutesToday);
    final focusScore = ((deepWorkMinutes / denom) * 100).round().clamp(0, 100);

    final streaks = calculateStreaks(allSessions.map((s) => s.startAt).toList());
    final currentStreak = streaks.currentStreak;
    final personalBestStreak = streaks.longestStreak;

    final dailyGoalMinutes = max(1, settings.dailyGoalMinutes);

    final deepWorkVolumeMinutes = weekSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final lastWeekVolumeMinutes =
        lastWeekSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final volumeDelta = deepWorkVolumeMinutes - lastWeekVolumeMinutes;

    final weekAvgSession =
        weekSessions.isEmpty ? 0 : (deepWorkVolumeMinutes / weekSessions.length).round();
    final lastWeekAvgSession =
        lastWeekSessions.isEmpty ? 0 : (lastWeekVolumeMinutes / lastWeekSessions.length).round();
    final avgDelta = weekAvgSession - lastWeekAvgSession;

    final activeDaysThisWeek = weekSessions
        .map((s) => DateTime(s.startAt.year, s.startAt.month, s.startAt.day))
        .toSet()
        .length;
    final completionRate = ((activeDaysThisWeek / 7) * 100).round().clamp(0, 100);

    final completionRateStatus = completionRate >= 85
        ? 'EXCELLENT'
        : (completionRate >= 60 ? 'SOLID' : 'DROPPING');

    final consistencyData = _buildConsistencyData(allSessions, now);
    final wellbeingState = _deriveWellbeingState(
      currentStreak: currentStreak,
      deepWorkMinutesToday: deepWorkMinutes,
    );

    final streakHud = computeStreakHudProgress(currentStreak, personalBestStreak);

    final activeMission = await _resolveActiveMission(challengeRepo, aiService);
    if (kDebugMode) {
      debugPrint('[Dashboard] Mission loaded title="${activeMission.title}" source=${activeMission.isAi ? 'ai' : 'fallback'}');
    }

    final totalMinutes = allSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

    return DashboardData(
      deepWorkMinutes: deepWorkMinutes,
      focusScore: focusScore,
      currentStreak: currentStreak,
      personalBestStreak: personalBestStreak,
      streakHud: streakHud,
      dailyGoalMinutes: dailyGoalMinutes,
      activeMissionTitle: activeMission.title,
      activeMissionSubtitle: activeMission.subtitle,
      activeMissionProgress: activeMission.progress,
      consistencyData: consistencyData,
      currentState: wellbeingState,
      deepWorkVolume: formatMinutes(deepWorkVolumeMinutes),
      deepWorkVolumeComparison: _formatDelta(volumeDelta),
      avgFocusSession: formatMinutes(weekAvgSession),
      avgFocusSessionComparison: _formatDelta(avgDelta),
      completionRate: completionRate,
      completionRateStatus: completionRateStatus,
      missionUsesAi: activeMission.isAi,
      totalMinutes: totalMinutes,
    );
  });
});

class _MissionData {
  final String title;
  final String subtitle;
  final double progress;
  final bool isAi;

  const _MissionData({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.isAi,
  });
}

Future<_MissionData> _resolveActiveMission(
  AiChallengeRepository challengeRepo,
  AiChallengeService aiService,
) async {
  if (kDebugMode) {
    debugPrint('[Dashboard] Resolving pinned active mission');
  }

  // Use the pinned mission. Auto-clears if the mission is stale/expired/replaced.
  final challenge = await aiService.resolveActiveMission();

  if (challenge == null) {
    if (kDebugMode) {
      debugPrint('[Dashboard] No pinned/valid active mission');
    }
    return const _MissionData(
      title: '',
      subtitle: 'Pick an active mission from AI Missions.',
      progress: 0,
      isAi: false,
    );
  }

  final progress = await aiService.calculateProgress(challenge);
  final isAi = (challenge.rawResponse ?? '').trim().isNotEmpty &&
      challenge.rawResponse != 'local-fallback';

  if (kDebugMode) {
    debugPrint('[Dashboard] Pinned mission: "${challenge.title}" ai=$isAi');
  }

  return _MissionData(
    title: challenge.title,
    subtitle: challenge.description,
    progress: (progress.percent / 100).clamp(0.0, 1.0),
    isAi: isAi,
  );
}

List<int> _buildConsistencyData(List<StudySession> sessions, DateTime now) {
  final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

  final byDayMinutes = <DateTime, int>{};
  for (int i = 0; i < 14; i++) {
    final d = from.add(Duration(days: i));
    byDayMinutes[DateTime(d.year, d.month, d.day)] = 0;
  }

  for (final s in sessions) {
    if (s.startAt.isBefore(from) || s.startAt.isAfter(to)) continue;
    final day = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
    byDayMinutes[day] = (byDayMinutes[day] ?? 0) + s.durationMinutes;
  }

  final ordered = byDayMinutes.keys.toList()..sort();
  return ordered.map((d) => _levelForMinutes(byDayMinutes[d] ?? 0)).toList();
}

int _levelForMinutes(int minutes) {
  if (minutes <= 0) return 0;
  if (minutes <= 30) return 1;
  if (minutes <= 60) return 2;
  if (minutes <= 120) return 3;
  return 4;
}

WellbeingState _deriveWellbeingState({
  required int currentStreak,
  required int deepWorkMinutesToday,
}) {
  // No activity at all → idle
  if (deepWorkMinutesToday == 0 && currentStreak == 0) return WellbeingState.idle;
  // Over 6 hours today → burnout (fatigue only)
  if (deepWorkMinutesToday > 360) return WellbeingState.burnout;
  // Long-running streak → proud
  if (currentStreak >= 7) return WellbeingState.proud;
  // At least 2 hours deep work today → flow (matches desktop; week spread is separate UI)
  if (deepWorkMinutesToday >= 120) return WellbeingState.flow;
  return WellbeingState.idle;
}

String _formatDelta(int minutesDelta) {
  if (minutesDelta == 0) return '0m';
  final sign = minutesDelta > 0 ? '+' : '-';
  return '$sign${formatMinutes(minutesDelta.abs())}';
}
