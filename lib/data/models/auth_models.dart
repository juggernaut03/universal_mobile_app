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

  factory OtpRequestResponse.fromJson(Map<String, dynamic> json) {
    return OtpRequestResponse(
      type: json['type'] ?? '',
      reason: json['reason'] ?? '',
      createTime: json['createTime'] ?? '',
      expiryTime: json['expiryTime'] ?? '',
      retryAfter: json['retryAfter'] ?? '',
      status: json['status'] ?? 'success', // Default to success if not provided
      mobile: json['mobile'] ?? '',
      transactionId: json['transactionId'] ?? '',
      statusCode: json['statusCode'] ?? '',
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

  factory OtpValidationResponse.fromJson(Map<String, dynamic> json) {
    return OtpValidationResponse(
      authentication: json['authentication'] ?? 0,
      message: json['message'] ?? '',
      accessKey: json['access_key'] ?? '',
      mobileNumber: json['mobile_number'] ?? 0,
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