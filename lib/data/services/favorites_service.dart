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
  
  static const String _apiEndpoint = '${ApiConstants.baseUrl}/add_remove_to_favorites';

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
  }) async {
    try {
      _logger.log('Toggling favorite status for product $pCode');
      
      final response = await _client.post(
        Uri.parse(_apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_key': accessKey,
          'p_code': pCode,
          'mobile_no': mobileNo,
          'store_code': storeCode,
        }),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Toggle favorite response status: ${response.statusCode}');
      
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
            _logger.error('Unexpected response message: $message');
            return FavoriteActionResult(
              success: false, 
              message: 'Unknown response: $message'
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
  /// 
  /// Note: This is a placeholder. The API doesn't appear to have an endpoint
  /// to retrieve favorite products, so this would need to be implemented
  /// when such an endpoint is available.
  Future<List<String>> getFavoriteProductCodes({
    required String accessKey,
    required String mobileNo,
    required String storeCode,
  }) async {
    // This would call an API endpoint to retrieve favorite products
    // For now, we'll return an empty list
    _logger.log('Getting favorite products (not implemented)');
    return [];
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