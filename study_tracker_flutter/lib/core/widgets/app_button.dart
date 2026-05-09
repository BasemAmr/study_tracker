import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

enum AppButtonType {
  primary,
  secondary,
  outline,
  surface,
}

enum AppButtonSize {
  small,
  medium,
  large,
}

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final bool fullWidth;
  final bool isRounded;
  final bool smallShadow;

  const AppButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.fullWidth = false,
    this.isRounded = false,
    this.smallShadow = true,
  }) : super(key: key);

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) => setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onPressed();
  }
  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (widget.type) {
      case AppButtonType.primary:
        backgroundColor = AppColors.primary;
        textColor = AppColors.onPrimary;
        break;
      case AppButtonType.secondary:
        backgroundColor = AppColors.secondary;
        textColor = AppColors.onSurface;
        break;
      case AppButtonType.surface:
        backgroundColor = AppColors.surface;
        textColor = AppColors.onSurface;
        break;
      case AppButtonType.outline:
        backgroundColor = Colors.transparent;
        textColor = AppColors.onSurface;
        break;
    }

    final double shadowOffset = widget.smallShadow ? 2.0 : 4.0;
    final double currentOffset = _isPressed ? 0.0 : shadowOffset;
    final double borderRadius = widget.isRounded ? 9999.0 : 12.0;

    Widget buttonContent = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      transform: Matrix4.translationValues(0, _isPressed ? shadowOffset : 0, 0),
      padding: widget.size == AppButtonSize.small 
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : (widget.size == AppButtonSize.large 
              ? const EdgeInsets.symmetric(horizontal: 32, vertical: 18)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.outline,
          width: 2.0,
        ),
        boxShadow: [
          if (widget.type != AppButtonType.outline)
            BoxShadow(
              color: AppColors.outline,
              offset: Offset(0, currentOffset),
              blurRadius: 0,
              spreadRadius: 0,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: textColor, size: widget.size == AppButtonSize.small ? 16 : 20),
            SizedBox(width: widget.size == AppButtonSize.small ? 6 : 8),
          ],
          Text(
            widget.text,
            style: (widget.size == AppButtonSize.small 
              ? AppTypography.textTheme.labelSmall 
              : AppTypography.textTheme.labelLarge)?.copyWith(
              color: textColor,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: buttonContent,
    );
  }
}
