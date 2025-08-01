// lib/data/repositories/profile_repository.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import 'base_repository.dart';

class ProfileRepository extends BaseRepository {

  ProfileRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });
  
  // Get user profile details using centralized auth
  Future<Map<String, dynamic>> getUserProfile() async {
    return await makeAuthenticatedRequest<Map<String, dynamic>>(
      () async {
        logActivity('Fetching user profile');

        final mobile = await getUserMobile();
        if (mobile == null) {
          logActivity('No mobile number found');
          return {};
        }
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/get_customer_profile',
          body: {
            'mobile_number': mobile,
          },
        );
        
        if (response is List && response.isNotEmpty) {
          logActivity('Successfully fetched user profile');
          return response[0] as Map<String, dynamic>;
        } else if (response is Map<String, dynamic>) {
          logActivity('Successfully fetched user profile');
          return response;
        } else {
          logActivity('Unexpected response format for user profile');
          return {};
        }
      },
      onAuthError: () => <String, dynamic>{},
    ) ?? <String, dynamic>{};
  }
  
  // Update user profile details using centralized auth
  Future<bool> updateUserProfile({
    required String firstName,
    required String lastName,
    String? emailId,
  }) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Updating user profile');

        final mobile = await getUserMobile();
        if (mobile == null) {
          logActivity('No mobile number found');
          return false;
        }
        
        // Create request body
        final requestBody = {
          'mobile_number': mobile,
          'first_name': firstName,
          'last_name': lastName,
        };

        // Add email if provided
        if (emailId != null && emailId.isNotEmpty) {
          requestBody['email_id'] = emailId;
        }
        
        logActivity('Update profile request: $requestBody');
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/add_update_customer_profile',
          body: requestBody,
        );
        
        logActivity('Update profile response: $response');
        
        if (response is Map<String, dynamic>) {
          final message = response['message']?.toString() ?? '';
          if (message.toLowerCase().contains('successfully') || 
              message.toLowerCase().contains('success')) {
            logActivity('Profile updated successfully');
            return true;
          }
        } else if (response is String) {
          // Handle plain text responses
          final responseStr = response.toLowerCase();
          if (responseStr.contains('successfully') || 
              responseStr.contains('success')) {
            logActivity('Profile updated successfully');
            return true;
          }
        }
        
        logActivity('Failed to update profile - unexpected response');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }
}

/// Provider for ProfileRepository using centralized dependencies
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dependencies = ref.watch(baseRepositoryDependenciesProvider);
  
  return ProfileRepository(
    authManager: dependencies.authManager,
    apiClient: dependencies.apiClient,
    logger: dependencies.logger,
  );
});