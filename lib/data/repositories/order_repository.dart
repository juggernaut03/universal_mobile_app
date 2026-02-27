// lib/data/repositories/order_repository.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/order_model.dart';
import '../models/last_order_status_model.dart';
import '../repositories/auth_repository.dart';

class OrderRepository {
  final http.Client _client;
  final AuthRepository _authRepository;
  final Logger _logger;

  OrderRepository({
    required http.Client client,
    required AuthRepository authRepository,
    required Logger logger,
  }) : 
    _client = client,
    _authRepository = authRepository,
    _logger = logger;
  
  // Helper method to convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertMap(Map<dynamic, dynamic> map) {
    return map.map<String, dynamic>((key, value) {
      if (value is Map<dynamic, dynamic>) {
        return MapEntry(key.toString(), _convertMap(value));
      } else if (value is List) {
        return MapEntry(key.toString(), _convertList(value));
      } else {
        return MapEntry(key.toString(), value);
      }
    });
  }
  
  // Helper method to handle lists in the JSON
  List _convertList(List list) {
    return list.map((item) {
      if (item is Map<dynamic, dynamic>) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }
  
  // Get order history using the updated API
  Future<List<Order>> getOrderHistory() async {
    try {
      // Get user profile to get access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/get_orders_history');
      final storeCode = await _getStoreCode();
      
      // Updated request body to match the new API format
      final requestBody = {
        "access_key": userProfile.accessKey,
        "store_code": storeCode,
      };
      
      _logger.log('Fetching order history with updated API format');
      _logger.log('Request details: ${jsonEncode(requestBody)}');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      _logger.log('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        
        if (jsonData is List) {
          return jsonData.map((item) => Order.fromJson(item)).toList();
        } else if (jsonData is Map && jsonData.containsKey('orders')) {
          final List orders = jsonData['orders'];
          return orders.map((item) => Order.fromJson(item)).toList();
        } else {
          _logger.error('Unexpected response format');
          return [];
        }
      } else {
        _logger.error('Failed to fetch order history: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      _logger.error('Error fetching order history: $e');
      return [];
    }
  }

  Future<String> _getStoreCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outletJson = prefs.getString(ApiConstants.keyOutlet);
      
      if (outletJson != null) {
        final outlet = jsonDecode(outletJson);
        return outlet['store_code'] ?? 'KLK'; // Default to KLK as shown in API example
      }
      
      return 'KLK'; // Default store code
    } catch (e) {
      _logger.error('Error getting store code: $e');
      return 'KLK'; // Default store code on error
    }
  }
  
  // Get order details
  Future<Order?> getOrderDetails(String orderId) async {
    try {
      // Get user profile to get mobile number and access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/get_order_details');
      
      // Create request body with order ID, mobile number, and access key
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'mobile_number': userProfile.mobile,
        'access_key': userProfile.accessKey,
        'order_id': orderId,
        'store_code': 'KLK',
      };
      
      _logger.log('Fetching order details for order ID: $orderId');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        
        if (jsonData is Map) {
          // Convert the map to a Map<String, dynamic>
          final Map<String, dynamic> typedJsonData = 
              jsonData is Map<String, dynamic> ? jsonData : _convertMap(jsonData as Map<dynamic, dynamic>);
          
          // Parse the response into an Order object
          return Order.fromJson(typedJsonData);
        } else if (jsonData is List && jsonData.isNotEmpty) {
          final dynamic firstItem = jsonData[0];
          if (firstItem is Map) {
            final Map<String, dynamic> typedFirstItem = 
                firstItem is Map<String, dynamic> ? firstItem : _convertMap(firstItem as Map<dynamic, dynamic>);
                
            return Order.fromJson(typedFirstItem);
          } else {
            _logger.error('Unexpected item type in order details list: ${firstItem.runtimeType}');
            return null;
          }
        } else {
          _logger.error('Unexpected response format: ${response.body}');
          return null;
        }
      } else {
        _logger.error('Failed to fetch order details: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.error('Error fetching order details: $e');
      return null;
    }
  }
  
  // Cancel an order
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      // Get user profile to get mobile number and access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/cancel_order');
      
      // Create request body with order ID, reason, mobile number, and access key
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'mobile_number': userProfile.mobile,
        'access_key': userProfile.accessKey,
        'order_id': orderId,
        'cancel_reason': reason,
        'store_code': 'KLK',
      };
      
      _logger.log('Cancelling order with ID: $orderId for reason: $reason');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        final Map<String, dynamic> typedJsonData = 
            jsonData is Map<String, dynamic> ? jsonData : _convertMap(jsonData as Map<dynamic, dynamic>);
            
        if (typedJsonData.containsKey('message') && 
            typedJsonData['message'].toString().toLowerCase().contains('success')) {
          return true;
        } else {
          _logger.error('Order cancellation response: ${response.body}');
          return false;
        }
      } else {
        _logger.error('Failed to cancel order: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('Error cancelling order: $e');
      return false;
    }
  }
  
  // Reorder (create a new order based on a previous order)
  Future<bool> reorder(String orderId) async {
    try {
      // Get user profile to get mobile number and access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/reorder');
      final storeCode = await _getStoreCode();
      
      // Create request body with order ID, mobile number, and access key
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'mobile_number': userProfile.mobile,
        'access_key': userProfile.accessKey,
        'order_id': orderId,
        'store_code': storeCode,
      };
      
      _logger.log('Creating reorder for order ID: $orderId');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        final Map<String, dynamic> typedJsonData = 
            jsonData is Map<String, dynamic> ? jsonData : _convertMap(jsonData as Map<dynamic, dynamic>);
            
        if (typedJsonData.containsKey('message') && 
            typedJsonData['message'].toString().toLowerCase().contains('success')) {
          return true;
        } else {
          _logger.error('Reorder response: ${response.body}');
          return false;
        }
      } else {
        _logger.error('Failed to create reorder: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('Error creating reorder: $e');
      return false;
    }
  }

  // Get last order status
  Future<LastOrderStatus?> getLastOrderStatus() async {
    try {
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        _logger.log('User not logged in, cannot fetch last order status');
        return null; // Requires login properly now
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/get_last_order_status');
      final storeCode = await _getStoreCode();
      
      final requestBody = {
        'access_key': userProfile.accessKey,
        'mobile': userProfile.mobile,
        'store_code': storeCode,
        'project_code': ApiConstants.projectCode,
      };
      
      _logger.log('Fetching last order status');
      print('=== [OrderTracking] Request URL: $uri');
      print('=== [OrderTracking] Request Body: ${jsonEncode(requestBody)}');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      print('=== [OrderTracking] Response Status: ${response.statusCode}');
      print('=== [OrderTracking] Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        
        // API returns an array containing the object
        if (jsonData is List && jsonData.isNotEmpty) {
          final firstItem = jsonData[0];
          if (firstItem is Map) {
            final Map<String, dynamic> typedData = 
              firstItem is Map<String, dynamic> ? firstItem : _convertMap(firstItem as Map<dynamic, dynamic>);
            return LastOrderStatus.fromJson(typedData);
          }
        } else if (jsonData is Map) {
          final Map<String, dynamic> typedData = 
              jsonData is Map<String, dynamic> ? jsonData : _convertMap(jsonData as Map<dynamic, dynamic>);
          return LastOrderStatus.fromJson(typedData);
        }
        
        _logger.log('No recent order status found or unexpected format.');
        return null;
      } else {
        _logger.error('Failed to fetch last order status: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.error('Error fetching last order status: $e');
      return null;
    }
  }
}