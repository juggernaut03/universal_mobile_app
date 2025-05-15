// lib/data/repositories/order_repository.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/order_model.dart';
import '../repositories/auth_repository.dart'; // Make sure to import this

class OrderRepository {
  final http.Client _client;
  final AuthRepository _authRepository;
  final Logger _logger;

  OrderRepository({
    required http.Client client,
    required AuthRepository authRepository, // This parameter was missing
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
  
Future<List<Order>> getOrderHistoryWithCustomEndpoint(
  String mobileNumber,
  String accessKey,
  {required String customEndpoint}
) async {
  try {
    _logger.log('Fetching order history with custom endpoint: $customEndpoint');
    
    // Create the URI with the custom endpoint
    final uri = Uri.parse('${ApiConstants.baseUrl}$customEndpoint');
    
    // Create request body with mobile number and access key
    final requestBody = {
      'project_code': ApiConstants.projectCode,
      'mobile_number': mobileNumber,
      'access_key': accessKey,
      'store_code': 'KLK',  // Use the store code that works in Postman
    };
    
    _logger.log('Request details for custom endpoint: ${jsonEncode(requestBody)}');
    
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
    
    _logger.log('Custom endpoint response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      try {
        final dynamic jsonData = jsonDecode(response.body);
        
        // Handle different response formats
        if (jsonData is List) {
          _logger.log('Response is a list with ${jsonData.length} items');
          return jsonData.map((item) => Order.fromJson(item)).toList();
        } else if (jsonData is Map) {
          _logger.log('Response is a map with keys: ${jsonData.keys.toList()}');
          
          if (jsonData.containsKey('orders') && jsonData['orders'] is List) {
            final List orders = jsonData['orders'];
            return orders.map((item) => Order.fromJson(item)).toList();
          } else if (jsonData.containsKey('data') && jsonData['data'] is List) {
            final List orders = jsonData['data'];
            return orders.map((item) => Order.fromJson(item)).toList();
          } else {
            _logger.error('Expected orders array not found in response');
            return [];
          }
        } else {
          _logger.error('Unexpected response format');
          return [];
        }
      } catch (e) {
        _logger.error('Error parsing JSON response: $e');
        return [];
      }
    } else {
      _logger.error('Failed with custom endpoint: ${response.statusCode} - ${response.body}');
      return [];
    }
  } catch (e) {
    _logger.error('Error with custom endpoint: $e');
    return [];
  }
}

Future<String> _getStoreCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outletJson = prefs.getString(ApiConstants.keyOutlet);
      
      if (outletJson != null) {
        final outlet = jsonDecode(outletJson);
        return outlet['store_code'] ?? 'TTL'; // Default to TTL if not found
      }
      
      return 'TTL'; // Default store code
    } catch (e) {
      _logger.error('Error getting store code: $e');
      return 'TTL'; // Default store code on error
    }
  }
  // Get order history
  Future<List<Order>> getOrderHistory() async {
    try {
      // Get user profile to get mobile number and access key
      final userProfile = await _authRepository.getUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/get_orders_history');
       final storeCode = await _getStoreCode();
      // Create request body with mobile number and access key
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'mobile_number': userProfile.mobile,
        'access_key': userProfile.accessKey,
        'store_code': storeCode, 
        
      };
      
      _logger.log('Fetching order history for mobile: ${userProfile.mobile}');
      _logger.log('Request details: ${jsonEncode(requestBody)}');
      
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));
      
      _logger.log('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Just log the first part of the response for debugging
        _logger.log('Response preview: ${response.body.substring(0, min(100, response.body.length))}...');
        
        try {
          final dynamic jsonData = jsonDecode(response.body);
          
          // Handle different response formats
          if (jsonData is List) {
            _logger.log('Response is a list with ${jsonData.length} items');
            return jsonData.map((item) => Order.fromJson(item)).toList();
          } else if (jsonData is Map) {
            _logger.log('Response is a map with keys: ${jsonData.keys.toList()}');
            
            if (jsonData.containsKey('orders') && jsonData['orders'] is List) {
              final List orders = jsonData['orders'];
              return orders.map((item) => Order.fromJson(item)).toList();
            } else if (jsonData.containsKey('data') && jsonData['data'] is List) {
              final List orders = jsonData['data'];
              return orders.map((item) => Order.fromJson(item)).toList();
            } else {
              _logger.error('Expected orders array not found in response');
              return [];
            }
          } else {
            _logger.error('Unexpected response format');
            return [];
          }
        } catch (e) {
          _logger.error('Error parsing JSON response: $e');
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
      final storeCode = _getStoreCode();
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
}