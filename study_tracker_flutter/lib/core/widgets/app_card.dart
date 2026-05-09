import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool smallShadow;
  final Color backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(24.0),
    this.borderRadius = 24.0, // xl by default
    this.smallShadow = false,
    this.backgroundColor = AppColors.surface,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final double shadowOffset = widget.smallShadow ? 2.0 : 4.0;
    final double currentOffset = _isPressed ? 0.0 : shadowOffset;
    final bool shouldAnimatePress = widget.onTap != null && isCurrentRoute;

    Widget cardContent = RepaintBoundary(
      child: AnimatedContainer(
        duration: shouldAnimatePress
            ? const Duration(milliseconds: 100)
            : Duration.zero,
        transform: Matrix4.translationValues(
          0,
          shouldAnimatePress && _isPressed ? shadowOffset : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: AppColors.outline,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.outline,
              offset: Offset(0, currentOffset),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
