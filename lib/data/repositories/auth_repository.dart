// lib/data/repositories/auth_repository.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../services/auth_service.dart';
import '../models/auth_models.dart';

class AuthRepository {
  final AuthService _authService;
  final Logger _logger;

  AuthRepository({
    required AuthService authService,
    Logger? logger,
  })  : _authService = authService,
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

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      return await _authService.isLoggedIn();
    } catch (e) {
      _logger.error('Error checking login status in repository: $e');
      return false;
    }
  }

  /// Get user profile
  Future<UserProfile?> getUserProfile() async {
    try {
      return await _authService.getUserProfile();
    } catch (e) {
      _logger.error('Error getting user profile in repository: $e');
      return null;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      _logger.error('Error logging out in repository: $e');
      rethrow;
    }
  }
}