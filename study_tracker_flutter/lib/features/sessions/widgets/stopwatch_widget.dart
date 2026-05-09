import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/stopwatch_provider.dart';
import '../../../l10n/app_localizations.dart';

class StopwatchWidget extends ConsumerWidget {
  const StopwatchWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stopwatch = ref.watch(stopwatchProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.outline,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.stopwatchTitle,
            style: AppTypography.textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            stopwatch.stopwatchDisplay,
            style: AppTypography.textTheme.displayLarge?.copyWith(
              fontSize: 64,
              fontFamily: AppTypography.monoFont,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (stopwatch.state == StopwatchState.idle)
                ElevatedButton(
                  onPressed: () => stopwatch.start(),
                  child: Text(l10n.stopwatchStart),
                )
              else if (stopwatch.state == StopwatchState.running) ...[
                ElevatedButton(
                  onPressed: () => stopwatch.lap(),
                  child: Text(l10n.stopwatchLap),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => stopwatch.pause(),
                  child: Text(l10n.sessionPause),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () => stopwatch.start(),
                  child: Text(l10n.sessionResume),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => stopwatch.reset(),
                  child: Text(l10n.stopwatchReset),
                ),
              ],
            ],
          ),
          if (stopwatch.laps.isNotEmpty) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: stopwatch.laps.length,
                itemBuilder: (context, index) {
                  final lap = stopwatch.laps.reversed.toList()[index];
                  return ListTile(
                    title: Text(l10n.stopwatchLapNumber(lap.number), style: const TextStyle(color: AppColors.onSurfaceVariant)),
                    trailing: Text(stopwatch.formatLapTime(lap.totalMs), style: AppTypography.textTheme.labelLarge),
                  );
                },
              ),
            ),
          ]
        ],
      ),
    );
  }
}
