import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Text style definitions using Poppins font
class AppTextStyles {
  // The base font family
  static const String fontFamily = 'Poppins';
  
  // Heading Styles
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h5 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: 0,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h6 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: 0,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  // Body Text Styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.15,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.25,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  
  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  // Button Styles
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
    color: AppColors.textOnPrimary,
    height: 1.4,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
    color: AppColors.textOnPrimary,
    height: 1.4,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
    color: AppColors.textOnPrimary,
    height: 1.4,
  );
  
  // Specialty Styles
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
    height: 1.3,
  );
  
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
    height: 1.3,
    textBaseline: TextBaseline.alphabetic,
  );
  
  // Additional font weight variations
  static TextStyle thin({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w100, // Thin
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle extraLight({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w200, // ExtraLight
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle light({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w300, // Light
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle regular({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w400, // Regular
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle medium({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle semiBold({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w600, // SemiBold
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle bold({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w700, // Bold
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle extraBold({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w800, // ExtraBold
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
  
  static TextStyle black({
    double? fontSize,
    Color? color,
    double? letterSpacing, 
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w900, // Black
    letterSpacing: letterSpacing,
    color: color ?? AppColors.textPrimary,
    height: height,
  );
}