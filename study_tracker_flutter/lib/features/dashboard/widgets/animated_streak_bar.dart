import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AnimatedStreakBar extends StatefulWidget {
  final double progress;
  
  const AnimatedStreakBar({Key? key, required this.progress}) : super(key: key);

  @override
  State<AnimatedStreakBar> createState() => _AnimatedStreakBarState();
}

class _AnimatedStreakBarState extends State<AnimatedStreakBar> with TickerProviderStateMixin {
  late final AnimationController _fillController;
  late final Animation<double> _fillAnimation;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    
    // Fill Animation
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Slower reload animation
    );
    _fillAnimation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeInOutCubic),
    );
    _fillController.forward();

    // Shimmer Animation (Sheen Pass)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );
    _shimmerController.repeat();
  }

  double get _curvedShimmerValue => CurvedAnimation(
    parent: _shimmerController,
    curve: Curves.easeInOut,
  ).value;

  @override
  void didUpdateWidget(AnimatedStreakBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _fillController.duration = const Duration(milliseconds: 1500);
      _fillAnimation = Tween<double>(
        begin: _fillAnimation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _fillController, curve: Curves.easeInOutCubic));
      _fillController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Track Background
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4E1).withOpacity(0.3), // Soft light red/orange tint
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        
        // The Glow (Fire/Amber)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              final currentProgress = _fillAnimation.value.clamp(0.0, 1.0);
              if (currentProgress == 0) return const SizedBox.shrink();
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: currentProgress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // The Fill + Shimmer
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              final currentProgress = _fillAnimation.value.clamp(0.0, 1.0);
              if (currentProgress == 0) return const SizedBox.shrink();
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: currentProgress,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      // Gradient Fill (Amber to Fire Red)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFF59E0B), // Amber
                              Color(0xFFEF4444), // Fire Red
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      // Specular highlight sweep ("sheen pass")
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _SheenPainter(
                                shimmerValue: _curvedShimmerValue,
                                isFull: currentProgress >= 1.0,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
class _SheenPainter extends CustomPainter {
  final double shimmerValue;
  final bool isFull;

  _SheenPainter({required this.shimmerValue, required this.isFull});

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width;
    final barHeight = size.height;
    
    final sheenCenter = barWidth * shimmerValue;
    final sheenWidth = barWidth * 0.135;
    
    // Clamp to filled region (which is size.width in this context because of FractionallySizedBox)
    final sheenStart = (sheenCenter - sheenWidth / 2).clamp(-1.0, barWidth + 1.0);
    final sheenEnd = (sheenCenter + sheenWidth / 2).clamp(-1.0, barWidth + 1.0);

    if (sheenEnd > sheenStart) {
      double alpha = 0.92;
      if (!isFull && shimmerValue > 0.96) {
        alpha = 0.92 * ((1.0 - shimmerValue) / 0.04).clamp(0.0, 1.0);
      }

      final spread = sheenWidth / 2 * 0.75;
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFFFFCDC).withOpacity(0.0),
            const Color(0xFFFFFCDC).withOpacity(alpha),
            const Color(0xFFFFFCDC).withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTRB(sheenCenter - spread, 0, sheenCenter + spread, barHeight));

      canvas.drawRect(Rect.fromLTRB(sheenStart, 0, sheenEnd, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SheenPainter oldDelegate) {
    return oldDelegate.shimmerValue != shimmerValue || oldDelegate.isFull != isFull;
  }
}
