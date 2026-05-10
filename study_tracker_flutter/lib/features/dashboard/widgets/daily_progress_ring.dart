import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class DailyProgressRing extends StatefulWidget {
  final int deepWorkMinutes;
  final int dailyGoalMinutes;

  const DailyProgressRing({
    Key? key,
    required this.deepWorkMinutes,
    required this.dailyGoalMinutes,
  }) : super(key: key);

  @override
  State<DailyProgressRing> createState() => _DailyProgressRingState();
}

class _DailyProgressRingState extends State<DailyProgressRing> with TickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );
    
    // Looping with ease-in-out
    _shimmerController.repeat();
  }

  // Drive value through a curved animation
  double get _curvedShimmerValue => CurvedAnimation(
    parent: _shimmerController,
    curve: Curves.easeInOut,
  ).value;

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final double targetProgress = (widget.deepWorkMinutes / widget.dailyGoalMinutes).clamp(0.0, 1.0);
    
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.dailyObjectiveTitle,
              style: AppTypography.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetProgress),
            duration: const Duration(milliseconds: 2000), // Slow fill
            curve: Curves.easeInOutCubic,
            builder: (context, progress, child) {
              final int percentage = (progress * 100).toInt();
              return SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow background
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.15 * (progress > 0 ? 1 : 0)),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(160, 160),
                          painter: _ProgressRingPainter(
                            progress: progress,
                            shimmerValue: _curvedShimmerValue,
                            trackColor: const Color(0xFFFFE4E1).withOpacity(0.2),
                            progressColorStart: const Color(0xFFF59E0B),
                            progressColorEnd: const Color(0xFFEF4444),
                          ),
                        );
                      }
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
                                color: const Color(0xFF334155),
                              ),
                            ),
                            Text(
                              '%',
                              style: AppTypography.textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF64748B),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.completedLabel,
                          style: AppTypography.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.goalLabel,
                style: AppTypography.textTheme.labelMedium?.copyWith(color: const Color(0xFF64748B)),
              ),
              Text(
                '${widget.deepWorkMinutes ~/ 60}h ${widget.deepWorkMinutes % 60}m / ${widget.dailyGoalMinutes ~/ 60}h',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
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
  final double shimmerValue;
  final Color trackColor;
  final Color progressColorStart;
  final Color progressColorEnd;

  _ProgressRingPainter({
    required this.progress,
    required this.shimmerValue,
    required this.trackColor,
    required this.progressColorStart,
    required this.progressColorEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;
    const strokeWidth = 16.0;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final startAngle = -pi / 2;

      // Progress arc with Gradient
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [progressColorStart, progressColorEnd, progressColorStart],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(startAngle),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
        
      if (progress >= 1.0) {
        canvas.drawCircle(center, radius, progressPaint);
      } else {
        canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
      }

      // specular highlight sweep ("sheen pass")
      final sheenCenter = startAngle + sweepAngle * shimmerValue;
      final sheenWidth = sweepAngle * 0.135;
      final sheenStart = max(sheenCenter - sheenWidth / 2, startAngle) - 1 / radius;
      final sheenEnd = min(sheenCenter + sheenWidth / 2, startAngle + sweepAngle) + 1 / radius;

      if (sheenEnd > sheenStart) {
        double alpha = 0.92;
        final bool isFull = progress >= 1.0;
        if (!isFull && shimmerValue > 0.96) {
          alpha = 0.92 * ((1.0 - shimmerValue) / 0.04).clamp(0.0, 1.0);
        }

        final tx = center.dx + radius * cos(sheenCenter);
        final ty = center.dy + radius * sin(sheenCenter);
        
        // Perpendicular tangent for the gradient
        final tangentX = -sin(sheenCenter);
        final tangentY = cos(sheenCenter);
        final spread = radius * sheenWidth * 0.75;

        final sheenPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(tx - tangentX * spread, ty - tangentY * spread),
            Offset(tx + tangentX * spread, ty + tangentY * spread),
            [
              const Color(0xFFFFFCDC).withOpacity(0.0),
              const Color(0xFFFFFCDC).withOpacity(alpha),
              const Color(0xFFFFFCDC).withOpacity(0.0),
            ],
            [0.0, 0.5, 1.0],
          )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth;

        canvas.drawArc(
          rect,
          sheenStart,
          sheenEnd - sheenStart,
          false,
          sheenPaint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.shimmerValue != shimmerValue;
  }
}
