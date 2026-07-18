import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/branding/app_branding.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';

void main() {
  test('applyConfig themes the whole design system from a config map', () {
    AppBranding.applyConfig({
      'app_name': 'Grahak Peth',
      'primary_color': '#2E7D32',
      'secondary_color': '#FF8F00',
      'accent_color': '#FFAB40',
      'background_color': '#FFFFFF',
      'text_primary_color': '#101010',
      'font_family': 'Poppins',
      'logo_url': 'https://example.com/logo.png',
    }, clientName: 'Grahak Peth');

    expect(AppColors.primary, const Color(0xFF2E7D32));
    expect(AppColors.secondary, const Color(0xFFFF8F00));
    expect(AppColors.accent, const Color(0xFFFFAB40));
    expect(AppColors.background, const Color(0xFFFFFFFF));
    expect(AppColors.textPrimary, const Color(0xFF101010));
    expect(AppBranding.instance.appName, 'Grahak Peth');
    expect(AppBranding.instance.logoUrl, 'https://example.com/logo.png');

    // Derived shades follow the base color
    expect(AppColors.primaryDark, isNot(AppColors.primary));
    expect(AppColors.primaryGradient.colors.first, AppColors.primary);

    // Text styles carry the brand text color + Poppins family
    expect(AppTextStyles.h1.color, const Color(0xFF101010));
    expect(AppTextStyles.h1.fontFamily, 'Poppins');
  });

  test('unset/invalid values fall back to built-in defaults', () {
    AppBranding.applyConfig({
      'primary_color': 'not-a-color',
      'app_name': '',
    });

    expect(AppColors.primary, const Color(0xFF77318B)); // built-in default
    expect(AppBranding.instance.appName, 'Patel Mart');
    expect(AppTextStyles.fontFamily, 'Poppins');
  });

  test('semantic colors are tenant-overridable with pastel derivation', () {
    AppBranding.applyConfig({'error_color': '#B00020'});
    expect(AppColors.error, const Color(0xFFB00020));
    final light = HSLColor.fromColor(AppColors.errorLight);
    expect(light.lightness, closeTo(0.90, 0.01));
  });
}
