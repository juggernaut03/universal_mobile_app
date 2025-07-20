// lib/core/services/force_update_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateService {
  static const String _baseUrl = 'https://newtech.shalviadvision.com/api';
  final http.Client _client;

  ForceUpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Check for app version update
  Future<UpdateCheckResponse> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final platform = Platform.isAndroid ? 'Android' : 'iOS';

      // Prepare request body
      final requestBody = {
        'mobile_platform': platform,
        'current_ver': currentVersion,
      };

      // DEBUG: Print request details
      debugPrint('🚀 FORCE UPDATE API CALL:');
      debugPrint('📍 URL: $_baseUrl/check_app_version');
      debugPrint('📱 Platform: $platform');
      debugPrint('🔢 Current Version: $currentVersion');
      debugPrint('📦 Request Body: ${json.encode(requestBody)}');
      debugPrint('=' * 50);

      // Make API call
      final response = await _client.post(
        Uri.parse('$_baseUrl/check_app_version'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      // DEBUG: Print response details
      debugPrint('📥 FORCE UPDATE API RESPONSE:');
      debugPrint('🔍 Status Code: ${response.statusCode}');
      debugPrint('📄 Response Headers: ${response.headers}');
      debugPrint('📝 Response Body: ${response.body}');
      debugPrint('=' * 50);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final updateResponse = UpdateCheckResponse.fromJson(data);
        
        // DEBUG: Print parsed response
        debugPrint('✅ PARSED FORCE UPDATE RESPONSE:');
        debugPrint('🔄 Force Update Required: ${updateResponse.forceUpdate}');
        debugPrint('📱 Latest Version: ${updateResponse.latestVersion}');
        debugPrint('⚠️ Minimum Version: ${updateResponse.minimumSupportedVersion}');
        debugPrint('💬 Update Message: ${updateResponse.updateMessage}');
        debugPrint('🔗 Android Download URL: ${updateResponse.androidDownloadUrl}');
        debugPrint('🔗 iOS Download URL: ${updateResponse.iosDownloadUrl}');
        debugPrint('🔗 Selected Download URL: ${updateResponse.downloadUrl}');
        debugPrint('=' * 50);
        
        return updateResponse;
      } else {
        debugPrint('❌ FORCE UPDATE API ERROR:');
        debugPrint('🔍 Status Code: ${response.statusCode}');
        debugPrint('📝 Response Body: ${response.body}');
        debugPrint('=' * 50);
        throw Exception('Failed to check app version: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 FORCE UPDATE EXCEPTION:');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack Trace: ${StackTrace.current}');
      debugPrint('=' * 50);
      throw Exception('Error checking for app update: $e');
    }
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