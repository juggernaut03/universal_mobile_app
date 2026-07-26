// lib/data/repositories/profile_repository.dart

import '../../core/constants/app_constants.dart';
import 'base_repository.dart';

class ProfileRepository extends BaseRepository {

  ProfileRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });
  
  // Get user profile details (GET /api/auth/profile).
  // The universal backend stores a single `name`; it is split into the
  // legacy first_name / last_name keys existing screens read.
  Future<Map<String, dynamic>> getUserProfile() async {
    return await makeAuthenticatedRequest<Map<String, dynamic>>(
      () async {
        logActivity('Fetching user profile');

        final response = await getWithAuth(ApiConstants.authProfile);

        final user = response is Map<String, dynamic> &&
                response['data'] is Map &&
                (response['data'] as Map)['user'] is Map
            ? Map<String, dynamic>.from((response['data'] as Map)['user'] as Map)
            : null;

        if (user == null) {
          logActivity('Unexpected response format for user profile');
          return {};
        }

        final name = (user['name'] ?? '').toString().trim();
        final parts = name.split(RegExp(r'\s+'));
        final firstName = parts.isNotEmpty ? parts.first : '';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        logActivity('Successfully fetched user profile');
        return {
          ...user,
          'first_name': firstName,
          'last_name': lastName,
          'email_id': user['email'] ?? '',
          'mobile_number': user['mobile'] ?? '',
        };
      },
      onAuthError: () => <String, dynamic>{},
    ) ?? <String, dynamic>{};
  }

  // Update user profile details (PUT /api/auth/profile)
  Future<bool> updateUserProfile({
    required String firstName,
    required String lastName,
    String? emailId,
  }) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Updating user profile');

        final requestBody = <String, dynamic>{
          'name': [firstName.trim(), lastName.trim()]
              .where((p) => p.isNotEmpty)
              .join(' '),
        };
        if (emailId != null && emailId.isNotEmpty) {
          requestBody['email'] = emailId;
        }

        final response = await putWithAuth(
          ApiConstants.authProfile,
          body: requestBody,
        );

        if (response is Map<String, dynamic> && response['success'] == true) {
          logActivity('Profile updated successfully');
          return true;
        }

        logActivity('Failed to update profile - unexpected response');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }
}

// profileRepositoryProvider now declared in lib/di/repository_providers.dart
