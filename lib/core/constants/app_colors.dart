// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';
import '../branding/app_branding.dart';

/// App color palette. Brand-driven tokens are getters backed by AppBranding
/// so every tenant themes the whole app from the admin panel at runtime —
/// no hardcoded brand colors, no rebuild. Grayscale scaffolding (neutrals,
/// borders, shadows) stays constant.
class AppColors {
  static AppBranding get _b => AppBranding.instance;

  // Primary colors (tenant brand)
  static Color get primary => _b.primary;
  static Color get primaryLight => _b.primaryLight;
  static Color get primaryLighter => _b.primaryLighter;
  static Color get primaryDark => _b.primaryDark;
  static Color get primaryDarker => _b.primaryDarker;

  // Secondary colors (tenant brand)
  static Color get secondary => _b.secondary;
  static Color get secondaryLight => _b.secondaryLight;
  static Color get secondaryLighter => _b.secondaryLighter;
  static Color get secondaryDark => _b.secondaryDark;
  static Color get secondaryDarker => _b.secondaryDarker;

  // Accent color - for highlights and CTAs (tenant brand)
  static Color get accent => _b.accent;
  static Color get accentLight => _b.accentLight;
  static Color get accentDark => _b.accentDark;

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

  // Semantic Colors (tenant overridable)
  static Color get success => _b.success;
  static Color get successLight => _b.successLight;
  static Color get warning => _b.warning;
  static Color get warningLight => _b.warningLight;
  static Color get error => _b.error;
  static Color get errorLight => _b.errorLight;
  static Color get info => _b.info;
  static Color get infoLight => _b.infoLight;

  // Background Colors
  static Color get background => _b.background;
  static const Color cardBackground = white;
  static const Color surfaceBackground = white;
  static const Color disabledBackground = neutral200;

  // Text Colors (tenant overridable)
  static Color get textPrimary => _b.textPrimary;
  static Color get textSecondary => _b.textSecondary;
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

  // Gradients (derived from tenant brand)
  static LinearGradient get primaryGradient => LinearGradient(
        colors: [primary, primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
