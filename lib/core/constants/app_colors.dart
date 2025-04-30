// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

/// App color palette constants
class AppColors {
  // Primary Colors - Updated to match the screenshot (deep purple)
  static const Color primary = Color(0xFF77318B);
  static const Color primaryLight = Color(0xFF9B4FB0);
  static const Color primaryLighter = Color(0xFFBF7DD0);
  static const Color primaryDark = Color(0xFF5A2269);
  static const Color primaryDarker = Color(0xFF3D1647);

  // Secondary Colors - Complementary to purple
  static const Color secondary = Color(0xFF428B31);
  static const Color secondaryLight = Color(0xFF6AB04C);
  static const Color secondaryLighter = Color(0xFF97D07D);
  static const Color secondaryDark = Color(0xFF2F6923);
  static const Color secondaryDarker = Color(0xFF1C4614);

  // Accent color - For highlights and CTAs
  static const Color accent = Color(0xFFFFAB40); 
  static const Color accentLight = Color(0xFFFFBF6F);
  static const Color accentDark = Color(0xFFE59323);

  // Neutral Colors
  static const Color neutral900 = Color(0xFF212121); // For primary text
  static const Color neutral800 = Color(0xFF424242); // For secondary text
  static const Color neutral700 = Color(0xFF616161); // For tertiary text
  static const Color neutral600 = Color(0xFF757575);
  static const Color neutral500 = Color(0xFF9E9E9E); // For disabled text
  static const Color neutral400 = Color(0xFFBDBDBD); // For borders
  static const Color neutral300 = Color(0xFFE0E0E0); // For dividers
  static const Color neutral200 = Color(0xFFEEEEEE); // For backgrounds
  static const Color neutral100 = Color(0xFFF5F5F5); // For card backgrounds
  static const Color neutral50 = Color(0xFFFAFAFA);  // For page backgrounds
  static const Color white = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFD8F3D9);
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFF3D6);
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFE5E3);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFD1ECFF);

  // Background Colors
  static const Color background = neutral50;
  static const Color cardBackground = white;
  static const Color surfaceBackground = white;
  static const Color disabledBackground = neutral200;

  // Text Colors
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral700;
  static const Color textHint = neutral500;
  static const Color textDisabled = neutral400;
  static const Color textOnPrimary = white;
  static const Color textOnSecondary = white;
  static const Color textOnAccent = neutral900;

  // Border Colors
  static const Color border = neutral300;
  static const Color borderLight = neutral200;
  static const Color borderDark = neutral400;

  // Shadow Colors
  static const Color shadow = Color(0x40000000);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}