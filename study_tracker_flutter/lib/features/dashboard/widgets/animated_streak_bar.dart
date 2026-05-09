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

    // Shimmer Animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Faster, more active shimmer
    );
    _startShimmerLoop();
  }

  void _startShimmerLoop() async {
    while (mounted) {
      await _shimmerController.forward(from: 0.0);
      if (!mounted) return;
      // No delay for infinite glistening feel
    }
  }

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
                      // Shimmer highlight (High-Prominence Glisten)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            return FractionalTranslation(
                              translation: Offset(_shimmerController.value * 4 - 2, 0),
                              child: Transform.rotate(
                                angle: 0.5, // Tilted shimmer
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.7), // More prominent
                                        Colors.white.withOpacity(0.0),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
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
