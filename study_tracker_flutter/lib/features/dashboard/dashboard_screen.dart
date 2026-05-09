import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/responsive.dart';
import '../../core/providers/dashboard_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/achievements_provider.dart';
import '../../core/services/ai_challenge_service.dart';
import '../../data/repositories/ai_challenge_repository.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/stats_row.dart';
import 'widgets/progress_streak_card.dart';
import 'widgets/today_signal_banner.dart';
import 'widgets/active_mission_banner.dart';
import 'widgets/historical_context_card.dart';
import 'widgets/ai_coach_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _refreshMission(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    debugPrint('[Dashboard] Manual mission refresh triggered');
    await ref.read(aiChallengeServiceProvider).refreshSurpriseNow();

    final all = await ref.read(aiChallengeRepositoryProvider).getAll();
    final now = DateTime.now();
    final active = all.where((c) => !c.completed && c.expiresAt.isAfter(now)).toList();
    final hasAi = active.any((c) {
      final raw = (c.rawResponse ?? '').trim();
      return raw.isNotEmpty && raw != 'local-fallback';
    });

    ref.invalidate(dashboardProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hasAi
          ? l10n.dashboardMissionRefreshAi
          : l10n.dashboardMissionRefreshFallback),
        behavior: SnackBarBehavior.floating,
      ),
    );
    debugPrint('[Dashboard] Manual refresh result: ${hasAi ? 'ai' : 'fallback'}');
  }

  void _quickStart(BuildContext context, StudySessionMode mode) {
    context.go('${AppRoutes.sessions}?mode=${mode.dbValue}&autostart=1');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dashboardData = ref.watch(dashboardProvider);
    final settings = ref.watch(settingsProvider).settings;
    final achievements = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(R.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context, settings.displayName, achievements),
              SizedBox(height: R.defaultPadding),

              // Responsive Layout
              dashboardData.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(l10n.dashboardLoadError)),
                ),
                data: (data) => LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = constraints.maxWidth;
                    if (contentWidth >= 1200) {
                      return _buildWideLayout(context, data);
                    }
                    if (contentWidth >= 860) {
                      return _buildTabletAdaptiveLayout(context, data, contentWidth);
                    }
                    return _buildMobileLayout(context, data);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? displayName, AchievementsProvider achievements) {
    final l10n = AppLocalizations.of(context)!;
    final name = (displayName ?? '').trim().isEmpty ? l10n.dashboardScholarFallbackName : displayName!.trim();
    final remainingXp = achievements.xpToNextLevel;
    final focusMinutes = ref.watch(settingsProvider).settings.focusMinutes.clamp(1, 300);
    final estSessions = (remainingXp / focusMinutes).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.dashboardHello(name),
          style: AppTypography.textTheme.headlineLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          'Level ${achievements.currentLevel} · $remainingXp XP to next level',
          style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _quickStart(context, StudySessionMode.pomodoro),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Start Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, DashboardData data) {
    return _buildMobileLayout(context, data); // Keep it simple and single-column for wide as well, just like Svelte
  }

  Widget _buildTabletAdaptiveLayout(BuildContext context, DashboardData data, double contentWidth) {
    return _buildMobileLayout(context, data);
  }

  Widget _buildMobileLayout(BuildContext context, DashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatsRow(
          todayMinutes: data.deepWorkMinutes,
          weekVolume: data.deepWorkVolume,
          streak: data.currentStreak,
          totalMinutes: data.totalMinutes,
        ),
        const SizedBox(height: 24),
        ProgressStreakCard(data: data),
        const SizedBox(height: 8),
        TodaySignalBanner(data: data),
        const SizedBox(height: 24),
        const AiCoachCard(),
        const SizedBox(height: 24),
        HistoricalContextCard(data: data),
        const SizedBox(height: 24),
        ActiveMissionBanner(
          title: data.activeMissionTitle,
          onPlay: () => context.go(AppRoutes.sessions),
          onPickMission: () => context.go(AppRoutes.achievements),
        ),
      ],
    );
  }
}
