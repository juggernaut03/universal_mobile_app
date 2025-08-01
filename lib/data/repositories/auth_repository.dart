// lib/data/repositories/auth_repository.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../../core/auth/centralized_auth_manager.dart';
import '../services/auth_service.dart';
import '../models/auth_models.dart';

class AuthRepository {
  final AuthService _authService;
  final CentralizedAuthManager _authManager;
  final Logger _logger;

  AuthRepository({
    required AuthService authService,
    required CentralizedAuthManager authManager,
    Logger? logger,
  })  : _authService = authService,
        _authManager = authManager,
        _logger = logger ?? Logger();

  /// Request OTP for the given mobile number
  Future<OtpRequestResponse> requestOtp(String mobileNumber) async {
    try {
      return await _authService.requestOtp(mobileNumber);
    } catch (e) {
      _logger.error('Error in repository requesting OTP: $e');
      rethrow;
    }
  }

  /// Validate OTP for the given mobile number
  Future<OtpValidationResponse> validateOtp(String mobileNumber, String otp) async {
    try {
      return await _authService.validateOtp(mobileNumber, otp);
    } catch (e) {
      _logger.error('Error in repository validating OTP: $e');
      rethrow;
    }
  }

  /// Check if user is logged in - Uses CentralizedAuthManager as single source
  Future<bool> isLoggedIn() async {
    try {
      return await _authManager.isLoggedIn();
    } catch (e) {
      _logger.error('Error checking login status in repository: $e');
      return false;
    }
  }

  /// Get user profile - Uses CentralizedAuthManager as single source
  Future<UserProfile?> getUserProfile() async {
    try {
      return await _authManager.getCurrentUserProfile();
    } catch (e) {
      _logger.error('Error getting user profile in repository: $e');
      return null;
    }
  }

  /// Logout user - Uses CentralizedAuthManager as single source
  Future<void> logout() async {
    try {
      // Use centralized auth manager for primary logout
      await _authManager.logout();
      
      // Clean up any legacy auth service storage
      await _authService.logout();
      
      _logger.log('User logged out successfully using CentralizedAuthManager');
    } catch (e) {
      _logger.error('Error logging out in repository: $e');
      rethrow;
    }
  }
}