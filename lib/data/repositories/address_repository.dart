// lib/data/repositories/address_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/address_model.dart';

class AddressRepository {
  final http.Client _client;
  final Logger _logger;
  
  AddressRepository({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  // Add a new address - Exactly matching the Postman format
  Future<bool> addAddress(Address address) async {
    try {
      final accessKey = await _getAccessKey();
      if (accessKey == null || accessKey.isEmpty) {
        _logger.error('Access key is empty or null');
        return false;
      }
      
      // Format exactly as shown in the successful Postman request
      final requestData = {
        "idaddress_book": "12", // This is a default ID for new addresses as seen in Postman
        "project_code": ApiConstants.projectCode,
        "full_name": address.fullName.trim(),
        "access_key": accessKey,
        "mobile_number": address.mobileNumber.trim(),
        "email_id": address.emailId.trim(),
        "delivery_addr_line_1": address.deliveryAddrLine1.trim(),
        "delivery_addr_line_2": address.deliveryAddrLine2.trim(),
        "delivery_addr_city": address.deliveryAddrCity.trim(),
        "delivery_addr_pincode": address.deliveryAddrPincode.trim(),
        "is_default": address.isDefault,
        "latitude": "", // Empty string as shown in Postman
        "longitude": "", // Empty string as shown in Postman
        "area_id": address.areaId.isEmpty ? "1" : address.areaId,
      };
      
      _logger.log('Adding address with data: $requestData');
      
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/add_address'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Add address response status: ${response.statusCode}');
      _logger.log('Add address response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Check for exact success message wording from Postman
        if (responseData.containsKey('insertedItems') || 
            (responseData.containsKey('message') && 
             responseData['message'].toString().contains("Address Inserted Successfully"))) {
          _logger.log('Address added successfully');
          return true;
        }
      }
      
      _logger.error('Failed to add address: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      _logger.error('Error adding address: $e');
      return false;
    }
  }

  // Get all addresses for the current user - Fixed to match Postman collection
  Future<List<Address>> getAddresses() async {
    try {
      final accessKey = await _getAccessKey();
      if (accessKey == null || accessKey.isEmpty) {
        _logger.error('Access key is empty or null');
        return [];
      }
      
      // Create request body exactly as in Postman
      final requestData = {
        "access_key": accessKey,
        "project_code": ApiConstants.projectCode
      };
      
      _logger.log('Fetching addresses with access key: $accessKey');
      _logger.log('Request data: $requestData');
      
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/get_address_list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Get address list response status: ${response.statusCode}');
      _logger.log('Get address list response body: ${response.body}');
      
      if (response.statusCode == 200) {
        // Try to parse the response as a list first
        try {
          List<dynamic> addressesJson = jsonDecode(response.body);
          return addressesJson.map((json) => Address.fromJson(json)).toList();
        } catch (e) {
          // If list parsing fails, try to parse as a map with a data/addresses field
          final Map<String, dynamic> responseMap = jsonDecode(response.body);
          
          if (responseMap.containsKey('data') && responseMap['data'] is List) {
            List<dynamic> addressesJson = responseMap['data'];
            return addressesJson.map((json) => Address.fromJson(json)).toList();
          } else if (responseMap.containsKey('addresses') && responseMap['addresses'] is List) {
            List<dynamic> addressesJson = responseMap['addresses'];
            return addressesJson.map((json) => Address.fromJson(json)).toList();
          } else if (responseMap.containsKey('insertedItems') && responseMap['insertedItems'] is List) {
            List<dynamic> addressesJson = responseMap['insertedItems'];
            return addressesJson.map((json) => Address.fromJson(json)).toList();
          }
          
          _logger.error('Unexpected response format: $responseMap');
          return [];
        }
      } else {
        _logger.error('Failed to load addresses: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      _logger.error('Error fetching addresses: $e');
      return [];
    }
  }

  // Update an existing address - Fixed to match Postman collection
  Future<bool> updateAddress(Address address) async {
    try {
      final accessKey = await _getAccessKey();
      if (accessKey == null || accessKey.isEmpty) {
        _logger.error('Access key is empty or null');
        return false;
      }
      
      // Format exactly as shown in the Postman request
      final requestData = {
        "idaddress_book": address.id,
        "project_code": ApiConstants.projectCode,
        "full_name": address.fullName.trim(),
        "access_key": accessKey,
        "mobile_number": address.mobileNumber.trim(),
        "email_id": address.emailId.trim(),
        "delivery_addr_line_1": address.deliveryAddrLine1.trim(),
        "delivery_addr_line_2": address.deliveryAddrLine2.trim(),
        "delivery_addr_city": address.deliveryAddrCity.trim(),
        "delivery_addr_pincode": address.deliveryAddrPincode.trim(),
        "is_default": address.isDefault,
        "latitude": "",
        "longitude": "",
        "area_id": address.areaId.isEmpty ? "1" : address.areaId,
      };
      
      _logger.log('Updating address with ID ${address.id}');
      _logger.log('Update request data: $requestData');
      
      // First try the update_address/{id} endpoint
      var url = '${ApiConstants.baseUrl}/update_address/${address.id}';
      var response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Update address response status: ${response.statusCode}');
      _logger.log('Update address response body: ${response.body}');
      
      // If the first attempt fails, try the add_address endpoint
      if (response.statusCode != 200 && response.statusCode != 201) {
        _logger.log('First update attempt failed, trying add_address endpoint');
        url = '${ApiConstants.baseUrl}/add_address';
        response = await _client.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestData),
        ).timeout(const Duration(seconds: 15));
        
        _logger.log('Alternative update response status: ${response.statusCode}');
        _logger.log('Alternative update response body: ${response.body}');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey('message') && 
            responseData['message'].toString().toLowerCase().contains('success')) {
          _logger.log('Address updated successfully');
          return true;
        }
      }
      
      _logger.error('Failed to update address: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      _logger.error('Error updating address: $e');
      return false;
    }
  }

  // Delete an address - Fixed to match API requirements
  Future<bool> deleteAddress(String addressId) async {
    try {
      final accessKey = await _getAccessKey();
      if (accessKey == null || accessKey.isEmpty) {
        _logger.error('Access key is empty or null');
        return false;
      }
      
      final requestData = {
        "access_key": accessKey,
        "project_code": ApiConstants.projectCode
      };
      
      _logger.log('Deleting address with ID: $addressId');
      
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/delete_address/$addressId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Delete address response status: ${response.statusCode}');
      _logger.log('Delete address response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey('message') && 
            responseData['message'].toString().toLowerCase().contains('success')) {
          _logger.log('Address deleted successfully');
          return true;
        }
      }
      
      _logger.error('Failed to delete address: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      _logger.error('Error deleting address: $e');
      return false;
    }
  }

  // Improved helper method to get current access key from multiple storage locations
  Future<String?> _getAccessKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try to get access key from different storage formats
      
      // Try user_profile first (most common format)
      final authProfile = prefs.getString('user_profile');
      if (authProfile != null && authProfile.isNotEmpty) {
        final profileData = jsonDecode(authProfile);
        if (profileData is Map && profileData.containsKey('accessKey')) {
          return profileData['accessKey'];
        }
      }
      
      // Try direct access_key storage
      final directKey = prefs.getString('user_access_key');
      if (directKey != null && directKey.isNotEmpty) {
        return directKey;
      }
      
      // Try from OTP validation response
      final otpResponse = prefs.getString('otp_validation_response');
      if (otpResponse != null && otpResponse.isNotEmpty) {
        final responseData = jsonDecode(otpResponse);
        if (responseData is Map && responseData.containsKey('access_key')) {
          return responseData['access_key'];
        }
      }
      
      _logger.error('Could not find access key in any storage location');
      return null;
    } catch (e) {
      _logger.error('Error getting access key: $e');
      return null;
    }
  }
}