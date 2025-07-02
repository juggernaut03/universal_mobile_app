// lib/data/services/auth_service.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';

class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;
  final Logger _logger;
  final http.Client _httpClient;
  final FirebaseMessaging _firebaseMessaging;
  
  // Keys for secure storage
  static const String _accessKeyKey = 'user_access_key';
  static const String _userProfileKey = 'user_profile';
  static const String _loginTimeKey = 'login_time';

  AuthService({
    required ApiClient apiClient,
    required FlutterSecureStorage secureStorage,
    Logger? logger,
    http.Client? httpClient,
    FirebaseMessaging? firebaseMessaging,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage,
        _logger = logger ?? Logger(),
        _httpClient = httpClient ?? http.Client(),
        _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance;

  /// Request OTP for the given mobile number
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

  /// Save user credentials to secure storage and handle FCM token
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
      
      // Save FCM token after successful login (non-blocking)
      _saveFcmTokenAfterLogin(userProfile);
      
      // Set up FCM token refresh listener
      _setupFcmTokenRefreshListener(userProfile);
      
    } catch (e) {
      _logger.error('Error saving user credentials: $e');
      rethrow;
    }
  }

  /// Save FCM token after successful login (runs in background)
  Future<void> _saveFcmTokenAfterLogin(UserProfile userProfile) async {
    try {
      _logger.log('Initiating FCM token save after login...');
      
      // Run in background without blocking the login flow
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          final success = await saveFcmToken(
            mobileNumber: userProfile.mobile,
            accessKey: userProfile.accessKey,
          );
          
          if (success) {
            _logger.log('FCM token saved successfully after login');
          } else {
            _logger.warning('FCM token save failed after login');
          }
        } catch (e) {
          _logger.error('Error saving FCM token after login: $e');
        }
      });
    } catch (e) {
      _logger.error('Error initiating FCM token save after login: $e');
    }
  }

  /// Set up FCM token refresh listener for automatic updates
  void _setupFcmTokenRefreshListener(UserProfile userProfile) {
    try {
      _logger.log('Setting up FCM token refresh listener for: ${userProfile.mobile}');
      
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        try {
          _logger.log('FCM token refreshed, saving new token...');
          
          final success = await saveFcmToken(
            mobileNumber: userProfile.mobile,
            accessKey: userProfile.accessKey,
            fcmToken: newToken,
          );
          
          if (success) {
            _logger.log('New FCM token saved successfully');
          } else {
            _logger.warning('Failed to save new FCM token');
          }
        } catch (e) {
          _logger.error('Error handling FCM token refresh: $e');
        }
      });
    } catch (e) {
      _logger.error('Error setting up FCM token refresh listener: $e');
    }
  }

  /// Save FCM token to server using the /save_fcm_token API
  Future<bool> saveFcmToken({
    required String mobileNumber,
    required String accessKey,
    String? fcmToken,
  }) async {
    try {
      // Get FCM token if not provided
      String? tokenToSave = fcmToken;
      if (tokenToSave == null || tokenToSave.isEmpty) {
        tokenToSave = await _getCurrentFcmToken();
        if (tokenToSave == null) {
          _logger.error('Failed to get FCM token');
          return false;
        }
      }

      _logger.log('Saving FCM token for mobile: $mobileNumber');
      
      // Prepare request body exactly as specified
      final requestBody = {
        "mobile_no": mobileNumber,
        "access_key": accessKey,
        "fcm_token": tokenToSave,
      };
      
      _logger.log('FCM token save request: ${jsonEncode(requestBody)}');
      
      // Make API call using the correct base URL
      final response = await _httpClient.post(
        Uri.parse('https://newtech.shalviadvision.com/api/save_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('FCM token save response status: ${response.statusCode}');
      _logger.log('FCM token save response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          
          // Check for success message
          if (responseData.containsKey('message') && 
              responseData['message'].toString().contains('Successfully')) {
            _logger.log('FCM token saved successfully');
            
            // Store the token locally for future reference
            await _storeFcmTokenLocally(tokenToSave);
            return true;
          }
        } catch (e) {
          // If response is not JSON, check if it contains success message
          if (response.body.toLowerCase().contains('successfully')) {
            _logger.log('FCM token saved successfully (non-JSON response)');
            await _storeFcmTokenLocally(tokenToSave);
            return true;
          }
        }
      }
      
      _logger.error('Failed to save FCM token: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      _logger.error('Error saving FCM token: $e');
      return false;
    }
  }

  /// Get current FCM token from Firebase
  Future<String?> _getCurrentFcmToken() async {
    try {
      // Try to get token with retries
      for (int i = 0; i < 3; i++) {
        try {
          final token = await _firebaseMessaging.getToken();
          if (token != null && token.isNotEmpty) {
            _logger.log('FCM token retrieved successfully');
            return token;
          }
          
          // Wait before retry
          if (i < 2) {
            await Future.delayed(Duration(seconds: (i + 1) * 2));
          }
        } catch (e) {
          _logger.error('FCM token attempt ${i + 1} failed: $e');
          if (i == 2) return null;
        }
      }
      
      return null;
    } catch (e) {
      _logger.error('Error getting FCM token: $e');
      return null;
    }
  }

  /// Store FCM token locally
  Future<void> _storeFcmTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await prefs.setString('fcm_token_last_saved', DateTime.now().toIso8601String());
      _logger.log('FCM token stored locally');
    } catch (e) {
      _logger.error('Error storing FCM token locally: $e');
    }
  }

  /// Check if FCM token needs to be updated on server
  Future<bool> shouldUpdateFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current token
      final currentToken = await _getCurrentFcmToken();
      if (currentToken == null) return false;
      
      // Get stored token
      final storedToken = prefs.getString('fcm_token');
      
      // If tokens are different, update is needed
      if (storedToken != currentToken) {
        _logger.log('FCM token changed, update needed');
        return true;
      }
      
      // Check if token was saved more than 7 days ago
      final lastSavedStr = prefs.getString('fcm_token_last_saved');
      if (lastSavedStr != null) {
        final lastSaved = DateTime.parse(lastSavedStr);
        final daysSinceLastSave = DateTime.now().difference(lastSaved).inDays;
        
        if (daysSinceLastSave > 7) {
          _logger.log('FCM token older than 7 days, update needed');
          return true;
        }
      } else {
        // No record of last save, update needed
        _logger.log('No record of FCM token save, update needed');
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.error('Error checking FCM token update requirement: $e');
      return true; // On error, assume update is needed
    }
  }

  /// Manually trigger FCM token save (for debugging or manual refresh)
  Future<bool> refreshFcmToken() async {
    try {
      final userProfile = await getUserProfile();
      if (userProfile == null) {
        _logger.error('Cannot refresh FCM token: user not logged in');
        return false;
      }
      
      _logger.log('Manually refreshing FCM token for user: ${userProfile.mobile}');
      
      return await saveFcmToken(
        mobileNumber: userProfile.mobile,
        accessKey: userProfile.accessKey,
      );
    } catch (e) {
      _logger.error('Error manually refreshing FCM token: $e');
      return false;
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

  /// Get current FCM token (public method for external use)
  Future<String?> getCurrentFcmToken() async {
    return await _getCurrentFcmToken();
  }

  /// Check FCM token status for debugging
  Future<Map<String, dynamic>> getFcmTokenStatus() async {
    try {
      final currentToken = await _getCurrentFcmToken();
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('fcm_token');
      final lastSaved = prefs.getString('fcm_token_last_saved');
      
      return {
        'current_token': currentToken?.substring(0, 20) ?? 'null',
        'stored_token': storedToken?.substring(0, 20) ?? 'null',
        'tokens_match': currentToken == storedToken,
        'last_saved': lastSaved ?? 'never',
        'needs_update': await shouldUpdateFcmToken(),
      };
    } catch (e) {
      _logger.error('Error getting FCM token status: $e');
      return {'error': e.toString()};
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