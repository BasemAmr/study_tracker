import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class AppBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const AppBadge({
    Key? key,
    required this.text,
    this.backgroundColor = AppColors.secondaryContainer,
    this.textColor = AppColors.onSurface,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.outline,
          width: 2.0,
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
