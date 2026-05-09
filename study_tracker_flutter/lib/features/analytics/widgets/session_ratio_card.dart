import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../l10n/app_localizations.dart';

class SessionRatioCard extends ConsumerWidget {
  const SessionRatioCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final chart = _buildDonutChart(provider.studyRatio, provider.breakRatio);

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRatioText(context, l10n, provider.studyRatio, provider.breakRatio),
                    const SizedBox(height: 20),
                    Center(child: chart),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildRatioText(context, l10n, provider.studyRatio, provider.breakRatio),
                    ),
                    const SizedBox(width: 16),
                    chart,
                  ],
                );
        },
      ),
    );
  }

  Widget _buildRatioText(
    BuildContext context,
    AppLocalizations l10n,
    double studyRatio,
    double breakRatio,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.analyticsSessionRatioTitle,
          style: AppTypography.textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.analyticsSessionRatioSubtitle,
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _buildLegendItem(
          l10n.analyticsFocusRatio(studyRatio.toStringAsFixed(0)),
          AppColors.primary,
        ),
        const SizedBox(height: 8),
        _buildLegendItem(
          l10n.analyticsBreakRatio(breakRatio.toStringAsFixed(0)),
          AppColors.secondary,
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.textTheme.labelMedium?.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(double studyRatio, double breakRatio) {
    final clampedStudy = studyRatio.clamp(0, 100).toDouble();
    final clampedBreak = breakRatio.clamp(0, 100).toDouble();
    final breakSweep = 2 * pi * (clampedBreak / 100);
    final ratioText = clampedBreak <= 0
        ? '${clampedStudy.toStringAsFixed(0)}:0'
        : '${(clampedStudy / clampedBreak).toStringAsFixed(1)}:1';

    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary,
            spreadRadius: 12,
          ),
          BoxShadow(
            color: AppColors.outline,
            spreadRadius: 16,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(120, 120),
            painter: _DonutSlicePainter(
              startAngle: -pi / 2,
              sweepAngle: breakSweep,
              color: AppColors.secondary,
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outline, width: 4),
            ),
            child: Center(
              child: Text(
                ratioText,
                style: AppTypography.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutSlicePainter extends CustomPainter {
  final double startAngle;
  final double sweepAngle;
  final Color color;

  _DonutSlicePainter({
    required this.startAngle,
    required this.sweepAngle,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16; // width of the slice

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _DonutSlicePainter oldDelegate) {
    return oldDelegate.startAngle != startAngle || oldDelegate.sweepAngle != sweepAngle;
  }
}
