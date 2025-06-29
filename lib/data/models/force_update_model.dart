// lib/data/models/force_update_model.dart

class ForceUpdateRequest {
  final String mobilePlatform;

  const ForceUpdateRequest({
    required this.mobilePlatform,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobile_platform': mobilePlatform,
    };
  }
}

class ForceUpdateResponse {
  final String latestVersion;
  final String minimumSupportedVersion;
  final bool forceUpdate;
  final String updateMessage;
  final String androidDownloadUrl;
  final String iosDownloadUrl;
  final String releaseNotes;
  final String maintenanceMode;
  final String maintenanceMessage;

  const ForceUpdateResponse({
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

  factory ForceUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ForceUpdateResponse(
      latestVersion: json['latestVersion'] ?? '',
      minimumSupportedVersion: json['minimumSupportedVersion'] ?? '',
      forceUpdate: json['forceUpdate'] ?? false,
      updateMessage: json['updateMessage'] ?? '',
      androidDownloadUrl: json['androidDownloadUrl'] ?? '',
      iosDownloadUrl: json['iosDownloadUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      maintenanceMode: json['maintenanceMode'] ?? '',
      maintenanceMessage: json['maintenanceMessage'] ?? '',
    );
  }
}