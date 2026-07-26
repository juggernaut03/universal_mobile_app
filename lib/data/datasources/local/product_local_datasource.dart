// lib/data/datasources/local/product_local_datasource.dart
//
// Cache I/O only. No HTTP. The cache *policy* (how long is fresh, when the
// daily reset fires) is expressed by ProductCachePolicy and applied by the
// repository — this class just reads and writes.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/exceptions.dart';
import '../../models/product_model.dart';

/// A cached payload together with the moment it was written.
final class CachedProducts {
  final List<ProductModel> products;
  final DateTime cachedAt;

  const CachedProducts({required this.products, required this.cachedAt});
}

/// Local persistence for product listings.
abstract interface class IProductLocalDataSource {
  /// Reads a cached listing, or null when nothing is stored.
  Future<CachedProducts?> readProducts(String key);

  /// Writes a listing, stamping it with [now].
  Future<void> writeProducts(String key, List<ProductModel> products, DateTime now);

  /// Removes every product entry.
  Future<void> clear();

  /// Timestamp of the last full cache clear, or null if never cleared.
  Future<DateTime?> readLastClearTime();

  /// Records that a full clear happened at [now].
  Future<void> writeLastClearTime(DateTime now);
}

final class ProductLocalDataSource implements IProductLocalDataSource {
  final SharedPreferences _prefs;

  ProductLocalDataSource({required SharedPreferences prefs}) : _prefs = prefs;

  static const String _productsPrefix = 'products_cache_';
  static const String _timestampPrefix = 'timestamp_';
  static const String _lastClearKey = 'last_product_cache_clear_time';

  /// Cache key for one department/category/sub-category/store combination.
  static String keyFor({
    required String storeCode,
    required String departmentId,
    required String categoryId,
    required String subCategoryId,
  }) =>
      '$_productsPrefix${departmentId}_${categoryId}_${subCategoryId}_$storeCode';

  @override
  Future<CachedProducts?> readProducts(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return null;

    final millis = _prefs.getInt('$_timestampPrefix$key');
    if (millis == null) return null;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return CachedProducts(
        products: decoded
            .whereType<Map<String, dynamic>>()
            .map(ProductModel.fromJson)
            .toList(growable: false),
        cachedAt: DateTime.fromMillisecondsSinceEpoch(millis),
      );
    } on Object catch (e, st) {
      // Corrupt entry: drop it so the next read goes to the network rather
      // than failing forever on the same bad payload.
      await _prefs.remove(key);
      await _prefs.remove('$_timestampPrefix$key');
      throw CacheException(
        'Corrupt product cache entry for "$key"; entry discarded',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> writeProducts(
    String key,
    List<ProductModel> products,
    DateTime now,
  ) async {
    try {
      final payload =
          jsonEncode(products.map((p) => p.toJson()).toList(growable: false));
      await _prefs.setString(key, payload);
      await _prefs.setInt(
        '$_timestampPrefix$key',
        now.millisecondsSinceEpoch,
      );
    } on Object catch (e, st) {
      throw CacheException(
        'Could not write product cache entry for "$key"',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      final doomed = _prefs
          .getKeys()
          .where((k) =>
              k.startsWith(_productsPrefix) ||
              k.startsWith('$_timestampPrefix$_productsPrefix'))
          .toList(growable: false);

      for (final key in doomed) {
        await _prefs.remove(key);
      }
    } on Object catch (e, st) {
      throw CacheException(
        'Could not clear product cache',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<DateTime?> readLastClearTime() async {
    final millis = _prefs.getInt(_lastClearKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> writeLastClearTime(DateTime now) async {
    await _prefs.setInt(_lastClearKey, now.millisecondsSinceEpoch);
  }
}
