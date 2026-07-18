// lib/core/branding/app_branding.dart
//
// Single source of truth for runtime branding. Every design token the app
// uses (colors, font, logos, app name) lives here and is overridable per
// tenant from the admin panel via GET /api/project-config — no rebuild
// needed. AppColors / AppTextStyles delegate to this singleton, so all
// existing call sites pick up tenant branding automatically.
//
// Lifecycle:
//   1. main() applies the cached config (SharedPreferences) BEFORE runApp so
//      the very first frame is branded.
//   2. ProjectConfigRepository.fetchProjectConfig() re-applies the fresh
//      config; the root widget watches projectConfigProvider and rebuilds.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBranding {
  AppBranding._();

  static final AppBranding instance = AppBranding._();

  // ---- Built-in defaults (legacy PatelMart identity) ----
  static const Color _defPrimary = Color(0xFF77318B);
  static const Color _defSecondary = Color(0xFF428B31);
  static const Color _defAccent = Color(0xFFFFAB40);
  static const Color _defBackground = Color(0xFFFAFAFA);
  static const Color _defTextPrimary = Color(0xFF212121);
  static const Color _defTextSecondary = Color(0xFF616161);
  static const Color _defSuccess = Color(0xFF4CAF50);
  static const Color _defWarning = Color(0xFFFFC107);
  static const Color _defError = Color(0xFFF44336);
  static const Color _defInfo = Color(0xFF2196F3);
  static const String _defFontFamily = 'Poppins';
  static const String _defAppName = 'Patel Mart';

  // ---- Current values (mutated by applyConfig) ----
  Color primary = _defPrimary;
  Color secondary = _defSecondary;
  Color accent = _defAccent;
  Color background = _defBackground;
  Color textPrimary = _defTextPrimary;
  Color textSecondary = _defTextSecondary;
  Color success = _defSuccess;
  Color warning = _defWarning;
  Color error = _defError;
  Color info = _defInfo;

  /// Google Fonts family name; empty = bundled Poppins.
  String fontFamily = '';
  String appName = _defAppName;
  String logoUrl = '';
  String splashLogoUrl = '';

  /// Apply a project-config `config` map (raw backend keys). Unset/invalid
  /// values fall back to the built-in defaults so a partially configured
  /// tenant still renders correctly.
  static void applyConfig(Map<String, dynamic> config,
      {String? clientName}) {
    final b = instance;
    b.primary = _hex(config['primary_color']) ?? _defPrimary;
    b.secondary = _hex(config['secondary_color']) ?? _defSecondary;
    b.accent = _hex(config['accent_color']) ?? _defAccent;
    b.background = _hex(config['background_color']) ?? _defBackground;
    b.textPrimary = _hex(config['text_primary_color']) ?? _defTextPrimary;
    b.textSecondary =
        _hex(config['text_secondary_color']) ?? _defTextSecondary;
    b.success = _hex(config['success_color']) ?? _defSuccess;
    b.warning = _hex(config['warning_color']) ?? _defWarning;
    b.error = _hex(config['error_color']) ?? _defError;
    b.info = _hex(config['info_color']) ?? _defInfo;
    b.fontFamily = (config['font_family'] ?? '').toString().trim();
    b.logoUrl = (config['logo_url'] ?? '').toString().trim();
    b.splashLogoUrl = (config['splash_logo_url'] ?? '').toString().trim();

    final name = (config['app_name'] ?? '').toString().trim();
    b.appName = name.isNotEmpty
        ? name
        : (clientName ?? '').trim().isNotEmpty
            ? clientName!.trim()
            : _defAppName;
  }

  // ---- Derived shades (computed so admins only pick base colors) ----
  Color get primaryLight => _shade(primary, 0.14);
  Color get primaryLighter => _shade(primary, 0.28);
  Color get primaryDark => _shade(primary, -0.12);
  Color get primaryDarker => _shade(primary, -0.24);

  Color get secondaryLight => _shade(secondary, 0.14);
  Color get secondaryLighter => _shade(secondary, 0.28);
  Color get secondaryDark => _shade(secondary, -0.12);
  Color get secondaryDarker => _shade(secondary, -0.24);

  Color get accentLight => _shade(accent, 0.12);
  Color get accentDark => _shade(accent, -0.12);

  Color get successLight => _pastel(success);
  Color get warningLight => _pastel(warning);
  Color get errorLight => _pastel(error);
  Color get infoLight => _pastel(info);

  /// Resolve a text style in the tenant font. Unknown/unavailable Google
  /// Fonts families fall back to the bundled Poppins.
  TextStyle textStyle(TextStyle base) {
    final family = fontFamily;
    if (family.isEmpty || family == _defFontFamily) {
      return base.copyWith(fontFamily: _defFontFamily);
    }
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } catch (_) {
      return base.copyWith(fontFamily: _defFontFamily);
    }
  }

  /// The effective font family name for callers that need a raw string.
  String get effectiveFontFamily {
    final family = fontFamily;
    if (family.isEmpty) return _defFontFamily;
    try {
      return GoogleFonts.getFont(family).fontFamily ?? _defFontFamily;
    } catch (_) {
      return _defFontFamily;
    }
  }

  static Color? _hex(dynamic raw) {
    if (raw == null) return null;
    final cleaned = raw.toString().replaceFirst('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return null;
    final value =
        int.tryParse(cleaned.length == 6 ? 'ff$cleaned' : cleaned, radix: 16);
    return value == null ? null : Color(value);
  }

  /// Shift lightness by [amount] (-1..1) keeping hue/saturation.
  static Color _shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Very light tint used for badge/alert backgrounds.
  static Color _pastel(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(0.90).withSaturation(0.55).toColor();
  }
}
