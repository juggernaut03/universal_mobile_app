// lib/data/services/fcm_token_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/auth/centralized_auth_manager.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../../core/constants/app_constants.dart';

class FcmTokenService {
  final CentralizedAuthManager _authManager;
  final ApiClient _apiClient;
  final Logger _logger;
  final FirebaseMessaging _firebaseMessaging;
  
  FcmTokenService({
    required CentralizedAuthManager authManager,
    required ApiClient apiClient,
    required Logger logger,
    FirebaseMessaging? firebaseMessaging,
  }) : _authManager = authManager,
       _apiClient = apiClient,
       _logger = logger,
       _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance;

  /// Save FCM token to server using centralized auth management
  Future<bool> saveFcmToken({String? fcmToken}) async {
    try {
      // Check if user is logged in
      if (!await _authManager.isLoggedIn()) {
        _logger.error('Cannot save FCM token: user not logged in');
        return false;
      }

      // Get user credentials from centralized auth
      final mobile = await _authManager.getUserMobile();
      if (mobile == null || mobile.isEmpty) {
        _logger.error('Cannot save FCM token: no mobile number found');
        return false;
      }

      // Get FCM token if not provided
      String? tokenToSave = fcmToken;
      if (tokenToSave == null || tokenToSave.isEmpty) {
        tokenToSave = await _getCurrentFcmToken();
        if (tokenToSave == null) {
          _logger.error('Failed to get FCM token');
          return false;
        }
      }

      _logger.log('Saving FCM token for mobile: $mobile');
      
      // Use centralized API client with auth (Bearer JWT)
      final response = await _apiClient.postWithAuth(
        ApiConstants.authSaveFcmToken,
        body: {
          "fcmToken": tokenToSave,
        },
      );

      _logger.log('FCM token save response: $response');

      if (response is Map<String, dynamic> && response['success'] == true) {
        _logger.log('FCM token saved successfully');

        // Store the token locally for future reference
        await _storeFcmTokenLocally(tokenToSave);
        return true;
      }
      
      _logger.error('Failed to save FCM token: $response');
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
      if (!await _authManager.isLoggedIn()) {
        _logger.error('Cannot refresh FCM token: user not logged in');
        return false;
      }
      
      final mobile = await _authManager.getUserMobile();
      _logger.log('Manually refreshing FCM token for user: $mobile');
      
      return await saveFcmToken();
    } catch (e) {
      _logger.error('Error manually refreshing FCM token: $e');
      return false;
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
        'user_logged_in': await _authManager.isLoggedIn(),
      };
    } catch (e) {
      _logger.error('Error getting FCM token status: $e');
      return {'error': e.toString()};
    }
  }

  /// Set up FCM token refresh listener for automatic updates
  void setupFcmTokenRefreshListener() async {
    try {
      if (!await _authManager.isLoggedIn()) {
        _logger.log('User not logged in, skipping FCM token refresh listener setup');
        return;
      }

      final mobile = await _authManager.getUserMobile();
      _logger.log('Setting up FCM token refresh listener for: $mobile');
      
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        try {
          _logger.log('FCM token refreshed, saving new token...');
          
          final success = await saveFcmToken(fcmToken: newToken);
          
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
}

// fcmTokenServiceProvider now declared in lib/di/service_providers.dart
