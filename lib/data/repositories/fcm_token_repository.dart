// lib/data/repositories/fcm_token_repository.dart

import 'dart:async';
import '../../core/utils/logger.dart';
import '../services/fcm_token_service.dart';
import '../models/auth_models.dart';

class FcmTokenRepository {
  final FcmTokenService _fcmTokenService;
  final Logger _logger;

  FcmTokenRepository({
    required FcmTokenService fcmTokenService,
    Logger? logger,
  }) : _fcmTokenService = fcmTokenService,
       _logger = logger ?? Logger();

  /// Save FCM token to server
  Future<bool> saveFcmToken({
    required String mobileNumber,
    required String accessKey,
    String? fcmToken,
  }) async {
    try {
      return await _fcmTokenService.saveFcmToken(
        mobileNumber: mobileNumber,
        accessKey: accessKey,
        fcmToken: fcmToken,
      );
    } catch (e) {
      _logger.error('Error in repository saving FCM token: $e');
      return false;
    }
  }

  /// Auto-save FCM token for the current user
  Future<bool> saveTokenForCurrentUser(UserProfile userProfile) async {
    try {
      _logger.log('Saving FCM token for current user: ${userProfile.mobile}');
      
      return await _fcmTokenService.autoSaveFcmTokenForUser(userProfile);
    } catch (e) {
      _logger.error('Error saving FCM token for current user: $e');
      return false;
    }
  }

  /// Check if FCM token should be updated
  Future<bool> shouldUpdateToken() async {
    try {
      return await _fcmTokenService.shouldUpdateFcmToken();
    } catch (e) {
      _logger.error('Error checking if FCM token should be updated: $e');
      return true; // On error, assume update is needed
    }
  }

  /// Set up automatic token refresh handling
  void setupTokenRefreshListener(UserProfile userProfile) {
    try {
      _logger.log('Setting up FCM token refresh listener for: ${userProfile.mobile}');
      _fcmTokenService.listenForTokenRefresh(userProfile);
    } catch (e) {
      _logger.error('Error setting up FCM token refresh listener: $e');
    }
  }
}