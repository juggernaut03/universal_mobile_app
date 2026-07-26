// lib/data/repositories/favorites_repository_impl.dart

import '../../core/error/exceptions.dart';
import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/i_favorites_repository.dart';
import 'favorites_repository.dart';

final class FavoritesRepositoryImpl implements IFavoritesRepository {
  final FavoritesRepository _delegate;

  FavoritesRepositoryImpl({required FavoritesRepository delegate})
      : _delegate = delegate;

  @override
  Future<Result<List<Product>>> items({required String storeCode}) =>
      guard(() async {
        final models = await _delegate.getFavoriteItems(storeCode: storeCode);
        return models.map((m) => m.toEntity()).toList(growable: false);
      });

  @override
  Future<Result<void>> setFavorite({
    required String productCode,
    required String storeCode,
    required bool isFavorite,
  }) =>
      guard(() async {
        final ok = await _delegate.toggleFavorite(
          productId: productCode,
          storeCode: storeCode,
          addToFavorites: isFavorite,
        );
        if (!ok) {
          throw ServerException('Could not update favourite $productCode');
        }
      });

  @override
  Future<Result<bool>> isFavorite({
    required String productCode,
    required String storeCode,
  }) =>
      guard(() => _delegate.isProductFavorite(
            productId: productCode,
            storeCode: storeCode,
          ));

  @override
  Future<Result<int>> count({required String storeCode}) =>
      guard(() => _delegate.getFavoriteCount(storeCode: storeCode));
}
