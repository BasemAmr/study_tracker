import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class DailyProgressRing extends StatelessWidget {
  final int deepWorkMinutes;
  final int dailyGoalMinutes;

  const DailyProgressRing({
    Key? key,
    required this.deepWorkMinutes,
    required this.dailyGoalMinutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final double progress = (deepWorkMinutes / dailyGoalMinutes).clamp(0.0, 1.0);
    final int percentage = (progress * 100).toInt();
    
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.dailyObjectiveTitle,
              style: AppTypography.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(160, 160),
                  painter: _ProgressRingPainter(
                    progress: progress,
                    trackColor: AppColors.surfaceContainerHigh,
                    progressColor: AppColors.primary,
                    outlineColor: AppColors.outline,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$percentage',
                          style: AppTypography.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '%',
                          style: AppTypography.textTheme.headlineSmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.completedLabel,
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.goalLabel,
                style: AppTypography.textTheme.labelMedium,
              ),
              Text(
                '${deepWorkMinutes ~/ 60}h ${deepWorkMinutes % 60}m / ${dailyGoalMinutes ~/ 60}h',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final Color outlineColor;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10; // Padding
    const strokeWidth = 16.0;

    // Background track outline
    final trackOutlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4;
    canvas.drawCircle(center, radius, trackOutlinePaint);

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc outline
    final progressOutlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth + 4;
      
    final sweepAngle = 2 * pi * progress;
    final startAngle = -pi / 2;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressOutlinePaint,
      );

      // Progress arc
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
        
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
