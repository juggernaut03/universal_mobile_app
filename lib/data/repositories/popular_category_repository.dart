import 'dart:convert';
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

  /// One cache entry per store holding every section, replacing the old
  /// per-section entries. Shares the `popular_category_` prefix so
  /// [clearCache] still sweeps it.
  static const String _sectionsCacheKeyPrefix = 'popular_category_sections_';
  static const String _timestampKeyPrefix = 'timestamp_';
  static const String _lastCacheClearKey = 'last_popular_category_cache_clear_time';

  /// The in-flight `/popular-categories/list` request, shared by every caller
  /// asking for the same store.
  ///
  /// The home screen renders five strips off this endpoint (sections 2-5 plus
  /// the seasonal strip, which is section 1), and pull-to-refresh asks for all
  /// of them again. Each used to issue its own request for the full section
  /// list and throw away every section but one. They now join a single fetch.
  static Future<List<dynamic>>? _inFlightSections;
  static String? _inFlightStoreCode;

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

      final sections = await _loadSections(
        storeCode: storeCode,
        forceRefresh: forceRefresh,
      );

      final categoryResponse =
          PopularCategoryResponse.fromJson(_sectionToLegacyJson(sections, sectionId));

      if (categoryResponse.categoriesDetails.isNotEmpty) {
        // Pre-cache category images for better user experience
        _preCacheCategoryImages(categoryResponse.categoriesDetails);
      }

      return categoryResponse;
    } catch (e) {
      _logger.error('Error fetching popular categories for section $sectionId: $e');

      // Try to get data from cache even if it's expired
      final stale = await _readCachedSections(storeCode, ignoreExpiry: true);
      if (stale != null) {
        _logger.log('Using expired cached categories data due to error');
        return PopularCategoryResponse.fromJson(
            _sectionToLegacyJson(stale, sectionId));
      }

      // Return empty response if no cache available
      return PopularCategoryResponse(
        title: '',  // Empty title - let UI handle empty title display
        categoriesDetails: [],
      );
    }
  }

  /// Returns every section for [storeCode], from memory, disk or the network —
  /// in that order — collapsing concurrent callers onto one request.
  Future<List<dynamic>> _loadSections({
    required String storeCode,
    required bool forceRefresh,
  }) async {
    // A request for this store is already running: join it. This holds for a
    // forced refresh too — the response it will deliver is just as fresh.
    final running = _inFlightSections;
    if (running != null && _inFlightStoreCode == storeCode) {
      _logger.log('Joining in-flight popular-categories request for $storeCode');
      return running;
    }

    if (!forceRefresh) {
      final cached = await _readCachedSections(storeCode);
      if (cached != null) {
        _logger.log('Using cached popular category sections for $storeCode');
        return cached;
      }
      // The disk read above yields; a concurrent caller may have started the
      // request while we waited on it.
      final startedWhileReading = _inFlightSections;
      if (startedWhileReading != null && _inFlightStoreCode == storeCode) {
        return startedWhileReading;
      }
    } else {
      _logger.log('Force refresh enabled - bypassing cache for $storeCode');
    }

    final request = _fetchSections(storeCode);
    _inFlightSections = request;
    _inFlightStoreCode = storeCode;
    try {
      return await request;
    } finally {
      if (identical(_inFlightSections, request)) {
        _inFlightSections = null;
        _inFlightStoreCode = null;
      }
    }
  }

  /// One network call for the whole section list.
  ///
  /// Universal backend: POST /api/popular-categories/list returns section
  /// documents ordered by sequence; the legacy per-section endpoints map to
  /// section index (sequence) here.
  Future<List<dynamic>> _fetchSections(String storeCode) async {
    _logger.log('Fetching popular category sections for $storeCode from API');

    final response = await _apiClient.post(
      ApiConstants.popularCategoriesList,
      body: {
        'store_code': storeCode,
        'include_inactive': false,
        'enrich_subcategories': true,
      },
    );

    final sections = response is Map ? (response['data'] as List? ?? []) : <dynamic>[];

    if (sections.isNotEmpty) {
      await _writeCachedSections(storeCode, sections);
    }

    return sections;
  }

  Future<List<dynamic>?> _readCachedSections(
    String storeCode, {
    bool ignoreExpiry = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_sectionsCacheKeyPrefix$storeCode';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData == null) return null;

      if (!ignoreExpiry) {
        final cachedTimestamp = prefs.getInt('$_timestampKeyPrefix$cacheKey') ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        if (age >= _cacheDurationHours * 3600000) return null;
      }

      final decoded = jsonDecode(cachedData);
      return decoded is List ? decoded : null;
    } catch (e) {
      _logger.error('Error reading cached popular category sections: $e');
      return null;
    }
  }

  Future<void> _writeCachedSections(String storeCode, List<dynamic> sections) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_sectionsCacheKeyPrefix$storeCode';
      await prefs.setString(cacheKey, jsonEncode(sections));
      await prefs.setInt(
          '$_timestampKeyPrefix$cacheKey', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _logger.error('Error caching popular category sections: $e');
    }
  }

  /// Picks the section matching [sectionId] (by sequence, falling back to
  /// list position) and converts its enriched subcategories to the legacy
  /// {title, categories_details} shape PopularCategoryResponse parses.
  Map<String, dynamic> _sectionToLegacyJson(List<dynamic> sections, int sectionId) {
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
      'category_bg_color': section['background_color'] ?? '#FFFFFF',
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
  //
  // Deliberately leaves any in-flight request alone. A pull-to-refresh clears
  // the cache from several call sites at once; dropping the shared request on
  // each one would split a single refresh back into several network calls, and
  // a response still in flight is newer than the cache being cleared anyway.
  // A store change is handled separately — requests are keyed by store code.
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
