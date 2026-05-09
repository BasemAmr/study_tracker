import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../l10n/app_localizations.dart';

class HistoricalContextCard extends StatelessWidget {
  final DashboardData data;

  const HistoricalContextCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.outline,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.historicalContextTitle,
                  style: AppTypography.textTheme.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
                child: Text(
                  l10n.historicalThisWeek,
                  style: AppTypography.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildMetricRow(
            title: l10n.historicalDeepWorkVolume,
            value: data.deepWorkVolume,
            comparisonLabel: l10n.historicalLastWeek,
            comparisonValue: data.deepWorkVolumeComparison,
            isPositive: data.deepWorkVolumeComparison.startsWith('+'),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            title: l10n.historicalAverageFocusSession,
            value: data.avgFocusSession,
            comparisonLabel: l10n.historicalLastWeek,
            comparisonValue: data.avgFocusSessionComparison,
            isPositive: data.avgFocusSessionComparison.startsWith('+'),
            isNeutral: data.avgFocusSessionComparison.startsWith('-'),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            title: l10n.historicalCompletionRate,
            value: '${data.completionRate}%',
            comparisonLabel: '',
            comparisonValue: data.completionRateStatus,
            isPositive: data.completionRateStatus == 'SOLID',
            hideBottomBorder: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String title,
    required String value,
    required String comparisonLabel,
    required String comparisonValue,
    bool isPositive = false,
    bool isNeutral = false,
    bool hideBottomBorder = false,
  }) {
    final compColor = isPositive
        ? AppColors.primary
      : (isNeutral ? AppColors.onSurface.withValues(alpha: 0.6) : AppColors.secondary);

    return Padding(
      padding: EdgeInsets.only(bottom: hideBottomBorder ? 0 : 12),
      child: Container(
        decoration: hideBottomBorder
            ? null
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.outline, width: 1),
                ),
              ),
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: AppTypography.textTheme.headlineSmall?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comparisonValue,
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        color: compColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
