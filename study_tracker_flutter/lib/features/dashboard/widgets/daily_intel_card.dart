import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class DailyIntelCard extends StatelessWidget {
  final int deepWorkMinutes;
  final int focusScore;
  final int streak;

  const DailyIntelCard({
    Key? key,
    required this.deepWorkMinutes,
    required this.focusScore,
    required this.streak,
  }) : super(key: key);

  String get _formattedTime {
    final hours = deepWorkMinutes ~/ 60;
    final minutes = deepWorkMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dailyIntelTitle,
            style: AppTypography.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.dailyIntelSubtitle,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: l10n.dailyIntelDeepWork,
                  value: _formattedTime,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatBox(
                  label: l10n.dailyIntelFocusScore,
                  value: '$focusScore%',
                  isPrimary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StreakBox(streak: streak, daysLabel: l10n.daysLabel, streakLabel: l10n.dailyIntelStreak),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;

  const _StatBox({
    required this.label,
    required this.value,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primaryContainer : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.textTheme.labelMedium?.copyWith(
              color: isPrimary ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.textTheme.headlineSmall?.copyWith(
              color: isPrimary ? AppColors.onPrimaryContainer : AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBox extends StatelessWidget {
  final int streak;
  final String daysLabel;
  final String streakLabel;

  const _StreakBox({required this.streak, required this.daysLabel, required this.streakLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.outline,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                streakLabel,
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  color: AppColors.onPrimary.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$streak',
                    style: AppTypography.textTheme.headlineSmall?.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    daysLabel,
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onPrimary.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Icon(
            Icons.local_fire_department,
            color: AppColors.secondary,
            size: 32,
          ),
        ],
      ),
    );
  }
}
