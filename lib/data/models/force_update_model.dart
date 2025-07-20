// lib/data/models/force_update_model.dart

import 'dart:io';

class ForceUpdateRequest {
  final String mobilePlatform;
  final String currentVersion;

  const ForceUpdateRequest({
    required this.mobilePlatform,
    required this.currentVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobile_platform': mobilePlatform,
      'current_ver': currentVersion,
    };
  }
}

class ForceUpdateResponse {
  final String latestVersion;
  final String reviewVersion;
  final String minimumSupportedVersion;
  final bool forceUpdate;
  final String updateMessage;
  final String downloadUrl; // Generic download URL (fallback)
  final String androidDownloadUrl;
  final String iosDownloadUrl;
  final String releaseNotes;
  final String maintenanceMode;
  final String maintenanceMessage;

  const ForceUpdateResponse({
    required this.latestVersion,
    required this.reviewVersion,
    required this.minimumSupportedVersion,
    required this.forceUpdate,
    required this.updateMessage,
    required this.downloadUrl,
    required this.androidDownloadUrl,
    required this.iosDownloadUrl,
    required this.releaseNotes,
    required this.maintenanceMode,
    required this.maintenanceMessage,
  });

  factory ForceUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ForceUpdateResponse(
      latestVersion: json['latestVersion']?.toString() ?? '',
      reviewVersion: json['reviewVersion']?.toString() ?? '',
      minimumSupportedVersion: json['minimumSupportedVersion']?.toString() ?? '',
      forceUpdate: json['forceUpdate'] == true,
      updateMessage: json['updateMessage']?.toString() ?? 'Please update your app',
      downloadUrl: json['DownloadUrl']?.toString() ?? '', // Generic fallback
      androidDownloadUrl: json['androidDownloadUrl']?.toString() ?? '',
      iosDownloadUrl: json['iosDownloadUrl']?.toString() ?? '',
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      maintenanceMode: json['maintenanceMode']?.toString() ?? '',
      maintenanceMessage: json['maintenanceMessage']?.toString() ?? '',
    );
  }

  /// Get platform-specific download URL with fallback logic
  String get platformSpecificDownloadUrl {
    String url;
    
    if (Platform.isAndroid) {
      // For Android, prefer androidDownloadUrl, fallback to generic downloadUrl
      url = androidDownloadUrl.isNotEmpty ? androidDownloadUrl : downloadUrl;
    } else {
      // For iOS, prefer iosDownloadUrl, fallback to generic downloadUrl
      url = iosDownloadUrl.isNotEmpty ? iosDownloadUrl : downloadUrl;
    }
    
    return url;
  }

  /// Check if app is in maintenance mode
  bool get isInMaintenanceMode {
    return maintenanceMode.toLowerCase() == 'true' || 
           maintenanceMode.toLowerCase() == 'yes' ||
           maintenanceMode == '1';
  }

  /// Get user-friendly maintenance message
  String get displayMaintenanceMessage {
    return maintenanceMessage.isNotEmpty 
        ? maintenanceMessage 
        : 'The app is currently under maintenance. Please try again later.';
  }

  /// Check if this is a critical update (force update required)
  bool get isCriticalUpdate {
    return forceUpdate;
  }

  /// Get update priority level
  UpdatePriority get updatePriority {
    if (forceUpdate) {
      return UpdatePriority.critical;
    } else if (latestVersion != reviewVersion) {
      return UpdatePriority.recommended;
    } else {
      return UpdatePriority.optional;
    }
  }
}

enum UpdatePriority {
  optional,
  recommended,
  critical,
}