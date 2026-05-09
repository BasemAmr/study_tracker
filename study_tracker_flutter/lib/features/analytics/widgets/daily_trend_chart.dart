import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../l10n/app_localizations.dart';

class DailyTrendChart extends ConsumerWidget {
  const DailyTrendChart({Key? key}) : super(key: key);

  String _compactWeekday(String label, AppLocalizations l10n) {
    final lower = label.toLowerCase();
    if (lower.startsWith('mon')) return l10n.weekdayMonShort;
    if (lower.startsWith('tue')) return l10n.weekdayTueShort;
    if (lower.startsWith('wed')) return l10n.weekdayWedShort;
    if (lower.startsWith('thu')) return l10n.weekdayThuShort;
    if (lower.startsWith('fri')) return l10n.weekdayFriShort;
    if (lower.startsWith('sat')) return l10n.weekdaySatShort;
    if (lower.startsWith('sun')) return l10n.weekdaySunShort;
    return label.isNotEmpty ? label[0].toUpperCase() : '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);
    final maxData = provider.dailyTrendData.isNotEmpty 
        ? provider.dailyTrendData.reduce((curr, next) => curr > next ? curr : next) 
        : 1.0;

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.analyticsDailyTrendTitle,
                style: AppTypography.textTheme.headlineMedium,
              ),
              const Icon(Icons.bar_chart, color: AppColors.outline),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(provider.dailyTrendData.length, (index) {
                      final value = provider.dailyTrendData[index];
                      final heightRatio = value / (maxData > 0 ? maxData : 1);
                      final isPeak = value == maxData && maxData > 0;
                      
                      final double barPadding = provider.dailyTrendData.length > 14 ? 1.0 : 4.0;
                      
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: barPadding),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isPeak)
                                SizedBox(
                                  height: 0,
                                  child: OverflowBox(
                                    maxWidth: 80,
                                    maxHeight: 40,
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        border: Border.all(color: AppColors.outline),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: const [
                                          BoxShadow(color: AppColors.outline, offset: Offset(1, 1)),
                                        ],
                                      ),
                                      child: Text(
                                        _formatMinutes(value.toInt(), l10n),
                                        style: AppTypography.textTheme.labelSmall?.copyWith(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                ),
                              Flexible(
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
                            ],
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
                  children: List.generate(provider.dailyTrendLabels.length, (index) {
                    final showEvery = provider.dailyTrendLabels.length > 14 ? 2 : 1;
                    final compact = _compactWeekday(provider.dailyTrendLabels[index], l10n);
                    return Expanded(
                      child: Text(
                        index % showEvery == 0 ? compact : '',
                        textAlign: TextAlign.center,
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.outlineVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int totalMins, AppLocalizations l10n) {
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    if (h > 0) return '$h${l10n.hoursUnit} $m${l10n.minutesUnit}';
    return '$m${l10n.minutesUnit}';
  }
}
