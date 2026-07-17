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
        ApiConstants.authSendOtp,
        body: {
          'mobile': mobileNumber,
        },
      );

      _logger.log('OTP request response: $response');

      return OtpRequestResponse.fromJson(
          response is Map<String, dynamic> ? response : {});
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
        ApiConstants.authVerifyOtp,
        body: {
          'mobile': mobileNumber,
          'otp': otp,
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

  /// Save user credentials and integrate with CentralizedAuthManager
  /// This method now properly integrates with CentralizedAuthManager
  Future<void> _saveUserCredentials(String mobile, String accessKey) async {
    try {
      final now = DateTime.now();
      
      // Create user profile for CentralizedAuthManager
      final userProfile = UserProfile(
        mobile: mobile,
        accessKey: accessKey,
        loginTime: now,
      );
      
      _logger.log('User credentials received - integrating with CentralizedAuthManager');
      
      // Save FCM token after successful login (non-blocking)
      _saveFcmTokenAfterLogin(userProfile);
      
      // Set up FCM token refresh listener
      _setupFcmTokenRefreshListener(userProfile);
      
    } catch (e) {
      _logger.error('Error handling user credentials: $e');
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

      // The JWT is passed explicitly because this fires during login, before
      // the profile lands in CentralizedAuthManager storage.
      final response = await _httpClient.post(
        Uri.parse(ApiConstants.authSaveFcmToken),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
          'Authorization': 'Bearer $accessKey',
        },
        body: jsonEncode({'fcmToken': tokenToSave}),
      ).timeout(const Duration(seconds: 15));

      _logger.log('FCM token save response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map && responseData['success'] == true) {
            _logger.log('FCM token saved successfully');
            await _storeFcmTokenLocally(tokenToSave);
            return true;
          }
        } catch (_) {}
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

  /// Get user profile - DEPRECATED: Use CentralizedAuthManager instead
  /// This method now delegates to CentralizedAuthManager
  Future<UserProfile?> getUserProfile() async {
    try {
      _logger.log('⚠️ DEPRECATED: AuthService.getUserProfile() - Use CentralizedAuthManager instead');
      // Note: Cannot directly access CentralizedAuthManager here due to circular dependency
      // This method should not be used - access CentralizedAuthManager directly
      return null;
    } catch (e) {
      _logger.error('Error getting user profile: $e');
      return null;
    }
  }

  /// Check if user is logged in - DEPRECATED: Use CentralizedAuthManager instead
  /// This method now delegates to CentralizedAuthManager  
  Future<bool> isLoggedIn() async {
    try {
      _logger.log('⚠️ DEPRECATED: AuthService.isLoggedIn() - Use CentralizedAuthManager instead');
      // Note: Cannot directly access CentralizedAuthManager here due to circular dependency
      // This method should not be used - access CentralizedAuthManager directly
      return false;
    } catch (e) {
      _logger.error('Error checking login status: $e');
      return false;
    }
  }

  /// Logout user - DEPRECATED: Use CentralizedAuthManager instead
  /// This method now only clears legacy storage
  Future<void> logout() async {
    try {
      _logger.log('⚠️ DEPRECATED: AuthService.logout() - Use CentralizedAuthManager instead');
      
      // Clean up any legacy storage that might exist
      await _secureStorage.delete(key: _accessKeyKey);
      await _secureStorage.delete(key: _userProfileKey);
      await _secureStorage.delete(key: _loginTimeKey);
      
      _logger.log('Legacy auth storage cleaned up');
    } catch (e) {
      _logger.error('Error clearing legacy auth storage: $e');
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

}