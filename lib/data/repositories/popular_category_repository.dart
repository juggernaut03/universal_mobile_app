import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/popular_category_models.dart';

class PopularCategoryRepository {
  final ApiClient _apiClient;
  final Logger _logger;
  final DefaultCacheManager _cacheManager;
  
  static const int _cacheDurationHours = 20; // Cache duration of 20 hours
  static const String _categoryCacheKeyPrefix = 'popular_category_';
  static const String _timestampKeyPrefix = 'timestamp_';
  static const String _lastCacheClearKey = 'last_popular_category_cache_clear_time';

  PopularCategoryRepository({
    required ApiClient apiClient,
    Logger? logger,
    DefaultCacheManager? cacheManager,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger(),
        _cacheManager = cacheManager ?? DefaultCacheManager();

  // Fetch popular categories for a specific section (1-5)
  Future<PopularCategoryResponse> getPopularCategories({
    required int sectionId,
    required String departmentId,
    required String storeCode,
    bool forceRefresh = false,  // When true, bypass cache and fetch from API
  }) async {
    try {
      // Check if cache should be cleared (2 AM daily)
      await _checkAndClearCacheIfNeeded();
      
      final cacheKey = '${_categoryCacheKeyPrefix}${sectionId}_${departmentId}_$storeCode';
      
      final prefs = await SharedPreferences.getInstance();
      
      // Skip cache check if forceRefresh is true - always fetch from API
      if (!forceRefresh) {
        final cachedData = prefs.getString(cacheKey);
        final cachedTimestamp = prefs.getInt('${_timestampKeyPrefix}$cacheKey') ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        
        // Check if cache is valid (not older than cache duration)
        if (cachedData != null && (currentTime - cachedTimestamp < _cacheDurationHours * 3600000)) {
          _logger.log('Using cached popular categories data for section $sectionId');
          final Map<String, dynamic> decoded = jsonDecode(cachedData);
          return PopularCategoryResponse.fromJson(decoded);
        }
      } else {
        _logger.log('Force refresh enabled - bypassing cache for section $sectionId');
      }
      
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      _logger.log('Fetching popular categories for section $sectionId from API');

      // Universal backend: POST /api/popular-categories/list returns section
      // documents ordered by sequence; the legacy per-section endpoints map to
      // section index (sequence) here.
      final response = await _apiClient.post(
        ApiConstants.popularCategoriesList,
        body: {
          'store_code': storeCode,
          'include_inactive': false,
          'enrich_subcategories': true,
        },
      );

      final legacyJson = _sectionToLegacyJson(response, sectionId);
      final categoryResponse = PopularCategoryResponse.fromJson(legacyJson);

      if (categoryResponse.categoriesDetails.isNotEmpty) {
        // Cache the response (legacy shape so cached reads keep working)
        await prefs.setString(cacheKey, jsonEncode(legacyJson));
        await prefs.setInt('${_timestampKeyPrefix}$cacheKey', currentTime);

        // Pre-cache category images for better user experience
        _preCacheCategoryImages(categoryResponse.categoriesDetails);
      }

      return categoryResponse;
    } catch (e) {
      _logger.error('Error fetching popular categories for section $sectionId: $e');
      
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_categoryCacheKeyPrefix}${sectionId}_${departmentId}_$storeCode';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        _logger.log('Using expired cached categories data due to error');
        final Map<String, dynamic> decoded = jsonDecode(cachedData);
        return PopularCategoryResponse.fromJson(decoded);
      }
      
      // Return empty response if no cache available
      return PopularCategoryResponse(
        title: '',  // Empty title - let UI handle empty title display
        categoriesDetails: [],
      );
    }
  }

  /// Picks the section matching [sectionId] (by sequence, falling back to
  /// list position) and converts its enriched subcategories to the legacy
  /// {title, categories_details} shape PopularCategoryResponse parses.
  Map<String, dynamic> _sectionToLegacyJson(dynamic response, int sectionId) {
    final sections = response is Map ? (response['data'] as List? ?? []) : [];
    if (sections.isEmpty) return {'title': '', 'categories_details': []};

    Map<String, dynamic>? section;
    for (final s in sections) {
      if (s is Map<String, dynamic> && s['sequence'] == sectionId) {
        section = s;
        break;
      }
    }
    section ??= sectionId - 1 < sections.length &&
            sections[sectionId - 1] is Map<String, dynamic>
        ? sections[sectionId - 1] as Map<String, dynamic>
        : null;
    if (section == null) return {'title': '', 'categories_details': []};

    final items = <Map<String, dynamic>>[];
    final subcategories = section['subcategories'];
    if (subcategories is List) {
      for (final item in subcategories) {
        if (item is! Map<String, dynamic>) continue;
        final sub = item['subcategory_details'] is Map<String, dynamic>
            ? item['subcategory_details'] as Map<String, dynamic>
            : <String, dynamic>{};
        final cat = item['category_details'] is Map<String, dynamic>
            ? item['category_details'] as Map<String, dynamic>
            : <String, dynamic>{};

        items.add({
          '_id': (sub['id'] ?? item['sub_category_id'] ?? '').toString(),
          'idcategory_master':
              (cat['idcategory_master'] ?? sub['category_id'] ?? '').toString(),
          'category_name':
              (sub['sub_category_name'] ?? cat['category_name'] ?? '').toString(),
          'dept_id': (cat['dept_id'] ?? '').toString(),
          'sequence_id': item['position'] ?? 0,
          'store_code': '',
          'no_of_col': '4',
          'image_link': (item['image_link'] ?? '').toString(),
        });
      }
    }

    return {
      'title': section['title'] ?? '',
      'categories_details': items,
    };
  }

  // Pre-cache category images in the background
  Future<void> _preCacheCategoryImages(List<PopularCategoryItem> categories) async {
    for (final category in categories) {
      if (_isValidImageUrl(category.imageLink)) {
        try {
          await _cacheManager.downloadFile(
            category.imageLink,
            key: 'popular_category_${category.categoryId}',
          );
          _logger.log('Cached category image: ${category.imageLink}');
        } catch (e) {
          _logger.error('Error caching category image: $e');
          // Continue with next image on error
        }
      } else {
        _logger.error('Invalid category image URL for ${category.categoryName}: ${category.imageLink}');
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
        _logger.log('Clearing popular category cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt(_lastCacheClearKey, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking popular category cache clear schedule: $e');
      // Continue without clearing cache on error
    }
  }

  // Clear cache (for debugging or force refresh)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList(); // Create a copy to avoid concurrent modification
      
      for (final key in keys) {
        if (key.startsWith(_categoryCacheKeyPrefix) || 
            (key.startsWith(_timestampKeyPrefix) && 
            key.contains(_categoryCacheKeyPrefix))) {
          await prefs.remove(key);
          _logger.log('Removed cache key: $key');
        }
      }
      
      // Also clear image cache for popular category images
      await _cacheManager.emptyCache();
      
      _logger.log('Popular category cache cleared completely');
    } catch (e) {
      _logger.error('Error clearing popular category cache: $e');
    }
  }
}
