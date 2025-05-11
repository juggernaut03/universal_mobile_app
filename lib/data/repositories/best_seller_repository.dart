// lib/data/repositories/best_seller_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/product_model.dart';
import '../models/best_seller_models.dart';

class BestSellerRepository {
  final ApiClient _apiClient;
  final Logger _logger;
  final DefaultCacheManager _cacheManager;
  
  static const int _cacheDurationHours = 20; // Cache duration of 20 hours
  static const String _bannerCacheKeyPrefix = 'best_seller_banner_';
  static const String _productsCacheKeyPrefix = 'best_seller_products_';
  static const String _timestampKeyPrefix = 'timestamp_';
  static const String _lastCacheClearKey = 'last_best_seller_cache_clear_time';

  BestSellerRepository({
    required ApiClient apiClient,
    Logger? logger,
    DefaultCacheManager? cacheManager,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger(),
        _cacheManager = cacheManager ?? DefaultCacheManager();

  // Fetch banners for a specific best seller section
  Future<List<BestSellerBanner>> getBestSellerBanners(int bestSellerId) async {
    try {
      // Check if cache should be cleared (2 AM daily)
      await _checkAndClearCacheIfNeeded();
      
      final bannerTypeId = BestSellerConfig.getBannerTypeId(bestSellerId);
      final cacheKey = '$_bannerCacheKeyPrefix$bestSellerId';
      
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt('${_timestampKeyPrefix}$cacheKey') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDurationHours * 3600000)) {
        _logger.log('Using cached best seller banners data for ID $bestSellerId');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => BestSellerBanner.fromJson(item)).toList();
      }

      _logger.log('Fetching best seller banners for ID $bestSellerId from API');
      
      // Get the selected outlet for API request
      final storeCode = await _getStoreCode();
      
      final response = await _apiClient.post(
        ApiConstants.baseUrl + '/get_banner',
        body: {
          'banner_type_id': bannerTypeId,
          'store_code': storeCode,
          'platform': 'Android',
          'project_code': ApiConstants.projectCode,
        },
      );

      List<BestSellerBanner> banners = [];
      
      if (response is List) {
        // Direct array response
        banners = response.map((item) => BestSellerBanner.fromJson(item)).toList();
      } else if (response is Map && response.containsKey('data')) {
        // Response with data wrapper
        if (response['data'] is List) {
          banners = (response['data'] as List).map((item) => BestSellerBanner.fromJson(item)).toList();
        }
      } else {
        _logger.error('Invalid response format for banners: $response');
      }
      
      if (banners.isNotEmpty) {
        // Cache the banners
        await prefs.setString(cacheKey, jsonEncode(response));
        await prefs.setInt('${_timestampKeyPrefix}$cacheKey', currentTime);
        
        // Log the banner URLs for debugging
        for (var banner in banners) {
          _logger.log('Banner URL: ${banner.imageUrl}');
        }
        
        // Pre-cache banner images for better user experience
        _preCacheBannerImages(banners);
      }
      
      return banners;
    } catch (e) {
      _logger.error('Error fetching best seller banners for ID $bestSellerId: $e');
      
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_bannerCacheKeyPrefix$bestSellerId';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        _logger.log('Using expired cached banners data due to error');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => BestSellerBanner.fromJson(item)).toList();
      }
      
      return [];
    }
  }

  // Fetch products for a specific best seller section
  Future<List<ProductModel>> getBestSellerProducts(int bestSellerId) async {
    try {
      // Check if cache should be cleared (2 AM daily)
      await _checkAndClearCacheIfNeeded();
      
      final endpoint = BestSellerConfig.getProductEndpoint(bestSellerId);
      final cacheKey = '$_productsCacheKeyPrefix$bestSellerId';
      
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt('${_timestampKeyPrefix}$cacheKey') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDurationHours * 3600000)) {
        _logger.log('Using cached best seller products data for ID $bestSellerId');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => ProductModel.fromJson(item)).toList();
      }

      _logger.log('Fetching best seller products for ID $bestSellerId from API');
      
      // Get the selected outlet for API request
      final storeCode = await _getStoreCode();
      
      final response = await _apiClient.post(
        ApiConstants.baseUrl + '/' + endpoint,
        body: {
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
        },
      );

      if (response is List) {
        final products = response.map((item) => ProductModel.fromJson(item)).toList();
        
        // Cache the products
        await prefs.setString(cacheKey, jsonEncode(response));
        await prefs.setInt('${_timestampKeyPrefix}$cacheKey', currentTime);
        
        // Pre-cache product images for better user experience
        _preCacheProductImages(products);
        
        return products;
      } else {
        _logger.error('Invalid response format for products: $response');
        return [];
      }
    } catch (e) {
      _logger.error('Error fetching best seller products for ID $bestSellerId: $e');
      
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_productsCacheKeyPrefix$bestSellerId';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        _logger.log('Using expired cached products data due to error');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => ProductModel.fromJson(item)).toList();
      }
      
      return [];
    }
  }
  
  // Get the current store code from shared preferences
  Future<String> _getStoreCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outletJson = prefs.getString(ApiConstants.keyOutlet);
      
      if (outletJson != null) {
        final outlet = jsonDecode(outletJson);
        return outlet['store_code'] ?? 'TTL'; // Default to TTL if not found
      }
      
      return 'TTL'; // Default store code
    } catch (e) {
      _logger.error('Error getting store code: $e');
      return 'TTL'; // Default store code on error
    }
  }

  // Pre-cache banner images in the background
  Future<void> _preCacheBannerImages(List<BestSellerBanner> banners) async {
    for (final banner in banners) {
      if (_isValidImageUrl(banner.imageUrl)) {
        try {
          await _cacheManager.downloadFile(
            banner.imageUrl,
            key: 'banner_${banner.id}',
          );
          _logger.log('Cached banner image: ${banner.imageUrl}');
        } catch (e) {
          _logger.error('Error caching banner image: $e');
          // Continue with next image on error
        }
      } else {
        _logger.error('Invalid banner image URL: ${banner.imageUrl}');
      }
    }
  }

  // Pre-cache product images in the background
  Future<void> _preCacheProductImages(List<ProductModel> products) async {
    for (final product in products) {
      if (_isValidImageUrl(product.pcodeImg)) {
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
      } else {
        _logger.error('Invalid product image URL for ${product.productName}: ${product.pcodeImg}');
      }
    }
  }
  
  // Check if a URL is valid for image loading
  bool _isValidImageUrl(String url) {
    // Handle empty URLs
    if (url.isEmpty) return false;
    
    // Handle obvious invalid values
    if (url.contains('null') || url.contains('undefined')) return false;
    
    // If it starts with http:// or https://, it's an absolute URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return true;
    }
    
    // Handle relative URLs (starting with /)
    if (url.startsWith('/')) {
      // This is a relative URL, which might need to be combined with a base URL
      // For now, we'll consider it valid and rely on the image widget to handle it
      return true;
    }
    
    // Otherwise, it's probably not a valid URL
    return false;
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
        _logger.log('Clearing best seller cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt(_lastCacheClearKey, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking best seller cache clear schedule: $e');
      // Continue without clearing cache on error
    }
  }

  // Clear cache (for debugging or force refresh)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_bannerCacheKeyPrefix) || 
            key.startsWith(_productsCacheKeyPrefix) ||
            (key.startsWith(_timestampKeyPrefix) && 
            (key.contains(_bannerCacheKeyPrefix) || key.contains(_productsCacheKeyPrefix)))) {
          await prefs.remove(key);
        }
      }
      
      // Also clear image cache for best seller images
      await _cacheManager.emptyCache();
      
      _logger.log('Best seller cache cleared');
    } catch (e) {
      _logger.error('Error clearing best seller cache: $e');
    }
  }
}