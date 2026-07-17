// lib/data/repositories/project_config_repository.dart
//
// Runtime branding for the universal multi-tenant app: fetches the tenant's
// public config (GET /api/project-config) at boot and caches it in
// SharedPreferences so the app can brand itself offline on later launches.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class ProjectConfig {
  final String projectCode;
  final String clientName;
  final String appName;
  final String logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final String contactEmail;
  final String contactPhone;

  const ProjectConfig({
    required this.projectCode,
    required this.clientName,
    required this.appName,
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.contactEmail,
    required this.contactPhone,
  });

  factory ProjectConfig.fromJson(Map<String, dynamic> json) {
    final config = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : <String, dynamic>{};
    return ProjectConfig(
      projectCode: (json['project_code'] ?? '').toString(),
      clientName: (json['client_name'] ?? '').toString(),
      appName: (config['app_name'] ?? '').toString(),
      logoUrl: (config['logo_url'] ?? '').toString(),
      primaryColor: (config['primary_color'] ?? '').toString(),
      secondaryColor: (config['secondary_color'] ?? '').toString(),
      contactEmail: (config['contact_email'] ?? '').toString(),
      contactPhone: (config['contact_phone'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        'client_name': clientName,
        'config': {
          'app_name': appName,
          'logo_url': logoUrl,
          'primary_color': primaryColor,
          'secondary_color': secondaryColor,
          'contact_email': contactEmail,
          'contact_phone': contactPhone,
        },
      };

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
}

class ProjectConfigRepository {
  static const String _cacheKey = 'project_config_cache';
  final http.Client _client;

  ProjectConfigRepository({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch config from the backend, falling back to the cached copy.
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
  Future<ProjectConfig?> readCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return ProjectConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
