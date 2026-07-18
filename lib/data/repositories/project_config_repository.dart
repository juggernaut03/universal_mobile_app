// lib/data/repositories/project_config_repository.dart
//
// Runtime branding for the universal multi-tenant app: fetches the tenant's
// public config (GET /api/project-config) at boot and caches it in
// SharedPreferences so the app can brand itself offline on later launches.
// Every apply also updates the AppBranding singleton, which AppColors /
// AppTextStyles read — so the whole design system follows the admin panel.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/branding/app_branding.dart';
import '../../core/constants/app_constants.dart';

class ProjectConfig {
  final String projectCode;
  final String clientName;

  /// Raw backend config map — cached verbatim so newly added backend fields
  /// survive the cache round-trip without app changes.
  final Map<String, dynamic> config;

  const ProjectConfig({
    required this.projectCode,
    required this.clientName,
    required this.config,
  });

  factory ProjectConfig.fromJson(Map<String, dynamic> json) {
    return ProjectConfig(
      projectCode: (json['project_code'] ?? '').toString(),
      clientName: (json['client_name'] ?? '').toString(),
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'client_name': clientName,
        'config': config,
      };

  String _str(String key) => (config[key] ?? '').toString();

  String get appName => _str('app_name');
  String get logoUrl => _str('logo_url');
  String get splashLogoUrl => _str('splash_logo_url');
  String get primaryColor => _str('primary_color');
  String get secondaryColor => _str('secondary_color');
  String get fontFamily => _str('font_family');
  String get contactEmail => _str('contact_email');
  String get contactPhone => _str('contact_phone');

  /// Display title with build-time fallback
  String get displayName => appName.isNotEmpty
      ? appName
      : clientName.isNotEmpty
          ? clientName
          : 'Patel Mart';

  /// Parsed primary color, or null when unset/invalid
  Color? get primarySeedColor => _parseHexColor(primaryColor);
  Color? get secondarySeedColor => _parseHexColor(secondaryColor);

  static Color? _parseHexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return null;
    final value = int.tryParse(cleaned.length == 6 ? 'ff$cleaned' : cleaned,
        radix: 16);
    return value == null ? null : Color(value);
  }

  /// Push this config into the AppBranding singleton (design system).
  void applyBranding() =>
      AppBranding.applyConfig(config, clientName: clientName);
}

class ProjectConfigRepository {
  static const String _cacheKey = 'project_config_cache';
  final http.Client _client;

  ProjectConfigRepository({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch config from the backend, falling back to the cached copy.
  /// Applies branding as a side effect.
  Future<ProjectConfig?> fetchProjectConfig() async {
    try {
      final response = await _client.get(
        Uri.parse(
            '${ApiConstants.projectConfig}?project_code=${ApiConstants.projectCode}'),
        headers: {
          'Accept': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is Map) {
          final config = ProjectConfig.fromJson(
              Map<String, dynamic>.from(decoded['data'] as Map));
          config.applyBranding();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
          return config;
        }
      }
    } catch (_) {
      // fall through to cache
    }
    return readCachedConfig();
  }

  /// Cached copy for offline/instant start (null if never fetched).
  /// Applies branding as a side effect.
  Future<ProjectConfig?> readCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final config =
          ProjectConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      config.applyBranding();
      return config;
    } catch (_) {
      return null;
    }
  }

  /// Synchronous variant for main() — SharedPreferences must already be
  /// initialized. Brands the very first frame from the cached config.
  static ProjectConfig? applyCachedBranding(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final config =
          ProjectConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      config.applyBranding();
      return config;
    } catch (_) {
      return null;
    }
  }
}

final projectConfigRepositoryProvider = Provider<ProjectConfigRepository>((ref) {
  return ProjectConfigRepository();
});

/// Tenant branding config, fetched at boot with SharedPreferences fallback.
final projectConfigProvider = FutureProvider<ProjectConfig?>((ref) async {
  final repository = ref.watch(projectConfigRepositoryProvider);
  return repository.fetchProjectConfig();
});
