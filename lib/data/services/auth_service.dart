// lib/data/services/auth_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';

class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;
  final Logger _logger;
  
  // Keys for secure storage
  static const String _accessKeyKey = 'user_access_key';
  static const String _userProfileKey = 'user_profile';
  static const String _loginTimeKey = 'login_time';

  AuthService({
    required ApiClient apiClient,
    required FlutterSecureStorage secureStorage,
    Logger? logger,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage,
        _logger = logger ?? Logger();

  /// Request OTP for the given mobile number
  // lib/data/services/auth_service.dart

Future<OtpRequestResponse> requestOtp(String mobileNumber) async {
  try {
    _logger.log('Requesting OTP for mobile: $mobileNumber');
    
    final response = await _apiClient.post(
      'https://newtech.shalviadvision.com/api/get_otp',
      body: {
        'mobileNo': mobileNumber,
        'project_code': ApiConstants.projectCode,
      },
    );
    
    _logger.log('OTP request response: $response');
    
    // The response is valid if it contains any of these fields
    if (response is Map<String, dynamic> && 
        (response.containsKey('reason') || response.containsKey('type'))) {
      // If response contains "OTP successfully generated", consider it a success
      if (response.containsKey('reason') && 
          response['reason'].toString().contains('successfully')) {
        return OtpRequestResponse.fromJson(response);
      }
    }
    
    // If we reach here, there might be an unexpected response format
    // But we'll still try to parse it as our model with defaults
    return OtpRequestResponse.fromJson(response is Map<String, dynamic> ? response : {});
  } catch (e) {
    _logger.error('Error requesting OTP: $e');
    rethrow;
  }
}
  /// Validate OTP for the given mobile number
  // lib/data/services/auth_service.dart (update the validateOtp method)

Future<OtpValidationResponse> validateOtp(String mobileNumber, String otp) async {
  try {
    _logger.log('Validating OTP for mobile: $mobileNumber, OTP: $otp');
    
    final response = await _apiClient.post(
      'https://newtech.shalviadvision.com/api/validate_otp',
      body: {
        'mobileNo': mobileNumber,
        'otp': otp,
        'project_code': ApiConstants.projectCode,
      },
    );
    
    // Log the response to help with debugging
    _logger.log('OTP validation response: $response');
    
    // Create validation response from JSON
    final validationResponse = OtpValidationResponse.fromJson(response);
    
    // If authentication is successful, save access key
    if (validationResponse.isSuccessful()) {
      _logger.log('OTP validation successful, saving credentials');
      
      // Convert mobile number to string if it's not already
      String mobileStr = mobileNumber;
      if (validationResponse.mobileNumber != null) {
        mobileStr = validationResponse.mobileNumber.toString();
      }
      
      await _saveUserCredentials(
        mobileStr,
        validationResponse.accessKey,
      );
    } else {
      _logger.error('OTP validation failed: ${validationResponse.message}');
    }
    
    return validationResponse;
  } catch (e) {
    _logger.error('Error validating OTP: $e');
    rethrow;
  }
}

  /// Save user credentials to secure storage
  Future<void> _saveUserCredentials(String mobile, String accessKey) async {
    try {
      final now = DateTime.now();
      
      // Save access key
      await _secureStorage.write(key: _accessKeyKey, value: accessKey);
      
      // Save login time
      await _secureStorage.write(key: _loginTimeKey, value: now.toIso8601String());
      
      // Save user profile
      final userProfile = UserProfile(
        mobile: mobile,
        accessKey: accessKey,
        loginTime: now,
      );
      
      await _secureStorage.write(
        key: _userProfileKey,
        value: _encodeUserProfile(userProfile),
      );
      
      _logger.log('User credentials saved successfully for mobile: $mobile');
    } catch (e) {
      _logger.error('Error saving user credentials: $e');
      rethrow;
    }
  }

  /// Get user profile from secure storage
  Future<UserProfile?> getUserProfile() async {
    try {
      final profileJson = await _secureStorage.read(key: _userProfileKey);
      if (profileJson == null) return null;
      
      return _decodeUserProfile(profileJson);
    } catch (e) {
      _logger.error('Error getting user profile: $e');
      return null;
    }
  }

  /// Check if user is logged in with valid access key
  Future<bool> isLoggedIn() async {
    try {
      final accessKey = await _secureStorage.read(key: _accessKeyKey);
      final loginTimeStr = await _secureStorage.read(key: _loginTimeKey);
      
      if (accessKey == null || loginTimeStr == null) return false;
      
      // Parse login time
      final loginTime = DateTime.parse(loginTimeStr);
      final now = DateTime.now();
      
      // Check if access key is still valid (10 days)
      final isValid = now.difference(loginTime).inDays < 10;
      
      _logger.log('Access key valid: $isValid');
      return isValid;
    } catch (e) {
      _logger.error('Error checking login status: $e');
      return false;
    }
  }

  /// Logout user by clearing credentials
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _accessKeyKey);
      await _secureStorage.delete(key: _userProfileKey);
      await _secureStorage.delete(key: _loginTimeKey);
      _logger.log('User logged out successfully');
    } catch (e) {
      _logger.error('Error logging out: $e');
      rethrow;
    }
  }

  // Helper methods for encoding/decoding user profile
  String _encodeUserProfile(UserProfile profile) {
    return '${profile.mobile}:${profile.accessKey}:${profile.loginTime.toIso8601String()}';
  }

  UserProfile _decodeUserProfile(String encoded) {
    final parts = encoded.split(':');
    if (parts.length >= 3) {
      return UserProfile(
        mobile: parts[0],
        accessKey: parts[1],
        loginTime: DateTime.parse(parts[2]),
      );
    }
    
    // Fallback
    return UserProfile(
      mobile: parts.isNotEmpty ? parts[0] : '',
      accessKey: parts.length > 1 ? parts[1] : '',
      loginTime: DateTime.now(),
    );
  }
}