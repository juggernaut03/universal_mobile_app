// lib/domain/repositories/i_product_repository.dart
//
// Declares WHAT the app can ask for. Never HOW.
//
// No mention of HTTP, SharedPreferences, cache expiry or image prefetching —
// those are implementation choices belonging to
// data/repositories/product_repository_impl.dart. A second implementation
// (in-memory fake, offline-first variant) must be substitutable without any
// caller noticing.

import '../../core/result/result.dart';
import '../entities/product.dart';

/// Read access to the product catalogue.
abstract interface class IProductRepository {
  /// Products within a department → category → sub-category at a given store.
  ///
  /// Returns only sellable products; out-of-stock and zero-priced entries are
  /// filtered out. An empty list is a success, not a failure.
  Future<Result<List<Product>>> getProducts({
    required String storeCode,
    required String departmentId,
    required String categoryId,
    required String subCategoryId,
  });

  /// A single product by its business code at a given store.
  ///
  /// Yields `Err(NotFoundFailure)` when no such product exists — distinct from
  /// `Err(NetworkFailure)`, which the previous `Future<ProductModel?>` signature
  /// could not express.
  Future<Result<Product>> getProductByCode({
    required String code,
    required String storeCode,
  });

  /// Drops every cached product payload.
  ///
  /// Used by the daily reset and by manual refresh.
  Future<Result<void>> clearCache();
}
