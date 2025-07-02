// lib/data/services/fcm_token_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';

class FcmTokenService {
  final http.Client _client;
  final Logger _logger;
  final FirebaseMessaging _firebaseMessaging;
  
  FcmTokenService({
    required http.Client client,
    required Logger logger,
    FirebaseMessaging? firebaseMessaging,
  }) : _client = client,
       _logger = logger,
       _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance;

  /// Save FCM token to server
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
      
      // Make API call
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/save_fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      _logger.log('FCM token save response status: ${response.statusCode}');
      _logger.log('FCM token save response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Check for success message
        if (responseData.containsKey('message') && 
            responseData['message'].toString().contains('Successfully')) {
          _logger.log('FCM token saved successfully');
          
          // Store the token locally for future reference
          await _storeFcmTokenLocally(tokenToSave);
          return true;
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

  /// Auto-save FCM token for logged-in user
  Future<bool> autoSaveFcmTokenForUser(UserProfile userProfile) async {
    try {
      _logger.log('Auto-saving FCM token for user: ${userProfile.mobile}');
      
      return await saveFcmToken(
        mobileNumber: userProfile.mobile,
        accessKey: userProfile.accessKey,
      );
    } catch (e) {
      _logger.error('Error auto-saving FCM token: $e');
      return false;
    }
  }

  /// Listen for FCM token refresh and auto-update
  void listenForTokenRefresh(UserProfile userProfile) {
    try {
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        _logger.log('FCM token refreshed');
        
        // Auto-save the new token
        await saveFcmToken(
          mobileNumber: userProfile.mobile,
          accessKey: userProfile.accessKey,
          fcmToken: newToken,
        );
      });
    } catch (e) {
      _logger.error('Error setting up FCM token refresh listener: $e');
    }
  }
}