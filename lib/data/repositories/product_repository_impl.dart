// lib/data/repositories/product_repository_impl.dart
//
// Implements IProductRepository. Orchestrates collaborators; performs no I/O
// of its own.
//
// Replaces the 227-line ProductRepository, which did four jobs in one class:
// HTTP, SharedPreferences caching, image prefetching and cache scheduling.
// Those are now ProductRemoteDataSource, ProductLocalDataSource,
// ProductImagePrefetcher and ProductCachePolicy respectively.
//
// Behaviour deliberately preserved from the original:
//   * 2-hour cache freshness, daily reset at 2 AM
//   * unavailable products filtered out of listings
//   * on fetch failure, fall back to stale cache rather than failing outright

import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/i_product_repository.dart';
import '../models/product_model.dart';
import '../datasources/local/product_image_prefetcher.dart';
import '../datasources/local/product_local_datasource.dart';
import '../datasources/remote/product_remote_datasource.dart';
import 'product_cache_policy.dart';

final class ProductRepositoryImpl implements IProductRepository {
  final IProductRemoteDataSource _remote;
  final IProductLocalDataSource _local;
  final IProductImagePrefetcher _imagePrefetcher;
  final ProductCachePolicy _policy;
  final Logger _logger;

  /// Injected rather than calling `DateTime.now()` inline, so cache expiry and
  /// the daily reset are testable without waiting for real time.
  final DateTime Function() _clock;

  ProductRepositoryImpl({
    required IProductRemoteDataSource remote,
    required IProductLocalDataSource local,
    required IProductImagePrefetcher imagePrefetcher,
    required Logger logger,
    ProductCachePolicy policy = const ProductCachePolicy(),
    DateTime Function()? clock,
  })  : _remote = remote,
        _local = local,
        _imagePrefetcher = imagePrefetcher,
        _policy = policy,
        _logger = logger,
        _clock = clock ?? DateTime.now;

  @override
  Future<Result<List<Product>>> getProducts({
    required String storeCode,
    required String departmentId,
    required String categoryId,
    required String subCategoryId,
  }) async {
    final key = ProductLocalDataSource.keyFor(
      storeCode: storeCode,
      departmentId: departmentId,
      categoryId: categoryId,
      subCategoryId: subCategoryId,
    );

    await _runDailyResetIfDue();

    // 1. Fresh cache wins.
    final cached = await _readCacheQuietly(key);
    if (cached != null &&
        _policy.isFresh(cachedAt: cached.cachedAt, now: _clock())) {
      _logger.log('Product cache hit: $key');
      return Ok(_toAvailableEntities(cached.products));
    }

    // 2. Otherwise go to the network.
    final fetched = await guard(() async {
      final models = await _remote.fetchProducts(
        storeCode: storeCode,
        departmentId: departmentId,
        categoryId: categoryId,
        subCategoryId: subCategoryId,
      );
      await _writeCacheQuietly(key, models);
      _imagePrefetcher.prefetch(models);
      return _toAvailableEntities(models);
    });

    if (fetched case Ok(:final value)) return Ok(value);

    // 3. Network failed. Serve stale data rather than an error screen, matching
    //    the original behaviour — but only if something is actually cached.
    final failure = (fetched as Err<List<Product>>).failure;
    if (cached != null) {
      _logger.warning(
        'Product fetch failed (${failure.message}); serving stale cache for $key',
      );
      return Ok(_toAvailableEntities(cached.products));
    }

    _logger.error('Product fetch failed with no cache fallback: ${failure.message}');
    return Err(failure);
  }

  @override
  Future<Result<Product>> getProductByCode({
    required String code,
    required String storeCode,
  }) {
    return guard(() async {
      final model = await _remote.fetchProductByCode(
        code: code,
        storeCode: storeCode,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Result<void>> clearCache() => guard(() => _local.clear());

  // ---- internals ----

  /// Listings expose only sellable products; the rule lives on the entity.
  List<Product> _toAvailableEntities(List<ProductModel> models) => models
      .map((m) => m.toEntity())
      .where((p) => p.isAvailable)
      .toList(growable: false);

  /// Clears the whole product cache once per day at the configured hour.
  ///
  /// Failure here must not fail the surrounding fetch — a cache we could not
  /// clear is not a reason to deny the user their products.
  Future<void> _runDailyResetIfDue() async {
    try {
      final now = _clock();
      final lastCleared = await _local.readLastClearTime();
      if (!_policy.isDailyResetDue(lastClearedAt: lastCleared, now: now)) return;

      _logger.log('Running scheduled daily product cache reset');
      await _local.clear();
      await _local.writeLastClearTime(now);
    } on Object catch (e) {
      _logger.warning('Daily cache reset skipped: $e');
    }
  }

  /// A cache read problem should degrade to a network fetch, not an error.
  Future<CachedProducts?> _readCacheQuietly(String key) async {
    try {
      return await _local.readProducts(key);
    } on Object catch (e) {
      _logger.warning('Product cache read failed for $key: $e');
      return null;
    }
  }

  /// A cache write problem should not fail a successful fetch.
  Future<void> _writeCacheQuietly(String key, List<ProductModel> models) async {
    try {
      await _local.writeProducts(key, models, _clock());
    } on Object catch (e) {
      _logger.warning('Product cache write failed for $key: $e');
    }
  }
}
