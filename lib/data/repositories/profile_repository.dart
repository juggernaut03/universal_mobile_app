// lib/data/repositories/profile_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository.dart';

class ProfileRepository {
  final http.Client _client;
  final AuthRepository _authRepository;
  final Logger _logger;

  ProfileRepository({
    required http.Client client,
    required AuthRepository authRepository,
    required Logger logger,
  }) : 
    _client = client,
    _authRepository = authRepository,
    _logger = logger;
  
  // Get user profile details
  Future getUserProfileDetails() async {
    try {
      // Get user profile to get mobile number and access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/get_user_profile');
      
      // Create request body with mobile number and access key
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'mobile_number': userProfile.mobile,
        'access_key': userProfile.accessKey, // Add access key
      };
      
      _logger.log('Fetching user profile details for mobile: ${userProfile.mobile}');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map) {
          return jsonData;
        } else if (jsonData is List && jsonData.isNotEmpty) {
          return jsonData[0];
        } else {
          _logger.error('Unexpected response format: ${response.body}');
          return {};
        }
      } else {
        _logger.error('Failed to fetch profile details: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch profile details');
      }
    } catch (e) {
      _logger.error('Error fetching profile details: $e');
      rethrow;
    }
  }
  
  // Update user profile details
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      // Get user profile to get mobile number and access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/update_user_profile');
      
      // Add mobile number and access key to the request
      profileData['project_code'] = ApiConstants.projectCode;
      profileData['mobile_number'] = userProfile.mobile;
      profileData['access_key'] = userProfile.accessKey; // Add access key
      
      _logger.log('Updating profile for mobile: ${userProfile.mobile}');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('message') && 
            jsonData['message'].toString().toLowerCase().contains('success')) {
          return true;
        } else {
          _logger.error('Profile update response: ${response.body}');
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
  
  // Update user profile photo
  Future<bool> updateProfilePhoto(String photoUrl) async {
    try {
      // Get user profile to get mobile number and access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/update_profile_photo');
      
      // Create request body
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'mobile_number': userProfile.mobile,
        'access_key': userProfile.accessKey, // Add access key
        'profile_photo': photoUrl,
      };
      
      _logger.log('Updating profile photo for mobile: ${userProfile.mobile}');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('message') && 
            jsonData['message'].toString().toLowerCase().contains('success')) {
          return true;
        } else {
          _logger.error('Profile photo update response: ${response.body}');
          return false;
        }
      } else {
        _logger.error('Failed to update profile photo: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('Error updating profile photo: $e');
      return false;
    }
  }
}