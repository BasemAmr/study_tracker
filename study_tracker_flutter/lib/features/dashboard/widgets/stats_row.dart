import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/utils.dart';
import '../../../l10n/app_localizations.dart';

class StatsRow extends StatelessWidget {
  final int todayMinutes;
  final String weekVolume;
  final int streak;
  final int totalMinutes;

  const StatsRow({
    Key? key,
    required this.todayMinutes,
    required this.weekVolume,
    required this.streak,
    required this.totalMinutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            label: l10n.dashboardToday,
            value: formatMinutes(todayMinutes),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            label: l10n.dashboardLast7Days,
            value: weekVolume,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            label: l10n.dashboardStreak,
            value: '$streak🔥',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            label: l10n.dashboardAllTime,
            value: formatMinutes(totalMinutes),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
