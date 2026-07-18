import 'package:flutter/material.dart';
import '../branding/app_branding.dart';
import 'app_colors.dart';

/// Text style definitions in the tenant's font (admin-managed at runtime,
/// falling back to bundled Poppins). All members are getters so every call
/// site picks up the tenant font and text colors without code changes.
class AppTextStyles {
  /// The effective font family name (Google Fonts resolved, else Poppins).
  static String get fontFamily => AppBranding.instance.effectiveFontFamily;

  static TextStyle _styled(TextStyle base) =>
      AppBranding.instance.textStyle(base);

  // Heading Styles
  static TextStyle get h1 => _styled(TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        height: 1.3,
      ));

  static TextStyle get h2 => _styled(TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        height: 1.3,
      ));

  static TextStyle get h3 => _styled(TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
        height: 1.3,
      ));

  static TextStyle get h4 => _styled(TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
        height: 1.3,
      ));

  static TextStyle get h5 => _styled(TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0,
        color: AppColors.textPrimary,
        height: 1.3,
      ));

  static TextStyle get h6 => _styled(TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600, // SemiBold
        letterSpacing: 0,
        color: AppColors.textPrimary,
        height: 1.3,
      ));

  // Body Text Styles
  static TextStyle get bodyLarge => _styled(TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400, // Regular
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
        height: 1.5,
      ));

  static TextStyle get bodyMedium => _styled(TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400, // Regular
        letterSpacing: 0.25,
        color: AppColors.textPrimary,
        height: 1.5,
      ));

  static TextStyle get bodySmall => _styled(TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400, // Regular
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
        height: 1.5,
      ));

  // Label Styles
  static TextStyle get labelLarge => _styled(TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500, // Medium
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
        height: 1.4,
      ));

  static TextStyle get labelMedium => _styled(TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
        height: 1.4,
      ));

  static TextStyle get labelSmall => _styled(TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500, // Medium
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
        height: 1.4,
      ));

  // Button Styles
  static TextStyle get buttonLarge => _styled(TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500, // Medium
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
        height: 1.4,
      ));

  static TextStyle get buttonMedium => _styled(TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500, // Medium
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
        height: 1.4,
      ));

  static TextStyle get buttonSmall => _styled(TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
        height: 1.4,
      ));

  // Specialty Styles
  static TextStyle get caption => _styled(TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400, // Regular
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
        height: 1.3,
      ));

  static TextStyle get overline => _styled(TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w400, // Regular
        letterSpacing: 1.5,
        color: AppColors.textSecondary,
        height: 1.3,
        textBaseline: TextBaseline.alphabetic,
      ));

  // Additional font weight variations
  static TextStyle _weighted(
    FontWeight weight, {
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _styled(TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color ?? AppColors.textPrimary,
        height: height,
      ));

  static TextStyle thin({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w100,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle extraLight({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w200,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle light({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w300,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle regular({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w400,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle medium({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w500,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle semiBold({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w600,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle bold({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w700,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle extraBold({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w800,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static TextStyle black({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      _weighted(FontWeight.w900,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          height: height);
}
