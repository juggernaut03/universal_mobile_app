// lib/data/services/recently_viewed_service.dart
//
// The shopper's recently viewed products, held on the device.
//
// Deliberately never sent to the server: browsing history is the most
// personal signal the app holds, and keeping it local is what lets the home
// feed stay public and cacheable. The `recently_viewed` section arrives as an
// empty placeholder and is filled from here.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/logger.dart';
import '../models/product_model.dart';

class RecentlyViewedService {
  final Logger _logger;

  /// Long enough to be a useful rail, short enough that the stored JSON stays
  /// small and the list still reads as "recent".
  static const int maxEntries = 20;

  static const String _key = 'recently_viewed_products';

  RecentlyViewedService({Logger? logger}) : _logger = logger ?? Logger();

  /// Records a product view, most recent first.
  ///
  /// Never throws: a failure to write history must not disturb the product
  /// screen the shopper is actually looking at.
  Future<void> record(ProductModel product) async {
    if (product.pCode.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _decode(prefs.getString(_key));

      // Re-viewing a product moves it to the front rather than duplicating it.
      entries.removeWhere((entry) => entry['p_code'] == product.pCode);
      entries.insert(0, product.toJson());

      if (entries.length > maxEntries) {
        entries.removeRange(maxEntries, entries.length);
      }

      await prefs.setString(_key, jsonEncode(entries));
    } catch (e) {
      _logger.error('Could not record recently viewed product: $e');
    }
  }

  /// Recently viewed products for [storeCode], most recent first.
  ///
  /// Filtered by store because a product held from a previous store is not
  /// purchasable here — tapping it would lead to a dead product page.
  Future<List<ProductModel>> load({required String storeCode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _decode(prefs.getString(_key));

      final products = <ProductModel>[];
      for (final entry in entries) {
        try {
          final product = ProductModel.fromJson(entry);
          if (storeCode.isNotEmpty && product.storeCode != storeCode) continue;
          products.add(product);
        } catch (_) {
          // One unreadable entry — written by an older build, say — must not
          // empty the whole rail.
        }
      }

      return products;
    } catch (e) {
      _logger.error('Could not read recently viewed products: $e');
      return const [];
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      _logger.error('Could not clear recently viewed products: $e');
    }
  }

  List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}
