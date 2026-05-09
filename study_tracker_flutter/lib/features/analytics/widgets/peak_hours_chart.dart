import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../l10n/app_localizations.dart';

class PeakHoursChart extends ConsumerWidget {
  const PeakHoursChart({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);
    final maxData = provider.peakHoursData.isNotEmpty 
        ? provider.peakHoursData.reduce((curr, next) => curr > next ? curr : next) 
        : 1.0;

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
                  l10n.analyticsPeakStudyHoursTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.schedule, color: AppColors.outlineVariant),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(provider.peakHoursData.length, (index) {
                      final value = provider.peakHoursData[index];
                      final heightRatio = value / (maxData > 0 ? maxData : 1);
                      final isPeak = value == maxData && maxData > 0;
                      
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Container(
                                height: constraints.maxHeight * heightRatio,
                                decoration: BoxDecoration(
                                  color: isPeak ? AppColors.primary : AppColors.surfaceContainerHigh,
                                  border: isPeak 
                                      ? const Border(
                                          top: BorderSide(color: AppColors.outline, width: 2),
                                          left: BorderSide(color: AppColors.outline, width: 2),
                                          right: BorderSide(color: AppColors.outline, width: 2),
                                        )
                                      : Border.all(color: AppColors.outline.withOpacity(0.2)),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              );
                            }
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Container(height: 2, color: AppColors.outline),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: provider.peakHoursLabels.map((label) {
                    return Text(
                      label,
                      style: AppTypography.textTheme.labelSmall?.copyWith(
                        color: AppColors.outlineVariant,
                        fontSize: 10,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
