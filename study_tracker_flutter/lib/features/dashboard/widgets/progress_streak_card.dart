import 'package:flutter/material.dart';
import 'animated_streak_bar.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/utils.dart';
import '../../../l10n/app_localizations.dart';

import '../../../core/providers/dashboard_provider.dart';

class ProgressStreakCard extends StatelessWidget {
  final DashboardData data;

  const ProgressStreakCard({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final double pct = data.dailyGoalMinutes > 0 
        ? (data.deepWorkMinutes / data.dailyGoalMinutes).clamp(0.0, 1.0) 
        : 0.0;
        
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Left side: Progress Ring
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      color: AppColors.surfaceContainerHigh,
                    ),
                    CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 6,
                      color: AppColors.primary,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dashboardDailyProgress,
                    style: AppTypography.textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMinutes(data.deepWorkMinutes)} / ${formatMinutes(data.dailyGoalMinutes)}',
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          Container(width: 1, height: 48, color: AppColors.outline),
          const SizedBox(width: 16),
          
          // Right side: Streak Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.currentStreak} days · ${data.streakHud.daysToNext != null ? '${data.streakHud.daysToNext} ${l10n.dashboardDaysToNext.toLowerCase()}' : 'Max level'}',
                  style: AppTypography.textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                AnimatedStreakBar(progress: data.streakHud.progress01),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
