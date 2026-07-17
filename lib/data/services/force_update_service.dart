// lib/core/services/force_update_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';

class ForceUpdateService {
  final http.Client _client;

  ForceUpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Check for app version update.
  /// The update policy lives in the tenant's project config
  /// (GET /api/project-config → config.min_app_version etc.). Any failure
  /// results in "no update required" so the app never blocks on this.
  Future<UpdateCheckResponse> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _client.get(
        Uri.parse(
            '${ApiConstants.projectConfig}?project_code=${ApiConstants.projectCode}'),
        headers: {
          'Accept': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final config = decoded is Map &&
                decoded['data'] is Map &&
                (decoded['data'] as Map)['config'] is Map
            ? (decoded['data'] as Map)['config'] as Map
            : {};

        final minVersion = (config['min_app_version'] ?? '').toString();
        final latestVersion =
            (config['latest_app_version'] ?? minVersion).toString();
        final forceUpdate = minVersion.isNotEmpty &&
            _compareVersions(currentVersion, minVersion) < 0;

        final updateResponse = UpdateCheckResponse(
          latestVersion: latestVersion,
          minimumSupportedVersion: minVersion,
          forceUpdate: forceUpdate,
          updateMessage: (config['force_update_message'] ?? 'Please update your app')
              .toString(),
          androidDownloadUrl: (config['android_store_url'] ?? '').toString(),
          iosDownloadUrl: (config['ios_store_url'] ?? '').toString(),
          releaseNotes: '',
          maintenanceMode: '',
          maintenanceMessage: '',
        );

        debugPrint(
            'Force update check: current=$currentVersion min=$minVersion force=${updateResponse.forceUpdate}');
        return updateResponse;
      }

      debugPrint('Force update check failed (${response.statusCode}) — assuming no update');
      return UpdateCheckResponse.none();
    } catch (e) {
      debugPrint('Force update check error ($e) — assuming no update');
      return UpdateCheckResponse.none();
    }
  }

  /// Compare dotted version strings: negative if a < b.
  int _compareVersions(String a, String b) {
    final pa = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final pb = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  /// Open store URL for app update
  Future<bool> openUpdateUrl(String url) async {
    try {
      debugPrint('🔗 Attempting to open URL: $url');
      
      if (url.isEmpty) {
        debugPrint('❌ Empty URL provided');
        return false;
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        final result = await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('🔗 URL launch result: $result');
        return result;
      } else {
        debugPrint('❌ Cannot launch URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error opening update URL: $e');
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Response model for update check
class UpdateCheckResponse {
  final String latestVersion;
  final String minimumSupportedVersion;
  final bool forceUpdate;
  final String updateMessage;
  final String androidDownloadUrl;
  final String iosDownloadUrl;
  final String releaseNotes;
  final String maintenanceMode;
  final String maintenanceMessage;

  UpdateCheckResponse({
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.forceUpdate,
    required this.updateMessage,
    required this.androidDownloadUrl,
    required this.iosDownloadUrl,
    required this.releaseNotes,
    required this.maintenanceMode,
    required this.maintenanceMessage,
  });

  /// "No update required" default used when the check fails.
  factory UpdateCheckResponse.none() {
    return UpdateCheckResponse(
      latestVersion: '',
      minimumSupportedVersion: '',
      forceUpdate: false,
      updateMessage: '',
      androidDownloadUrl: '',
      iosDownloadUrl: '',
      releaseNotes: '',
      maintenanceMode: '',
      maintenanceMessage: '',
    );
  }

  factory UpdateCheckResponse.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResponse(
      latestVersion: json['latestVersion']?.toString() ?? '',
      minimumSupportedVersion: json['minimumSupportedVersion']?.toString() ?? '',
      forceUpdate: json['forceUpdate'] == true,
      updateMessage: json['updateMessage']?.toString() ?? 'Please update your app',
      androidDownloadUrl: json['androidDownloadUrl']?.toString() ?? '',
      iosDownloadUrl: json['iosDownloadUrl']?.toString() ?? '',
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      maintenanceMode: json['maintenanceMode']?.toString() ?? '',
      maintenanceMessage: json['maintenanceMessage']?.toString() ?? '',
    );
  }

  /// Get platform-specific download URL
  String get downloadUrl {
    final url = Platform.isAndroid ? androidDownloadUrl : iosDownloadUrl;
    debugPrint('🔗 Download URL Selection:');
    debugPrint('   └─ Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
    debugPrint('   └─ Android URL: $androidDownloadUrl');
    debugPrint('   └─ iOS URL: $iosDownloadUrl');
    debugPrint('   └─ Selected URL: $url');
    return url;
  }
}