// lib/data/repositories/profile_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

class ProfileRepository {
  final http.Client _client;
  final Logger _logger;

  ProfileRepository({
    required http.Client client,
    required Logger logger,
  }) : 
    _client = client,
    _logger = logger;
  
  // Get user profile details
  Future<Map<String, dynamic>> getUserProfile(String mobileNumber, String accessKey) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/get_customer_profile');
      
      // Create request body
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'mobile_number': mobileNumber,
        'access_key': accessKey,
      };
      
      _logger.log('Fetching user profile for mobile: $mobileNumber');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is List && jsonData.isNotEmpty) {
          return jsonData[0];
        } else {
          _logger.error('Unexpected response format: ${response.body}');
          return {};
        }
      } else {
        _logger.error('Failed to fetch profile: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch profile');
      }
    } catch (e) {
      _logger.error('Error fetching profile: $e');
      rethrow;
    }
  }
  
  // Update user profile details
  Future<bool> updateUserProfile({
    required String accessKey,
    required String mobileNumber,
    required String firstName,
    required String lastName,
    String? emailId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/add_update_customer_profile');
      
      // Create request body matching the format in the screenshot
      final requestBody = {
        'access_key': accessKey,
        'mobile_number': mobileNumber,
        'first_name': firstName,
        'last_name': lastName,
      };

      // Add email if provided
      if (emailId != null && emailId.isNotEmpty) {
        requestBody['email_id'] = emailId;
      }
      
      _logger.log('Updating profile for mobile: $mobileNumber');
      _logger.log('Request body: $requestBody');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      _logger.log('Update profile response status: ${response.statusCode}');
      _logger.log('Update profile response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Directly check if response body contains success message
        final responseBody = response.body.toString().toLowerCase();
        if (responseBody.contains("successfully") || 
            responseBody.contains("success")) {
          _logger.log('Profile updated successfully');
          return true;
        } else {
          _logger.error('Unexpected response content: ${response.body}');
          return false;
        }
      } else {
        _logger.error('Failed to update profile: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('Error updating profile: $e');
      return false;
    }
  }
}