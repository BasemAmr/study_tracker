import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData light({required bool isArabic}) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: isArabic ? AppTypography.arabicFont : AppTypography.bodyFont,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textThemeFor(isArabic: isArabic),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  static ThemeData dark({required bool isArabic}) {
    // Basic dark theme for now using primary accent
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: isArabic ? AppTypography.arabicFont : AppTypography.bodyFont,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      textTheme: AppTypography.textThemeFor(isArabic: isArabic),
    );
  }
}
