import 'package:flutter/material.dart';

class R {
  // Breakpoints
  static const double mobilePortraitMaxWidth = 600;
  static const double tabletPortraitMaxWidth = 900;
  // Based on these, anything above 900 is considered tablet landscape or desktop.
  // Actually, usually:
  // < 600: Phone Portrait
  // 600 - 900: Phone Landscape / Tablet Portrait
  // > 900: Tablet Landscape / Desktop

  static bool isPhonePortrait(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < mobilePortraitMaxWidth;
  }

  static bool isPhoneLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= mobilePortraitMaxWidth && size.width < tabletPortraitMaxWidth && size.width > size.height;
  }

  static bool isTabletPortrait(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= mobilePortraitMaxWidth && size.width < tabletPortraitMaxWidth && size.height > size.width;
  }

  static bool isTabletLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= tabletPortraitMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    return isTabletPortrait(context) || isTabletLandscape(context);
  }

  static bool isPhone(BuildContext context) {
    return isPhonePortrait(context) || isPhoneLandscape(context);
  }
  
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Common Layout Spacing Constants
  static double get defaultPadding => 24.0;
  static double get cardPadding => 24.0;
  static double get smallPadding => 16.0;
}
