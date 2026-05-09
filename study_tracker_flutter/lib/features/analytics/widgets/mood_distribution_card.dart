import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../l10n/app_localizations.dart';

class MoodDistributionCard extends ConsumerWidget {
  const MoodDistributionCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.analyticsStateDistributionTitle,
                style: AppTypography.textTheme.headlineMedium,
              ),
              const Icon(Icons.psychology, color: AppColors.outlineVariant),
            ],
          ),
          const SizedBox(height: 24),
          if (provider.moodDistribution.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.analyticsNoMoodData,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.outlineVariant),
                ),
              ),
            )
          else
            Column(
              children: provider.moodDistribution.map((mood) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Text(
                        mood.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _localizedMoodLabel(mood.label, l10n),
                                  style: AppTypography.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(mood.percentage * 100).toInt()}%',
                                  style: AppTypography.textTheme.labelMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.outline, width: 2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: mood.percentage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getColorForMood(mood.label),
                                    borderRadius: BorderRadius.circular(4),
                                    border: const Border(
                                      right: BorderSide(color: AppColors.outline, width: 2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _localizedMoodLabel(String source, AppLocalizations l10n) {
    final lower = source.toLowerCase();
    if (lower.contains('flow')) return l10n.analyticsMoodDeepFlow;
    if (lower.contains('resistance')) return l10n.analyticsMoodResistance;
    if (lower.contains('fatigue')) return l10n.analyticsMoodFatigue;
    return source;
  }

  Color _getColorForMood(String label) {
    if (label.toLowerCase().contains('flow')) return AppColors.primary;
    if (label.toLowerCase().contains('resistance')) return AppColors.secondary;
    return AppColors.outlineVariant;
  }
}
