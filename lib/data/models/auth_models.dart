// lib/data/models/auth_models.dart

// lib/data/models/auth_models.dart

class OtpRequestResponse {
  final String type;
  final String reason;
  final String createTime;
  final String expiryTime;
  final String retryAfter;
  final String status;
  final String mobile;
  final String transactionId;
  final String statusCode;

  OtpRequestResponse({
    this.type = '',
    this.reason = '',
    this.createTime = '',
    this.expiryTime = '',
    this.retryAfter = '',
    this.status = 'success', // Default to success since "OTP successfully generated"
    this.mobile = '',
    this.transactionId = '',
    this.statusCode = '',
  });

  // Universal backend envelope: {success, message, expiresIn}
  factory OtpRequestResponse.fromJson(Map<String, dynamic> json) {
    final bool success = json['success'] == true;
    return OtpRequestResponse(
      type: success ? 'success' : 'error',
      reason: json['message'] ?? '',
      expiryTime: json['expiresIn']?.toString() ?? '',
      status: success ? 'success' : 'failure',
      mobile: json['mobile'] ?? '',
    );
  }
}
// lib/data/models/auth_models.dart (update the OtpValidationResponse class)

class OtpValidationResponse {
  final int authentication;
  final String message;
  final String accessKey;
  final dynamic mobileNumber; // Changed to dynamic to handle both int and String

  OtpValidationResponse({
    required this.authentication,
    required this.message,
    required this.accessKey,
    required this.mobileNumber,
  });

  // Universal backend envelope: {success, message, data: {token, user}}.
  // The JWT is carried in accessKey so existing storage/UI code keeps working.
  factory OtpValidationResponse.fromJson(Map<String, dynamic> json) {
    final bool success = json['success'] == true;
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    return OtpValidationResponse(
      authentication: success ? 1 : 0,
      message: json['message'] ?? '',
      accessKey: data['token'] ?? '',
      mobileNumber: user['mobile'] ?? '',
    );
  }
  
  // Helper method to check if authentication was successful
  bool isSuccessful() {
    return authentication == 1 && accessKey.isNotEmpty;
  }
}

class UserProfile {
  final String mobile;
  final String accessKey;
  final DateTime loginTime;

  UserProfile({
    required this.mobile,
    required this.accessKey,
    required this.loginTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobile': mobile,
      'accessKey': accessKey,
      'loginTime': loginTime.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      mobile: json['mobile'] ?? '',
      accessKey: json['accessKey'] ?? '',
      loginTime: json['loginTime'] != null 
          ? DateTime.parse(json['loginTime']) 
          : DateTime.now(),
    );
  }
}