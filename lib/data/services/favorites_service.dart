// lib/data/services/favorites_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/product_model.dart';

/// Service class to handle the favorites API interactions
class FavoritesService {
  final http.Client _client;
  final Logger _logger;
  
  static const String _addRemoveEndpoint = '${ApiConstants.baseUrl}/add_remove_to_favorites';
  static const String _getFavoritesEndpoint = '${ApiConstants.baseUrl}/get_favorite_items';

  FavoritesService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  /// Toggle a product's favorite status - returns true if successful
  /// 
  /// This function determines whether to add or remove based on the server response
  Future<FavoriteActionResult> toggleFavorite({
    required String accessKey,
    required String pCode,
    required String mobileNo,
    required String storeCode,
    required String projectCode,
  }) async {
    try {
      _logger.log('Toggling favorite status for product $pCode');
      
      final requestBody = {
        'access_key': accessKey,
        'p_code': pCode,
        'mobile_no': mobileNo,
        'store_code': storeCode,
        'project_code': projectCode,
      };
      
      _logger.log('Request body: $requestBody');
      
      final response = await _client.post(
        Uri.parse(_addRemoveEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Toggle favorite response status: ${response.statusCode}');
      _logger.log('Toggle favorite response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['message'] != null) {
          final message = responseData['message'].toString();
          
          if (message.contains('Added to favorite')) {
            _logger.log('Product $pCode added to favorites');
            return FavoriteActionResult(
              success: true, 
              isNowFavorite: true, 
              message: 'Added to favorites'
            );
          } else if (message.contains('Removed from favorite')) {
            _logger.log('Product $pCode removed from favorites');
            return FavoriteActionResult(
              success: true, 
              isNowFavorite: false, 
              message: 'Removed from favorites'
            );
          } else {
            _logger.log('Response message: $message');
            // Consider it successful even if message format is different
            return FavoriteActionResult(
              success: true, 
              message: message
            );
          }
        } else {
          _logger.error('Missing message in response: ${response.body}');
          return FavoriteActionResult(
            success: false, 
            message: 'Invalid response format'
          );
        }
      } else {
        _logger.error('API error: ${response.statusCode} - ${response.body}');
        return FavoriteActionResult(
          success: false, 
          message: 'Server error: ${response.statusCode}'
        );
      }
    } catch (e) {
      _logger.error('Error toggling favorite: $e');
      return FavoriteActionResult(
        success: false, 
        message: 'Connection error: $e'
      );
    }
  }

  /// Get favorite products for a user
  Future<List<ProductModel>> getFavoriteItems({
    required String accessKey,
    required String mobileNo,
    required String storeCode,
    required String projectCode,
  }) async {
    try {
      _logger.log('Getting favorite items for user $mobileNo');
      
      final requestBody = {
        'access_key': accessKey,
        'mobile_no': mobileNo,
        'store_code': storeCode,
        'project_code': projectCode,
      };
      
      _logger.log('Get favorites request body: $requestBody');
      
      final response = await _client.post(
        Uri.parse(_getFavoritesEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Get favorites response status: ${response.statusCode}');
      _logger.log('Get favorites response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isEmpty) {
          _logger.log('Empty response body');
          return [];
        }
        
        final responseData = jsonDecode(response.body);
        
        // Check if response is a list (array of favorite items)
        if (responseData is List) {
          final favoriteItems = responseData.cast<Map<String, dynamic>>();
          
          final products = favoriteItems.map((item) {
            try {
              return ProductModel.fromJson(item);
            } catch (e) {
              _logger.error('Error parsing favorite item: $e');
              _logger.error('Item data: $item');
              return null;
            }
          }).where((product) => product != null).cast<ProductModel>().toList();
          
          _logger.log('Successfully parsed ${products.length} favorite items');
          return products;
        } 
        // Check if response is an object with favorite items array
        else if (responseData is Map<String, dynamic> && responseData.containsKey('favoriteItems')) {
          final favoriteItems = responseData['favoriteItems'] as List<dynamic>;
          
          final products = favoriteItems.map((item) {
            try {
              return ProductModel.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              _logger.error('Error parsing favorite item: $e');
              return null;
            }
          }).where((product) => product != null).cast<ProductModel>().toList();
          
          _logger.log('Successfully parsed ${products.length} favorite items from object');
          return products;
        } else {
          _logger.error('Unexpected response format: ${responseData.runtimeType}');
          _logger.error('Response data: $responseData');
          return [];
        }
      } else {
        _logger.error('API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      _logger.error('Error getting favorite items: $e');
      return [];
    }
  }

  /// Get favorite product codes for a user (lightweight version)
  Future<List<String>> getFavoriteProductCodes({
    required String accessKey,
    required String mobileNo,
    required String storeCode,
    required String projectCode,
  }) async {
    try {
      final favoriteItems = await getFavoriteItems(
        accessKey: accessKey,
        mobileNo: mobileNo,
        storeCode: storeCode,
        projectCode: projectCode,
      );
      
      return favoriteItems.map((product) => product.pCode).toList();
    } catch (e) {
      _logger.error('Error getting favorite product codes: $e');
      return [];
    }
  }
}

/// Result class for favorite actions
class FavoriteActionResult {
  final bool success;
  final bool isNowFavorite;
  final String message;
  
  FavoriteActionResult({
    required this.success,
    this.isNowFavorite = false,
    required this.message,
  });
}