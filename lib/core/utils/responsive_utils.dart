import 'package:flutter/material.dart';

/// Responsive utilities to help make the app look good on all screen sizes
class ResponsiveUtils {
  /// Returns a value based on screen size breakpoints
  static double getResponsiveValue({
    required BuildContext context,
    required double small,
    required double medium,
    required double large,
  }) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return small;
    if (screenWidth < 900) return medium;
    return large;
  }

  /// Check if the current screen size is considered small
  static bool isSmall(BuildContext context) => 
      MediaQuery.of(context).size.width < 600;
      
  /// Check if the current screen size is considered medium
  static bool isMedium(BuildContext context) => 
      MediaQuery.of(context).size.width >= 600 && 
      MediaQuery.of(context).size.width < 900;
      
  /// Check if the current screen size is considered large
  static bool isLarge(BuildContext context) => 
      MediaQuery.of(context).size.width >= 900;

  /// Get padding that scales with screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.width * 0.05,
      vertical: MediaQuery.of(context).size.height * 0.02,
    );
  }
}