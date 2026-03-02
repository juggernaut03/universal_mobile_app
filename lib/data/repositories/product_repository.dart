// lib/data/repositories/product_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/product_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

class ProductRepository {
  final http.Client _client;
  final String _baseUrl;
  final Logger _logger;
  final DefaultCacheManager _cacheManager;
  
  static const int _cacheDurationHours = 2; // Cache duration of 2 hours
  static const String _productsKeyPrefix = 'products_cache_';
  static const String _timestampKeyPrefix = 'timestamp_';
  static const String _lastCacheClearKey = 'last_product_cache_clear_time';
  static const String _sessionStartKey = 'product_cache_session_start';

  ProductRepository({
    http.Client? client,
    String? baseUrl,
    Logger? logger,
    DefaultCacheManager? cacheManager,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConstants.baseUrl,
       _logger = logger ?? Logger(),
       _cacheManager = cacheManager ?? DefaultCacheManager();

  Future<List<ProductModel>> getProducts({
    required String deptId,
    required String categoryId,
    required String subCategoryId,
    required String storeCode,
  }) async {
    try {
      await _checkAndClearCacheIfNeeded();
      
      // Create a unique cache key based on all parameters
      final cacheKey = '${_productsKeyPrefix}${deptId}_${categoryId}_${subCategoryId}_$storeCode';
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt('${_timestampKeyPrefix}$cacheKey') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDurationHours * 3600000)) {
        _logger.log('Using cached products data for filter: dept=$deptId, cat=$categoryId, subcat=$subCategoryId');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => ProductModel.fromJson(item)).toList();
      }

      _logger.log('Fetching products for dept=$deptId, cat=$categoryId, subcat=$subCategoryId from API');
      final response = await _client.post(
        Uri.parse('$_baseUrl/get_active_products_list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'dept_id': deptId,
          'category_id': categoryId,
          'sub_category_id': subCategoryId,
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products = data.map((json) => ProductModel.fromJson(json)).toList();
        
        // Cache the products
        await prefs.setString(cacheKey, response.body);
        await prefs.setInt('${_timestampKeyPrefix}$cacheKey', currentTime);
        
        // Pre-cache product images in background
        _preCacheProductImages(products);
        
        return products;
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Error fetching products: $e');
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_productsKeyPrefix}${deptId}_${categoryId}_${subCategoryId}_$storeCode';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        _logger.log('Using expired cached products data due to error');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => ProductModel.fromJson(item)).toList();
      }
      rethrow;
    }
  }

  // Pre-cache product images in the background
  Future<void> _preCacheProductImages(List<ProductModel> products) async {
    for (final product in products) {
      if (product.pcodeImg.isNotEmpty) {
        try {
          await _cacheManager.downloadFile(
            product.pcodeImg,
            key: 'product_${product.pCode}',
          );
          _logger.log('Cached product image: ${product.pcodeImg}');
        } catch (e) {
          _logger.error('Error caching product image: $e');
          // Continue with next image on error
        }
      }
    }
  }

  // Check if it's time to clear cache (2 AM daily)
  Future<void> _checkAndClearCacheIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastClearTime = prefs.getInt(_lastCacheClearKey) ?? 0;
      
      final now = DateTime.now();
      final lastClear = DateTime.fromMillisecondsSinceEpoch(lastClearTime);
      
      // Get today's 2 AM timestamp
      final todayTwoAm = DateTime(now.year, now.month, now.day, 2, 0, 0);
      
      // If current time is after 2 AM today and last clear was before 2 AM today
      if (now.isAfter(todayTwoAm) && lastClear.isBefore(todayTwoAm)) {
        _logger.log('Clearing product cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt(_lastCacheClearKey, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking product cache clear schedule: $e');
      // Continue without clearing cache on error
    }
  }

  // Clear cache (for debugging or force refresh)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_productsKeyPrefix) ||
            key.startsWith('${_timestampKeyPrefix}${_productsKeyPrefix}')) {
          await prefs.remove(key);
        }
      }
      
      _logger.log('Product cache cleared');
    } catch (e) {
      _logger.error('Error clearing product cache: $e');
    }
  }
  Future<ProductModel?> getProductByCode(String pCode, String storeCode) async {
  try {
    final response = await _client.post(
      Uri.parse('$_baseUrl/get_product_by_code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'p_code': pCode,
        'store_code': storeCode,
        'project_code': ApiConstants.projectCode,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return ProductModel.fromJson(data);
      } else if (data is List && data.isNotEmpty) {
        return ProductModel.fromJson(data[0]);
      }
    }
    return null;
  } catch (e) {
    _logger.error('Error fetching product by code: $e');
    return null;
  }
}
  // Get a cached image URL for a product if available
  Future<String> getCachedProductImageUrl(String productCode, String originalUrl) async {
    try {
      final cacheKey = 'product_$productCode';
      final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      if (fileInfo != null) {
        return fileInfo.file.path;
      }
      return originalUrl;
    } catch (e) {
      _logger.error('Error getting cached product image: $e');
      return originalUrl;
    }
  }
}