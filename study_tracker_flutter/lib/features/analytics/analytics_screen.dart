import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/summary_stats_grid.dart';
import 'widgets/consistency_heatmap_card.dart';
import 'widgets/daily_trend_chart.dart';
import 'widgets/session_ratio_card.dart';
import 'widgets/subject_breakdown_card.dart';
import 'widgets/mood_distribution_card.dart';
import 'widgets/peak_hours_chart.dart';
import 'widgets/recent_output_list.dart';
import 'widgets/ai_insights_section.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AnalyticsScreenContent();
  }
}

class _AnalyticsScreenContent extends ConsumerWidget {
  const _AnalyticsScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth;
            final isNarrow = contentWidth < 420;
            final useDesktop = contentWidth >= 1180;
            final useTablet = contentWidth >= 860;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isNarrow ? 14 : R.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, contentWidth),
                  const SizedBox(height: 32),
                  if (useDesktop)
                    _buildDesktopLayout()
                  else if (useTablet)
                    _buildTabletLayout(contentWidth)
                  else
                    _buildMobileLayout(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double contentWidth) {
    final l10n = AppLocalizations.of(context)!;
    final isNarrow = contentWidth < 420;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: AppColors.primary, size: isNarrow ? 32 : 40),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.navAnalytics,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.headlineLarge?.copyWith(fontSize: isNarrow ? 28 : 36),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.analyticsSubtitle,
          style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        const SummaryStatsGrid(),
        const SizedBox(height: 24),
        const AiInsightsSection(),
        const SizedBox(height: 24),
        const ConsistencyHeatmapCard(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  const DailyTrendChart(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: const MoodDistributionCard()),
                      const SizedBox(width: 24),
                      Expanded(child: const PeakHoursChart()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  const SessionRatioCard(),
                  const SizedBox(height: 24),
                  const SubjectBreakdownCard(),
                  const SizedBox(height: 24),
                  const RecentOutputList(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletLayout(double contentWidth) {
    final shouldSplitCards = contentWidth >= 980;
    return Column(
      children: [
        const SummaryStatsGrid(),
        const SizedBox(height: 24),
        const AiInsightsSection(),
        const SizedBox(height: 24),
        const ConsistencyHeatmapCard(),
        const SizedBox(height: 24),
        const DailyTrendChart(),
        const SizedBox(height: 24),
        _buildPairOrStack(
          shouldSplit: shouldSplitCards,
          first: const SessionRatioCard(),
          second: const SubjectBreakdownCard(),
        ),
        const SizedBox(height: 24),
        _buildPairOrStack(
          shouldSplit: shouldSplitCards,
          first: const MoodDistributionCard(),
          second: const PeakHoursChart(),
        ),
        const SizedBox(height: 24),
        const RecentOutputList(),
      ],
    );
  }

  Widget _buildPairOrStack({
    required bool shouldSplit,
    required Widget first,
    required Widget second,
  }) {
    if (!shouldSplit) {
      return Column(
        children: [
          first,
          const SizedBox(height: 24),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 24),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        const SummaryStatsGrid(),
        const SizedBox(height: 24),
        const AiInsightsSection(),
        const SizedBox(height: 24),
        const ConsistencyHeatmapCard(),
        const SizedBox(height: 24),
        const DailyTrendChart(),
        const SizedBox(height: 24),
        const SessionRatioCard(),
        const SizedBox(height: 24),
        const SubjectBreakdownCard(),
        const SizedBox(height: 24),
        const MoodDistributionCard(),
        const SizedBox(height: 24),
        const PeakHoursChart(),
        const SizedBox(height: 24),
        const RecentOutputList(),
      ],
    );
  }
}
