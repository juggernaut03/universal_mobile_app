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

  /// Get all favorite items for the current user.
  /// The universal backend returns favorite records (p_code + store_code
  /// only), so full product cards are hydrated via productdetails with
  /// bounded concurrency.
  Future<List<ProductModel>> getFavoriteItems({
    required String storeCode,
  }) async {
    return await makeAuthenticatedRequest<List<ProductModel>>(
      () async {
        logActivity('Fetching favorite items');

        final response = await postWithAuth(
          ApiConstants.favoritesGetByStore,
          body: {'store_code': storeCode},
        );

        if (response is! Map<String, dynamic> || response['data'] is! List) {
          logActivity('Unexpected favorites response format');
          return <ProductModel>[];
        }

        final pCodes = (response['data'] as List)
            .whereType<Map>()
            .map((f) => (f['p_code'] ?? '').toString())
            .where((code) => code.isNotEmpty)
            .toList();

        logActivity('Found ${pCodes.length} favorite p_code(s); hydrating products');
        if (pCodes.isEmpty) return <ProductModel>[];

        final products = <ProductModel>[];
        const batchSize = 5;
        for (var i = 0; i < pCodes.length; i += batchSize) {
          final batch = pCodes.skip(i).take(batchSize);
          final results = await Future.wait(batch.map((pCode) async {
            try {
              final detail = await post(
                ApiConstants.productDetails,
                body: {'p_code': pCode, 'store_code': storeCode},
              );
              final data =
                  detail is Map<String, dynamic> ? detail['data'] : null;
              if (data is Map<String, dynamic>) {
                return ProductModel.fromJson(data);
              }
            } catch (e) {
              logActivity('Error hydrating favorite $pCode: $e');
            }
            return null;
          }));
          products.addAll(results.whereType<ProductModel>());
        }

        logActivity('Hydrated ${products.length} favorite product(s)');
        return products;
      },
      onAuthError: () => <ProductModel>[],
    ) ?? <ProductModel>[];
  }

  /// Add or remove item from favorites
  Future<bool> toggleFavorite({
    required String productId,
    required String storeCode,
    required bool addToFavorites,
  }) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        final action = addToFavorites ? 'Adding to favorites' : 'Removing from favorites';
        logActivity('$action - Product: $productId, Store: $storeCode');

        final body = {
          'p_code': productId,
          'store_code': storeCode,
        };

        final response = addToFavorites
            ? await postWithAuth(ApiConstants.favoritesAdd, body: body)
            : await deleteWithAuth(ApiConstants.favoritesRemove, body: body);

        if (response is Map<String, dynamic> && response['success'] == true) {
          logActivity('✅ Successfully toggled favorite status');
          return true;
        }

        logActivity('❌ Favorite toggle failed: $response');
        return false;
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

  /// Get list of favorite product codes (for quick lookup) — no product
  /// hydration needed, the raw favorite records carry p_code.
  Future<Set<String>> getFavoriteProductCodes({required String storeCode}) async {
    return await makeAuthenticatedRequest<Set<String>>(
      () async {
        logActivity('Getting favorite product codes');

        final response = await postWithAuth(
          ApiConstants.favoritesGetByStore,
          body: {'store_code': storeCode},
        );

        if (response is Map<String, dynamic> && response['data'] is List) {
          final productCodes = (response['data'] as List)
              .whereType<Map>()
              .map((f) => (f['p_code'] ?? '').toString())
              .where((code) => code.isNotEmpty)
              .toSet();
          logActivity('Found ${productCodes.length} favorite product codes');
          return productCodes;
        }
        return <String>{};
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