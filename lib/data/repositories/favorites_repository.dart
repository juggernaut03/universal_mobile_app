// lib/data/repositories/favorites_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../models/product_model.dart';
import 'base_repository.dart';

class FavoritesRepository extends BaseRepository {
  
  FavoritesRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });

  /// Get all favorite items for the current user using centralized auth
  Future<List<ProductModel>> getFavoriteItems({
    required String storeCode,
  }) async {
    return await makeAuthenticatedRequest<List<ProductModel>>(
      () async {
        logActivity('Fetching favorite items');

        final mobile = await getUserMobile();
        if (mobile == null) {
          logActivity('No mobile number found');
          return <ProductModel>[];
        }
        
        // The postWithAuth method automatically adds access_key and project_code
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/get_favorite_items',
          body: {
            'mobile_no': mobile,
            'store_code': storeCode,
          },
        );
        
        logActivity('🔥 Get favorites API response: $response');
        
        // Handle different response formats
        if (response is List) {
          // Response is directly an array of favorite items
          final favoriteItems = response.cast<Map<String, dynamic>>();
          final products = favoriteItems
              .map((item) {
                try {
                  return ProductModel.fromJson(item);
                } catch (e) {
                  logActivity('Error parsing favorite item: $e');
                  return null;
                }
              })
              .where((product) => product != null)
              .cast<ProductModel>()
              .toList();
          
          logActivity('Successfully fetched ${products.length} favorite items from array');
          return products;
        } else if (response is Map<String, dynamic>) {
          // Check if response contains favoriteItems key
          if (response.containsKey('favoriteItems')) {
            final favoriteItems = response['favoriteItems'] as List<dynamic>;
            final products = favoriteItems
                .map((item) {
                  try {
                    return ProductModel.fromJson(item as Map<String, dynamic>);
                  } catch (e) {
                    logActivity('Error parsing favorite item: $e');
                    return null;
                  }
                })
                .where((product) => product != null)
                .cast<ProductModel>()
                .toList();
            
            logActivity('Successfully fetched ${products.length} favorite items from object');
            return products;
          }
          // Check if response contains items directly at root level
          else if (response.containsKey('items') || response.containsKey('data')) {
            final itemsKey = response.containsKey('items') ? 'items' : 'data';
            final favoriteItems = response[itemsKey] as List<dynamic>;
            final products = favoriteItems
                .map((item) {
                  try {
                    return ProductModel.fromJson(item as Map<String, dynamic>);
                  } catch (e) {
                    logActivity('Error parsing favorite item: $e');
                    return null;
                  }
                })
                .where((product) => product != null)
                .cast<ProductModel>()
                .toList();
            
            logActivity('Successfully fetched ${products.length} favorite items from $itemsKey');
            return products;
          }
          // Response might be an error message object
          else {
            final message = response['message']?.toString() ?? 'Unknown error';
            logActivity('API response contains message: $message');
            return <ProductModel>[];
          }
        }
        
        logActivity('Unexpected response format: ${response.runtimeType}');
        logActivity('Response content: $response');
        return <ProductModel>[];
      },
      onAuthError: () => <ProductModel>[],
    ) ?? <ProductModel>[];
  }

  /// Add or remove item from favorites using centralized auth
  Future<bool> toggleFavorite({
    required String productId,
    required String storeCode,
    required bool addToFavorites,
  }) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        final action = addToFavorites ? 'Adding to favorites' : 'Removing from favorites';
        logActivity('🔥 $action - Product: $productId, Store: $storeCode');

        final mobile = await getUserMobile();
        if (mobile == null) {
          logActivity('❌ No mobile number found');
          return false;
        }
        
        logActivity('📱 Mobile number: $mobile');
        
        // The postWithAuth method automatically adds access_key and project_code
        final requestBody = {
          'mobile_no': mobile,
          'p_code': productId,
          'store_code': storeCode,
        };
        
        logActivity('🔥 Making favorites API call with body: $requestBody');
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/add_remove_to_favorites',
          body: requestBody,
        );
        
        logActivity('🔥 Favorites API response: $response');
        
        if (response is Map<String, dynamic>) {
          final message = response['message']?.toString() ?? '';
          logActivity('📋 Response message: "$message"');
          
          // Check for both success patterns and specific favorite messages
          if (message.toLowerCase().contains('success') ||
              message.toLowerCase().contains('added to favorite') ||
              message.toLowerCase().contains('removed from favorite') ||
              message.contains('Added to favorite') ||
              message.contains('Removed from favorite')) {
            logActivity('✅ Successfully toggled favorite status: $message');
            return true;
          }
          
          // Check for error messages
          if (message.toLowerCase().contains('error') || 
              message.toLowerCase().contains('failed') ||
              message.toLowerCase().contains('invalid')) {
            logActivity('❌ API returned error message: $message');
            return false;
          }
          
          // If message exists but doesn't match known patterns, consider it successful
          if (message.isNotEmpty) {
            logActivity('⚠️ Unknown message format but assuming success: $message');
            return true;
          }
          
          logActivity('❌ Empty or missing message in response');
          return false;
        } else {
          logActivity('❌ Unexpected response type: ${response.runtimeType}');
          logActivity('🔍 Response content: $response');
          return false;
        }
      },
      onAuthError: () {
        logActivity('❌ Authentication error in toggleFavorite');
        return false;
      },
    ) ?? false;
  }

  /// Check if a product is in favorites using centralized auth
  Future<bool> isProductFavorite({
    required String productId,
    required String storeCode,
  }) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Checking favorite status for product: $productId');

        final favorites = await getFavoriteItems(storeCode: storeCode);
        final isFavorite = favorites.any((product) => product.pCode == productId);
        
        logActivity('Product $productId favorite status: $isFavorite');
        return isFavorite;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Get favorite products count using centralized auth
  Future<int> getFavoriteCount({required String storeCode}) async {
    return await makeAuthenticatedRequest<int>(
      () async {
        logActivity('Getting favorite count');

        final favorites = await getFavoriteItems(storeCode: storeCode);
        final count = favorites.length;
        
        logActivity('Favorite count: $count');
        return count;
      },
      onAuthError: () => 0,
    ) ?? 0;
  }

  /// Get list of favorite product codes (for quick lookup)
  Future<Set<String>> getFavoriteProductCodes({required String storeCode}) async {
    return await makeAuthenticatedRequest<Set<String>>(
      () async {
        logActivity('Getting favorite product codes');

        final favorites = await getFavoriteItems(storeCode: storeCode);
        final productCodes = favorites.map((product) => product.pCode).toSet();
        
        logActivity('Found ${productCodes.length} favorite product codes');
        return productCodes;
      },
      onAuthError: () => <String>{},
    ) ?? <String>{};
  }
}

/// Provider for FavoritesRepository using centralized dependencies
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final dependencies = ref.watch(baseRepositoryDependenciesProvider);
  
  return FavoritesRepository(
    authManager: dependencies.authManager,
    apiClient: dependencies.apiClient,
    logger: dependencies.logger,
  );
});