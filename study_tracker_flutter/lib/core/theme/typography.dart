import 'package:flutter/material.dart';
import 'colors.dart';

class AppTypography {
  static const String headlineFont = 'Space Grotesk';
  static const String bodyFont = 'Plus Jakarta Sans';
  static const String monoFont = 'JetBrains Mono';
  static const String arabicFont = 'Tajawal';
  static bool _activeArabic = false;

  static void setLocale({required bool isArabic}) {
    _activeArabic = isArabic;
  }

  static TextTheme get textTheme => textThemeFor(isArabic: _activeArabic);

  static TextTheme textThemeFor({required bool isArabic}) {
    final heading = isArabic ? arabicFont : headlineFont;
    final body = isArabic ? arabicFont : bodyFont;
    final label = isArabic ? arabicFont : monoFont;

    return TextTheme(
      displayLarge: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 57, letterSpacing: -0.25),
      displayMedium: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 45),
      displaySmall: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 36),
      headlineLarge: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 32),
      headlineMedium: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 28),
      headlineSmall: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 24),
      titleLarge: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 22),
      titleMedium: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 18),
      titleSmall: TextStyle(fontFamily: heading, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 14),
      bodyLarge: TextStyle(fontFamily: body, fontWeight: FontWeight.w400, color: AppColors.onSurface, fontSize: 16),
      bodyMedium: TextStyle(fontFamily: body, fontWeight: FontWeight.w400, color: AppColors.onSurface, fontSize: 14),
      bodySmall: TextStyle(fontFamily: body, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant, fontSize: 12),
      labelLarge: TextStyle(fontFamily: label, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 14),
      labelMedium: TextStyle(fontFamily: label, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 12),
      labelSmall: TextStyle(fontFamily: label, fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 10, letterSpacing: 0.5),
    );
  }
}
