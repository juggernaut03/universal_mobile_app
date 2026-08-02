// lib/data/services/auth_service.dart

import 'dart:async';
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
        
        _registerDeviceForPush(mobileStr, validationResponse.accessKey);
      } else {
        _logger.error('OTP validation failed: ${validationResponse.message}');
      }
      
      return validationResponse;
    } catch (e) {
      _logger.error('Error validating OTP: $e');
      rethrow;
    }
  }

  /// Registers this device for push after a successful OTP verification.
  ///
  /// Deliberately fire-and-forget: a failure to register for push must not
  /// fail a login that has already succeeded.
  ///
  /// The ongoing job of keeping the server's copy of the FCM token current
  /// belongs to [FcmTokenService], which reads a fresh bearer token per call
  /// and holds a cancellable subscription. This class used to do that too, via
  /// an `onTokenRefresh.listen` that was never cancelled and closed over the
  /// access token as it stood at login — so every rotation after the first
  /// authenticated with a JWT that had already been replaced.
  void _registerDeviceForPush(String mobile, String accessKey) {
    // The token is passed explicitly because this fires during login, before
    // the profile lands in CentralizedAuthManager storage.
    unawaited(() async {
      try {
        final success =
            await saveFcmToken(mobileNumber: mobile, accessKey: accessKey);
        success
            ? _logger.log('FCM token saved after login')
            : _logger.warning('FCM token save failed after login');
      } catch (e) {
        _logger.error('Error saving FCM token after login: $e');
      }
    }());
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

  // `getUserProfile()`, `isLoggedIn()` and `refreshFcmToken()` used to live
  // here. The first two were hardcoded to `return null` / `return false` with a
  // comment explaining they could not reach CentralizedAuthManager — and
  // `refreshFcmToken()` called `getUserProfile()`, so it reported "user not
  // logged in" for every signed-in user and never saved anything.
  //
  // Session questions go to CentralizedAuthManager (or IAuthRepository); FCM
  // upkeep goes to FcmTokenService, which has the auth manager injected and can
  // answer both.

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

  /// First 20 characters of [token], for logging. Safe on short values.
  static String _preview(String? token) {
    if (token == null || token.isEmpty) return 'null';
    return token.length <= 20 ? token : '${token.substring(0, 20)}…';
  }

  /// Check FCM token status for debugging
  Future<Map<String, dynamic>> getFcmTokenStatus() async {
    try {
      final currentToken = await _getCurrentFcmToken();
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('fcm_token');
      final lastSaved = prefs.getString('fcm_token_last_saved');
      
      return {
        // Never a bare substring(0, 20): it throws on tokens shorter than 20
        // characters, crashing the debug screen precisely when it is needed.
        'current_token': _preview(currentToken),
        'stored_token': _preview(storedToken),
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