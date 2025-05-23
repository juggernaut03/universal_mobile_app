// lib/data/repositories/favorites_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/product_model.dart';
import '../../presentation/providers/auth_providers.dart';

class FavoritesRepository {
  final http.Client _client;
  final Logger _logger;
  
  static const String _addRemoveFavoritesUrl = '${ApiConstants.baseUrl}/add_remove_to_favorites';
  static const String _getFavoriteItemsUrl = '${ApiConstants.baseUrl}/get_favorite_items';
  static const String _cachedFavoritesKey = 'cached_favorites';

  FavoritesRepository({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  /// Get all favorite items for a user with robust error handling and retries
  Future<List<ProductModel>> getFavoriteItems({
    required String accessKey,
    required String mobileNo,
    required String storeCode,
  }) async {
    try {
      _logger.log('Fetching favorite items for user: $mobileNo');
      
      // Try up to 3 times with exponential backoff
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final response = await _client.post(
            Uri.parse(_getFavoriteItemsUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'access_key': accessKey,
              'mobile_no': mobileNo,
              'store_code': storeCode,
              'project_code': ApiConstants.projectCode,
            }),
          ).timeout(const Duration(seconds: 15));
          
          _logger.log('Get favorite items response status: ${response.statusCode}');
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            final responseData = jsonDecode(response.body);
            
            // Handle different response formats
            List<dynamic> favoriteItemsData = [];
            
            if (responseData is List) {
              favoriteItemsData = responseData;
            } else if (responseData is Map && responseData.containsKey('favorite_items')) {
              favoriteItemsData = responseData['favorite_items'] as List? ?? [];
            } else if (responseData is Map && responseData.containsKey('data')) {
              favoriteItemsData = responseData['data'] as List? ?? [];
            }
            
            // Convert to ProductModel objects
            final List<ProductModel> favoriteProducts = [];
            for (final item in favoriteItemsData) {
              try {
                final productModel = ProductModel(
                  id: item['_id']?.toString() ?? '',
                  pCode: item['p_code']?.toString() ?? '',
                  pcodeImg: item['pcode_img']?.toString() ?? '',
                  barcode: item['barcode']?.toString() ?? '',
                  productName: item['product_name']?.toString() ?? '',
                  productDescription: item['product_description']?.toString() ?? '',
                  packageSize: _parseDouble(item['package_size']),
                  packageUnit: item['package_unit']?.toString() ?? '',
                  productMrp: _parseDouble(item['product_mrp']),
                  ourPrice: _parseDouble(item['our_price']),
                  brandName: item['brand_name']?.toString() ?? '',
                  storeCode: item['store_code']?.toString() ?? storeCode,
                  pcodestatus: item['pcode_status']?.toString() ?? '',
                  deptId: item['dept_id']?.toString() ?? '',
                  categoryId: item['category_id']?.toString() ?? '',
                  subCategoryId: item['sub_category_id']?.toString() ?? '',
                  storeQuantity: _parseInt(item['store_quantity']),
                  maxQuantityAllowed: _parseInt(item['max_quantity_allowed']),
                );
                favoriteProducts.add(productModel);
              } catch (e) {
                _logger.error('Error parsing favorite item: $e');
              }
            }
            
            // Cache the favorites locally
            await _cacheFavorites(favoriteProducts);
            
            _logger.log('Successfully fetched ${favoriteProducts.length} favorite items');
            return favoriteProducts;
          } else {
            // On failure, wait and retry
            if (attempt < 2) {
              await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
              continue;
            }
            _logger.error('Failed to fetch favorite items: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            continue;
          }
          _logger.error('Error in attempt $attempt: $e');
        }
      }
      
      // If all attempts fail, try to load from local cache
      final cachedFavorites = await _loadCachedFavorites();
      if (cachedFavorites.isNotEmpty) {
        _logger.log('Returning ${cachedFavorites.length} favorites from local cache');
        return cachedFavorites;
      }
      
      return [];
    } catch (e) {
      _logger.error('Error fetching favorite items: $e');
      
      // Try to load from local cache on error
      final cachedFavorites = await _loadCachedFavorites();
      if (cachedFavorites.isNotEmpty) {
        _logger.log('Returning ${cachedFavorites.length} favorites from local cache after error');
        return cachedFavorites;
      }
      
      return [];
    }
  }

  /// Get list of favorite product codes only (for quick checks)
  Future<List<String>> getFavoriteProductCodes({
    required String accessKey,
    required String mobileNo,
    required String storeCode,
  }) async {
    try {
      final favoriteProducts = await getFavoriteItems(
        accessKey: accessKey,
        mobileNo: mobileNo,
        storeCode: storeCode,
      );
      
      return favoriteProducts.map((product) => product.pCode).toList();
    } catch (e) {
      _logger.error('Error getting favorite product codes: $e');
      return [];
    }
  }

  /// Add a product to favorites
  Future<bool> addToFavorites({
    required String accessKey,
    required String pCode,
    required String mobileNo,
    required String storeCode,
  }) async {
    try {
      _logger.log('Adding product $pCode to favorites');
      
      final response = await _client.post(
        Uri.parse(_addRemoveFavoritesUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_key': accessKey,
          'p_code': pCode,
          'mobile_no': mobileNo,
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
        }),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Add to favorites response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['message'] != null && 
            responseData['message'].toString().contains('Added to favorite')) {
          _logger.log('Product successfully added to favorites');
          
          // Update the cached favorites (add the new product)
          await _updateCachedFavoritesForToggle(pCode, true);
          
          return true;
        } else {
          _logger.error('Unexpected response format: ${response.body}');
          return false;
        }
      } else {
        _logger.error('Failed to add to favorites: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove a product from favorites
  Future<bool> removeFromFavorites({
    required String accessKey,
    required String pCode,
    required String mobileNo,
    required String storeCode,
  }) async {
    try {
      _logger.log('Removing product $pCode from favorites');
      
      final response = await _client.post(
        Uri.parse(_addRemoveFavoritesUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_key': accessKey,
          'p_code': pCode,
          'mobile_no': mobileNo,
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
        }),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Remove from favorites response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['message'] != null && 
            responseData['message'].toString().contains('Removed from favorite')) {
          _logger.log('Product successfully removed from favorites');
          
          // Update the cached favorites (remove the product)
          await _updateCachedFavoritesForToggle(pCode, false);
          
          return true;
        } else {
          _logger.error('Unexpected response format: ${response.body}');
          return false;
        }
      } else {
        _logger.error('Failed to remove from favorites: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('Error removing from favorites: $e');
      return false;
    }
  }

  // Local cache methods
  
  Future<void> _cacheFavorites(List<ProductModel> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedFavorites = favorites.map((product) => jsonEncode(product.toJson())).toList();
      await prefs.setStringList(_cachedFavoritesKey, encodedFavorites);
      _logger.log('Cached ${favorites.length} favorites locally');
    } catch (e) {
      _logger.error('Error caching favorites: $e');
    }
  }

  Future<List<ProductModel>> _loadCachedFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedFavorites = prefs.getStringList(_cachedFavoritesKey) ?? [];
      
      final favorites = encodedFavorites.map((encoded) {
        try {
          final json = jsonDecode(encoded);
          return ProductModel.fromJson(json);
        } catch (e) {
          _logger.error('Error parsing cached favorite: $e');
          return null;
        }
      }).whereType<ProductModel>().toList();
      
      _logger.log('Loaded ${favorites.length} favorites from cache');
      return favorites;
    } catch (e) {
      _logger.error('Error loading cached favorites: $e');
      return [];
    }
  }
  
  Future<void> _updateCachedFavoritesForToggle(String pCode, bool isAdding) async {
    try {
      final favorites = await _loadCachedFavorites();
      
      if (isAdding) {
        // If we're adding and don't have product details, don't modify cache
        // The next getFavoriteItems call will update the cache with full product details
        return;
      } else {
        // If we're removing, filter out the product
        final updatedFavorites = favorites.where((p) => p.pCode != pCode).toList();
        await _cacheFavorites(updatedFavorites);
      }
    } catch (e) {
      _logger.error('Error updating cached favorites for toggle: $e');
    }
  }

  // Helper methods
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }
}