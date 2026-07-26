// lib/domain/repositories/i_favorites_repository.dart

import '../../core/result/result.dart';
import '../entities/product.dart';

/// The customer's saved products.
abstract interface class IFavoritesRepository {
  /// Favourited products for a store.
  ///
  /// Favourites are per-store because price and availability are: the same
  /// product code can be favourited at one outlet and absent at another.
  Future<Result<List<Product>>> items({required String storeCode});

  /// Sets whether a product is favourited.
  ///
  /// Named `set`, not `toggle`: the backend call takes the desired state
  /// explicitly. The old `toggleFavorite(addToFavorites: ...)` name implied it
  /// flipped the current value, which it never did — callers had to know the
  /// current state and pass the opposite, and getting that wrong silently
  /// wrote the value the user already had.
  Future<Result<void>> setFavorite({
    required String productCode,
    required String storeCode,
    required bool isFavorite,
  });

  /// Whether a product is favourited.
  Future<Result<bool>> isFavorite({
    required String productCode,
    required String storeCode,
  });

  /// How many products are favourited at a store.
  Future<Result<int>> count({required String storeCode});
}
