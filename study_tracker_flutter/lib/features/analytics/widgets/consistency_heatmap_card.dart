import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class ConsistencyHeatmapCard extends ConsumerWidget {
  const ConsistencyHeatmapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);
    final start = provider.consistencyStartDate;
    final levels = provider.consistencyLevels;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.analyticsHeatmapTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            start == null
                ? l10n.analyticsNoSessionsYet
                : l10n.analyticsStartDay('${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 124,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _HeatmapGrid(levels: levels),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(l10n.lessLabel, style: AppTypography.textTheme.labelSmall),
              const SizedBox(width: 6),
              ...List.generate(5, (i) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _colorForLevel(i),
                    border: Border.all(color: AppColors.outline, width: 1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(l10n.moreLabel, style: AppTypography.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForLevel(int level) {
    switch (level) {
      case 0:
        return AppColors.surfaceContainer;
      case 1:
        return AppColors.primary.withValues(alpha: 0.35);
      case 2:
        return AppColors.primary.withValues(alpha: 0.55);
      case 3:
        return AppColors.primary.withValues(alpha: 0.8);
      case 4:
        return AppColors.secondary;
      default:
        return AppColors.surfaceContainer;
    }
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<int> levels;

  const _HeatmapGrid({required this.levels});

  @override
  Widget build(BuildContext context) {
    final data = levels.isEmpty ? List<int>.filled(365, 0) : levels;
    final weeks = (data.length / 7).ceil();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(weeks, (weekIndex) {
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Column(
            children: List.generate(7, (dayOffset) {
              final index = weekIndex * 7 + dayOffset;
              final level = index < data.length ? data[index] : 0;
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: _colorForLevel(level),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.25), width: 1),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Color _colorForLevel(int level) {
    switch (level) {
      case 0:
        return AppColors.surfaceContainer;
      case 1:
        return AppColors.primary.withValues(alpha: 0.35);
      case 2:
        return AppColors.primary.withValues(alpha: 0.55);
      case 3:
        return AppColors.primary.withValues(alpha: 0.8);
      case 4:
        return AppColors.secondary;
      default:
        return AppColors.surfaceContainer;
    }
  }
}
