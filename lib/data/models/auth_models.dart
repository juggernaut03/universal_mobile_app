// lib/data/models/auth_models.dart

import 'dart:convert';

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

  /// Long-lived token from `data.refreshToken`. Empty against a backend that
  /// predates refresh tokens, which just means the session is not renewable.
  final String refreshToken;

  OtpValidationResponse({
    required this.authentication,
    required this.message,
    required this.accessKey,
    required this.mobileNumber,
    this.refreshToken = '',
  });

  // Universal backend envelope: {success, message, data: {token, refreshToken, user}}.
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
      refreshToken: data['refreshToken'] ?? '',
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

  /// Long-lived credential used to mint a new [accessKey] without asking the
  /// shopper for another OTP. Empty for sessions stored before refresh tokens
  /// existed — those simply expire the old way instead of being force-logged
  /// out on upgrade.
  final String refreshToken;

  /// When [accessKey] stops being accepted, read from the JWT's own `exp`.
  ///
  /// The session used to be judged by "days since login < 10", a number this
  /// app invented that had nothing to do with the token's real lifetime. It
  /// could call a perfectly valid token expired, and a genuinely expired one
  /// valid — the latter surfacing as an unexplained 401 mid-checkout.
  final DateTime? accessKeyExpiresAt;

  UserProfile({
    required this.mobile,
    required this.accessKey,
    required this.loginTime,
    this.refreshToken = '',
    this.accessKeyExpiresAt,
  });

  UserProfile copyWith({
    String? mobile,
    String? accessKey,
    DateTime? loginTime,
    String? refreshToken,
    DateTime? accessKeyExpiresAt,
  }) {
    return UserProfile(
      mobile: mobile ?? this.mobile,
      accessKey: accessKey ?? this.accessKey,
      loginTime: loginTime ?? this.loginTime,
      refreshToken: refreshToken ?? this.refreshToken,
      accessKeyExpiresAt: accessKeyExpiresAt ?? this.accessKeyExpiresAt,
    );
  }

  bool get hasRefreshToken => refreshToken.isNotEmpty;

  /// True once [accessKey] is within [leeway] of expiring, so a refresh can be
  /// done before a request fails rather than after.
  bool accessKeyNeedsRefresh({Duration leeway = const Duration(minutes: 2)}) {
    final expiry = accessKeyExpiresAt;
    if (expiry == null) return false;
    return DateTime.now().add(leeway).isAfter(expiry);
  }

  /// Reads the `exp` claim out of a JWT without verifying it.
  ///
  /// The signature is the server's business; the client only needs to know
  /// when to stop sending the token. Returns null for anything unparseable,
  /// which callers treat as "no known expiry" rather than "expired".
  static DateTime? expiryFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalised = base64Url.normalize(payload);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalised)));
      final exp = decoded is Map ? decoded['exp'] : null;
      if (exp is! int) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'mobile': mobile,
      'accessKey': accessKey,
      'loginTime': loginTime.toIso8601String(),
      'refreshToken': refreshToken,
      'accessKeyExpiresAt': accessKeyExpiresAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final accessKey = json['accessKey'] ?? '';
    final storedExpiry = json['accessKeyExpiresAt'];
    return UserProfile(
      mobile: json['mobile'] ?? '',
      accessKey: accessKey,
      loginTime: json['loginTime'] != null
          ? DateTime.parse(json['loginTime'])
          : DateTime.now(),
      refreshToken: json['refreshToken'] ?? '',
      // Fall back to reading the JWT for profiles written before this field
      // existed, so an upgrade keeps the session it already had.
      accessKeyExpiresAt: storedExpiry != null
          ? DateTime.tryParse(storedExpiry)
          : expiryFromJwt(accessKey),
    );
  }
}