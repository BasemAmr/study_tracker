import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class RecentOutputList extends ConsumerWidget {
  const RecentOutputList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.outline,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: AppColors.outline, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.analyticsRecentOutputTitle,
                  style: AppTypography.textTheme.headlineSmall,
                ),
                TextButton(
                  onPressed: () {
                    context.go('/sessions?tab=history');
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.analyticsViewAll,
                    style: AppTypography.textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // List
          if (provider.recentOutputs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n.analyticsNoRecentOutput,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.outlineVariant),
                ),
              ),
            )
          else
            ...provider.recentOutputs.asMap().entries.map((entry) {
              final index = entry.key;
              final output = entry.value;
              final isLast = index == provider.recentOutputs.length - 1;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast 
                      ? null 
                      : Border(bottom: BorderSide(color: AppColors.outline.withOpacity(0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: output.isHighlight 
                                  ? AppColors.primaryContainer 
                                  : AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Center(
                              child: Text(
                                output.code,
                                style: AppTypography.textTheme.labelMedium?.copyWith(
                                  color: output.isHighlight ? AppColors.onPrimaryContainer : AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  output.title,
                                  style: AppTypography.textTheme.headlineSmall?.copyWith(
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  output.dateString.replaceFirst('COMPLETED', l10n.analyticsCompletedPrefix),
                                  style: AppTypography.textTheme.labelSmall?.copyWith(
                                    color: AppColors.outlineVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          output.durationString,
                          style: AppTypography.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          output.tag,
                          style: AppTypography.textTheme.labelSmall?.copyWith(
                            color: output.isHighlight ? AppColors.primary : AppColors.outlineVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
