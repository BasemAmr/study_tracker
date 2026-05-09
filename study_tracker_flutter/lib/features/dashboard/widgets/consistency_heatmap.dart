import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class ConsistencyHeatmap extends StatelessWidget {
  final List<int> data;

  const ConsistencyHeatmap({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.consistencyGridTitle,
                  style: AppTypography.textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.consistencyLast14Days,
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildGrid(context),
          const SizedBox(height: 16),
          _buildLegend(context),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    // Ensuring we have exactly 14 items for a 2x7 layout
    final safeData = List<int>.from(data);
    while (safeData.length < 14) {
      safeData.insert(0, 0);
    }
    if (safeData.length > 14) {
      safeData.removeRange(0, safeData.length - 14);
    }

    final week1 = safeData.sublist(0, 7);
    final week2 = safeData.sublist(7, 14);

    return Column(
      children: [
        _buildWeekRow(context, week1),
        const SizedBox(height: 8),
        _buildWeekRow(context, week2, isCurrentWeek: true),
      ],
    );
  }

  Widget _buildWeekRow(BuildContext context, List<int> weekData, {bool isCurrentWeek = false}) {
    final l10n = AppLocalizations.of(context)!;
    final days = [
      l10n.weekdayMonShort,
      l10n.weekdayTueShort,
      l10n.weekdayWedShort,
      l10n.weekdayThuShort,
      l10n.weekdayFriShort,
      l10n.weekdaySatShort,
      l10n.weekdaySunShort,
    ];
    
    return Row(
      children: List.generate(7, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _HeatmapCell(
              dayLabel: days[index],
              level: weekData[index],
              isToday: isCurrentWeek && index == 6, // Mocking today as Sunday of week2
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          l10n.lessLabel,
          style: AppTypography.textTheme.labelMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: List.generate(5, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getColorForLevel(index),
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.moreLabel,
          style: AppTypography.textTheme.labelMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static Color _getColorForLevel(int level) {
    switch (level) {
      case 0:
        return AppColors.surfaceContainer;
      case 1:
        return AppColors.primary.withOpacity(0.4);
      case 2:
        return AppColors.primary.withOpacity(0.7);
      case 3:
        return AppColors.primary;
      case 4:
        return AppColors.secondary;
      default:
        return AppColors.surfaceContainer;
    }
  }
}

class _HeatmapCell extends StatelessWidget {
  final String dayLabel;
  final int level;
  final bool isToday;

  const _HeatmapCell({
    required this.dayLabel,
    required this.level,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: ConsistencyHeatmap._getColorForLevel(level),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.outline,
              width: isToday ? 2 : 1,
            ),
            boxShadow: [
              if (level > 0 && !isToday)
                const BoxShadow(color: AppColors.outline, offset: Offset(0, 1)),
            ],
          ),
          child: Center(
            child: Text(
              dayLabel,
              style: AppTypography.textTheme.labelSmall?.copyWith(
                color: level > 1 ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
          ),
        ),
        if (isToday) ...[
          const SizedBox(height: 4),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          )
        ]
      ],
    );
  }
}
