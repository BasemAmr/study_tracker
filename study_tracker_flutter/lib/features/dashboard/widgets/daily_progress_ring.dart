import 'package:flutter/material.dart';
import 'dart:math';
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
      duration: const Duration(seconds: 3),
    )..repeat();
  }

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
            duration: const Duration(milliseconds: 3500), // Slow fill
            curve: Curves.easeInCubic, // Slow at first, fast at finish
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
                            color: const Color(0xFFEF4444).withOpacity(0.2 * (progress > 0 ? 1 : 0)),
                            blurRadius: 40,
                            spreadRadius: 8,
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
                            shimmerValue: _shimmerController.value,
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
        ..shader = LinearGradient(
          colors: [progressColorStart, progressColorEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
        
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

      // Organic Shimmer Effect (No 'Hotdog' look)
      final shimmerPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.6), // Softer glint
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.0),
          ],
          stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
          transform: GradientRotation(startAngle + (sweepAngle * shimmerValue)),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0) // Soft edges
        ..strokeWidth = strokeWidth + 1;

      canvas.save();
      final clipPath = Path()..addArc(rect, startAngle, sweepAngle);
      canvas.clipPath(clipPath);
      canvas.drawArc(rect, startAngle, sweepAngle, false, shimmerPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.shimmerValue != shimmerValue;
  }
}
