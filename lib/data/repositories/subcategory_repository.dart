// lib/data/repositories/subcategory_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subcategory_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

class SubcategoryRepository {
  final http.Client _client;
  final String _baseUrl;
  final Logger _logger;
  
  static const int _cacheDurationHours = 20; // Cache duration of 20 hours
  static const String _subcategoriesKeyPrefix = 'subcategories_cache_cat_';
  static const String _timestampKeyPrefix = 'timestamp_';
  static const String _lastCacheClearKey = 'last_subcategory_cache_clear_time';

  SubcategoryRepository({
    http.Client? client,
    String? baseUrl,
    Logger? logger,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConstants.baseUrl,
       _logger = logger ?? Logger();

  Future<List<SubcategoryModel>> getSubcategories(String categoryId) async {
    try {
      await _checkAndClearCacheIfNeeded();
      
      final cacheKey = '$_subcategoriesKeyPrefix$categoryId';
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt('$_timestampKeyPrefix$cacheKey') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDurationHours * 3600000)) {
        _logger.log('Using cached subcategories data for category $categoryId');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => SubcategoryModel.fromJson(item)).toList();
      }

      _logger.log('Fetching subcategories for category $categoryId from API');
      // GET /api/subcategories returns every subcategory for the tenant;
      // filter by category_id client-side (the POST variant needs dept/store
      // context this screen does not have).
      final response = await _client.get(
        Uri.parse('$_baseUrl/subcategories?project_code=${ApiConstants.projectCode}'),
        headers: {
          'Content-Type': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data =
            decoded is Map ? (decoded['data'] as List? ?? []) : (decoded as List);
        final filtered = data
            .where((json) =>
                json is Map && json['category_id']?.toString() == categoryId)
            .toList();
        final subcategories =
            filtered.map((json) => SubcategoryModel.fromJson(json)).toList();

        // Cache the filtered subcategories for this category
        await prefs.setString(cacheKey, jsonEncode(filtered));
        await prefs.setInt('$_timestampKeyPrefix$cacheKey', currentTime);

        return subcategories;
      } else {
        throw Exception('Failed to load subcategories: ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Error fetching subcategories for category $categoryId: $e');
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_subcategoriesKeyPrefix$categoryId';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        _logger.log('Using expired cached subcategories data due to error');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => SubcategoryModel.fromJson(item)).toList();
      }
      rethrow;
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
        _logger.log('Clearing subcategory cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt(_lastCacheClearKey, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking subcategory cache clear schedule: $e');
      // Continue without clearing cache on error
    }
  }

  // Clear cache (for debugging or force refresh)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_subcategoriesKeyPrefix) ||
            key.startsWith('$_timestampKeyPrefix$_subcategoriesKeyPrefix')) {
          await prefs.remove(key);
        }
      }
      
      _logger.log('Subcategory cache cleared');
    } catch (e) {
      _logger.error('Error clearing subcategory cache: $e');
    }
  }
}