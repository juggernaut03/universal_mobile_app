// lib/data/datasources/local/product_image_prefetcher.dart
//
// Extracted from ProductRepository._preCacheProductImages.
//
// The original awaited every image download sequentially inside the product
// fetch path. It was fire-and-forget at the call site, but each `await`
// still ran in series, so a listing of 40 products queued 40 sequential
// downloads behind one another.
//
// Prefetching is a best-effort optimisation: it must never fail a product
// fetch, so every error is swallowed deliberately and reported to the logger.

import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../core/utils/logger.dart';
import '../../models/product_model.dart';

/// Warms the image cache for a batch of products.
abstract interface class IProductImagePrefetcher {
  /// Downloads product imagery in the background. Never throws.
  void prefetch(List<ProductModel> products);

  /// Local file path for a previously cached image, or [originalUrl] when it
  /// is not cached.
  Future<String> cachedUrlFor(String productCode, String originalUrl);
}

final class ProductImagePrefetcher implements IProductImagePrefetcher {
  final BaseCacheManager _cacheManager;
  final Logger _logger;

  /// Cap on simultaneous downloads, so prefetching a large listing does not
  /// saturate the connection the user is browsing on.
  final int maxConcurrent;

  ProductImagePrefetcher({
    required BaseCacheManager cacheManager,
    required Logger logger,
    this.maxConcurrent = 4,
  })  : _cacheManager = cacheManager,
        _logger = logger;

  static String _keyFor(String productCode) => 'product_$productCode';

  @override
  void prefetch(List<ProductModel> products) {
    final targets = products
        .where((p) => p.pcodeImg.isNotEmpty)
        .toList(growable: false);
    if (targets.isEmpty) return;

    // Deliberately not awaited: this is a background optimisation and the
    // caller's product fetch must not wait on it.
    unawaited(_prefetchAll(targets));
  }

  Future<void> _prefetchAll(List<ProductModel> targets) async {
    for (var i = 0; i < targets.length; i += maxConcurrent) {
      final end = (i + maxConcurrent).clamp(0, targets.length);
      await Future.wait(
        targets.sublist(i, end).map(_prefetchOne),
      );
    }
  }

  Future<void> _prefetchOne(ProductModel product) async {
    try {
      await _cacheManager.downloadFile(
        product.pcodeImg,
        key: _keyFor(product.pCode),
      );
    } on Object catch (e) {
      // Best effort: a failed image download must not surface to the user or
      // fail the surrounding product fetch.
      _logger.warning('Image prefetch failed for ${product.pCode}: $e');
    }
  }

  @override
  Future<String> cachedUrlFor(String productCode, String originalUrl) async {
    try {
      final info = await _cacheManager.getFileFromCache(_keyFor(productCode));
      return info?.file.path ?? originalUrl;
    } on Object catch (e) {
      _logger.warning('Cache lookup failed for $productCode: $e');
      return originalUrl;
    }
  }
}
