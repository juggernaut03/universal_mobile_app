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
  static const String _titleCacheKeyPrefix = 'best_seller_title_'; // New cache key for titles
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
        return decoded.map((item) => BestSellerBanner.fromJson(_castToStringMap(item))).toList();
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
        banners = response.map((item) => BestSellerBanner.fromJson(_castToStringMap(item))).toList();
      } else if (response is Map && response.containsKey('data')) {
        // Response with data wrapper
        if (response['data'] is List) {
          banners = (response['data'] as List).map((item) => BestSellerBanner.fromJson(_castToStringMap(item))).toList();
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
          _logger.log('Banner URL: ${banner.imageUrl}, Background Color: ${banner.backgroundColor}');
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
        return decoded.map((item) => BestSellerBanner.fromJson(_castToStringMap(item))).toList();
      }
      
      return [];
    }
  }

  // Fetch products for a specific best seller section - Updated to handle title
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
        final dynamic decoded = jsonDecode(cachedData);
        
        // Handle both old format (direct array) and new format (with title)
        if (decoded is List) {
          // Old format - direct array
          return decoded.map((item) => ProductModel.fromJson(_castToStringMap(item))).where((p) => p.isAvailable).toList();
        } else if (decoded is Map) {
          // New format - with title and bestseller_details
          final response = BestSellerProductsResponse.fromJson(_castToStringMap(decoded));
          return response.products.map((item) => ProductModel.fromJson(_castToStringMap(item))).where((p) => p.isAvailable).toList();
        }
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

      if (response is Map && response.containsKey('title') && response.containsKey('bestseller_details')) {
        // New API format with title and bestseller_details
        final bestSellerResponse = BestSellerProductsResponse.fromJson(_castToStringMap(response));
        final products = bestSellerResponse.products.map((item) => ProductModel.fromJson(_castToStringMap(item))).where((p) => p.isAvailable).toList();
        
        // Cache the entire response (including title)
        await prefs.setString(cacheKey, jsonEncode(response));
        await prefs.setInt('${_timestampKeyPrefix}$cacheKey', currentTime);
        
        // Cache the title separately for easy access
        await prefs.setString('$_titleCacheKeyPrefix$bestSellerId', bestSellerResponse.title);
        
        // Pre-cache product images for better user experience
        _preCacheProductImages(products);
        
        _logger.log('Cached best seller title for ID $bestSellerId: ${bestSellerResponse.title}');
        
        return products;
      } else if (response is List) {
        // Old API format - direct array of products
        final products = response.map((item) => ProductModel.fromJson(_castToStringMap(item))).where((p) => p.isAvailable).toList();
        
        // Cache the products
        await prefs.setString(cacheKey, jsonEncode(response));
        await prefs.setInt('${_timestampKeyPrefix}$cacheKey', currentTime);
        
        // Cache default title for backward compatibility
        final defaultTitle = BestSellerConfig.getDefaultTitle(bestSellerId);
        await prefs.setString('$_titleCacheKeyPrefix$bestSellerId', defaultTitle);
        
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
        final dynamic decoded = jsonDecode(cachedData);
        
        // Handle both old format (direct array) and new format (with title)
        if (decoded is List) {
          return decoded.map((item) => ProductModel.fromJson(_castToStringMap(item))).where((p) => p.isAvailable).toList();
        } else if (decoded is Map) {
          final response = BestSellerProductsResponse.fromJson(_castToStringMap(decoded));
          return response.products.map((item) => ProductModel.fromJson(_castToStringMap(item))).where((p) => p.isAvailable).toList();
        }
      }
      
      return [];
    }
  }
  
  // New method to get the title for a best seller section
  Future<String> getBestSellerTitle(int bestSellerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTitle = prefs.getString('$_titleCacheKeyPrefix$bestSellerId');
      
      if (cachedTitle != null) {
        _logger.log('Using cached title for best seller ID $bestSellerId: $cachedTitle');
        return cachedTitle;
      }
      
      // If no cached title, return default
      final defaultTitle = BestSellerConfig.getDefaultTitle(bestSellerId);
      _logger.log('Using default title for best seller ID $bestSellerId: $defaultTitle');
      return defaultTitle;
    } catch (e) {
      _logger.error('Error getting best seller title for ID $bestSellerId: $e');
      return BestSellerConfig.getDefaultTitle(bestSellerId);
    }
  }
  
  // Helper method to safely cast Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _castToStringMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      return Map<String, dynamic>.from(data);
    } else {
      _logger.error('Invalid data type for casting to Map<String, dynamic>: ${data.runtimeType}');
      throw ArgumentError('Expected Map but got ${data.runtimeType}');
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
          // Use a cache key that includes the background color
          final cacheKey = 'banner_${banner.id}_${banner.backgroundColor}';
          
          await _cacheManager.downloadFile(
            banner.imageUrl,
            key: cacheKey,
          );
          _logger.log('Cached banner image: ${banner.imageUrl} with key $cacheKey');
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
      final keys = prefs.getKeys().toList(); // Create a copy to avoid concurrent modification
      
      for (final key in keys) {
        if (key.startsWith(_bannerCacheKeyPrefix) || 
            key.startsWith(_productsCacheKeyPrefix) ||
            key.startsWith(_titleCacheKeyPrefix) || // Include title cache keys
            (key.startsWith(_timestampKeyPrefix) && 
            (key.contains(_bannerCacheKeyPrefix) || 
             key.contains(_productsCacheKeyPrefix) || 
             key.contains(_titleCacheKeyPrefix)))) {
          await prefs.remove(key);
          _logger.log('Removed cache key: $key');
        }
      }
      
      // Also clear image cache for best seller images
      await _cacheManager.emptyCache();
      
      _logger.log('Best seller cache cleared completely');
    } catch (e) {
      _logger.error('Error clearing best seller cache: $e');
    }
  }
}