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

  /// Save FCM token to server using centralized auth
  Future<bool> saveFcmToken({String? fcmToken}) async {
    try {
      return await _fcmTokenService.saveFcmToken(fcmToken: fcmToken);
    } catch (e) {
      _logger.error('Error in repository saving FCM token: $e');
      return false;
    }
  }

  /// Auto-save FCM token for the current user
  Future<bool> saveTokenForCurrentUser(UserProfile userProfile) async {
    try {
      _logger.log('Saving FCM token for current user: ${userProfile.mobile}');
      
      return await _fcmTokenService.saveFcmToken();
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

  /// Set up automatic token refresh handling.
  ///
  /// Takes no profile: the service resolves the signed-in user from the auth
  /// manager when a rotation actually arrives. Passing a profile in encouraged
  /// callers to capture credentials that go stale the moment the access token
  /// is refreshed.
  void setupTokenRefreshListener() {
    try {
      _fcmTokenService.setupFcmTokenRefreshListener();
    } catch (e) {
      _logger.error('Error setting up FCM token refresh listener: $e');
    }
  }

  /// Stop listening for token rotations.
  Future<void> cancelTokenRefreshListener() async {
    try {
      await _fcmTokenService.cancelTokenRefreshListener();
    } catch (e) {
      _logger.error('Error cancelling FCM token refresh listener: $e');
    }
  }
}