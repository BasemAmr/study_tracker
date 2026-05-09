import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../l10n/app_localizations.dart';

class SummaryStatsGrid extends ConsumerWidget {
  const SummaryStatsGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 2 : 4;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isMobile ? 1.5 : 1.2,
          children: [
            _buildStatCard(
              l10n.analyticsStatTotalTime,
              _formatMinutes(provider.totalMinutes, l10n),
              isPrimary: true,
            ),
            _buildStatCard(
              l10n.analyticsStatDailyAvg,
              _formatMinutes(provider.dailyAvgMinutes, l10n),
            ),
            _buildStatCard(
              l10n.analyticsStatPeakSession,
              _formatMinutes(provider.peakSessionMinutes, l10n),
              isSecondary: true,
            ),
            _buildStatCard(
              l10n.analyticsStatPeakHour,
              '${provider.peakHour > 12 ? provider.peakHour - 12 : provider.peakHour} ${provider.peakHour >= 12 ? l10n.analyticsPm : l10n.analyticsAm}',
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, {bool isPrimary = false, bool isSecondary = false}) {
    Color textColor = AppColors.onSurface;
    if (isPrimary) textColor = AppColors.primary;
    if (isSecondary) textColor = AppColors.secondary;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: AppColors.outlineVariant,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.textTheme.headlineLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int totalMins, AppLocalizations l10n) {
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    if (hours > 0) return '$hours${l10n.hoursUnit} $mins${l10n.minutesUnit}';
    return '$mins${l10n.minutesUnit}';
  }
}
