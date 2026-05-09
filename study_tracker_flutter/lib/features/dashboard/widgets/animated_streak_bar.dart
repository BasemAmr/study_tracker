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
      duration: const Duration(milliseconds: 800),
    );
    _fillAnimation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeOut),
    );
    _fillController.forward();

    // Shimmer Animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _startShimmerLoop();
  }

  void _startShimmerLoop() async {
    while (mounted) {
      await _shimmerController.forward(from: 0.0);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500)); // Pause
    }
  }

  @override
  void didUpdateWidget(AnimatedStreakBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _fillController.duration = const Duration(milliseconds: 800);
      _fillAnimation = Tween<double>(
        begin: _fillAnimation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _fillController, curve: Curves.easeOut));
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
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Light grey/slate
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        
        // The Glow
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
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withOpacity(0.3),
                        blurRadius: 10,
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
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      // Gradient Fill
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF4ADE80), // Light Green
                              Color(0xFF22C55E), // Primary Green
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      // Shimmer highlight (The Glisten)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            return FractionalTranslation(
                              translation: Offset(_shimmerController.value * 3 - 1.5, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.4),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: const Alignment(-0.5, 0.0),
                                    end: const Alignment(0.5, 0.0),
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
