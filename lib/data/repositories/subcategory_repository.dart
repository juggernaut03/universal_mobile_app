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
  static const String _allSubcategoriesKey = 'subcategories_cache_all';
  static const String _timestampKeyPrefix = 'timestamp_';
  static const String _lastCacheClearKey = 'last_subcategory_cache_clear_time';

  /// The in-flight `GET /subcategories` request, shared by every caller.
  /// Only the fallback path uses it — see [getSubcategories].
  static Future<List<dynamic>>? _inFlightAll;

  SubcategoryRepository({
    http.Client? client,
    String? baseUrl,
    Logger? logger,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConstants.baseUrl,
       _logger = logger ?? Logger();

  /// Subcategories of [categoryId].
  ///
  /// With [departmentId] and [storeCode] this asks the backend for just this
  /// category (POST /subcategories/get-subcategories). Without them — or if
  /// that returns nothing, which happens when the tenant's categories are not
  /// scoped to the store the caller passed — it falls back to the tenant-wide
  /// GET /subcategories and filters client-side.
  Future<List<SubcategoryModel>> getSubcategories(
    String categoryId, {
    String? departmentId,
    String? storeCode,
  }) async {
    try {
      await _checkAndClearCacheIfNeeded();

      final cached = await _readCache(_categoryCacheKey(categoryId));
      if (cached != null) {
        _logger.log('Using cached subcategories data for category $categoryId');
        return _toModels(cached);
      }

      if (departmentId != null &&
          departmentId.isNotEmpty &&
          storeCode != null &&
          storeCode.isNotEmpty) {
        final targeted = await _fetchForCategory(
          categoryId: categoryId,
          departmentId: departmentId,
          storeCode: storeCode,
        );

        if (targeted.isNotEmpty) {
          await _writeCache(_categoryCacheKey(categoryId), targeted);
          return _toModels(targeted);
        }

        _logger.log(
            'Targeted subcategory fetch returned nothing for category $categoryId '
            '(dept $departmentId, store $storeCode) — falling back to the full list');
      }

      final filtered = _filterByCategory(await _fetchAll(), categoryId);
      await _writeCache(_categoryCacheKey(categoryId), filtered);
      return _toModels(filtered);
    } catch (e) {
      _logger.error('Error fetching subcategories for category $categoryId: $e');
      // Try to get data from cache even if it's expired
      final stale = await _readCache(
        _categoryCacheKey(categoryId),
        ignoreExpiry: true,
      );
      if (stale != null) {
        _logger.log('Using expired cached subcategories data due to error');
        return _toModels(stale);
      }
      rethrow;
    }
  }

  /// POST /api/subcategories/get-subcategories — one category's worth of rows.
  ///
  /// Returns an empty list rather than throwing when the backend rejects or
  /// cannot resolve the request, so the caller can fall back.
  Future<List<dynamic>> _fetchForCategory({
    required String categoryId,
    required String departmentId,
    required String storeCode,
  }) async {
    _logger.log('Fetching subcategories for category $categoryId from API');

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/subcategories/get-subcategories'),
            headers: {
              'Content-Type': 'application/json',
              'X-Project-Code': ApiConstants.projectCode,
            },
            body: jsonEncode({
              'dept_id': departmentId,
              'store_code': storeCode,
              'project_code': ApiConstants.projectCode,
              'idcategory_master': categoryId,
            }),
          )
          .timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));

      if (response.statusCode != 200) {
        _logger.error(
            'Targeted subcategory fetch failed: ${response.statusCode} - ${response.body}');
        return const [];
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map ? (decoded['data'] as List? ?? const []) : const [];
    } catch (e) {
      _logger.error('Targeted subcategory fetch errored: $e');
      return const [];
    }
  }

  /// GET /api/subcategories — every subcategory the tenant has.
  ///
  /// The fallback path only. Cached whole and shared between concurrent callers
  /// so browsing several categories does not re-download the table each time.
  Future<List<dynamic>> _fetchAll() async {
    final cached = await _readCache(_allSubcategoriesKey);
    if (cached != null) {
      _logger.log('Using cached tenant-wide subcategory list');
      return cached;
    }

    final running = _inFlightAll;
    if (running != null) return running;

    final request = _requestAll();
    _inFlightAll = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightAll, request)) _inFlightAll = null;
    }
  }

  Future<List<dynamic>> _requestAll() async {
    _logger.log('Fetching the tenant-wide subcategory list from API');

    final response = await _client
        .get(
          Uri.parse('$_baseUrl/subcategories?project_code=${ApiConstants.projectCode}'),
          headers: {
            'Content-Type': 'application/json',
            'X-Project-Code': ApiConstants.projectCode,
          },
        )
        .timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));

    if (response.statusCode != 200) {
      throw Exception('Failed to load subcategories: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> data =
        decoded is Map ? (decoded['data'] as List? ?? []) : (decoded as List);

    await _writeCache(_allSubcategoriesKey, data);
    return data;
  }

  /// A row matches [categoryId] either by its primary `category_id`, or by
  /// being cross-mapped there via the backend's `category_ids` array (a
  /// subcategory can now belong to more than one category) — falls back to
  /// the bare field when `category_ids` isn't present, for older backends.
  List<dynamic> _filterByCategory(List<dynamic> rows, String categoryId) => rows
      .where((json) => json is Map && _matchesCategory(json, categoryId))
      .toList();

  bool _matchesCategory(Map json, String categoryId) {
    final categoryIds = json['category_ids'];
    if (categoryIds is List) {
      return categoryIds.map((id) => id.toString()).contains(categoryId);
    }
    return json['category_id']?.toString() == categoryId;
  }

  List<SubcategoryModel> _toModels(List<dynamic> rows) => rows
      .whereType<Map<String, dynamic>>()
      .map(SubcategoryModel.fromJson)
      .toList();

  String _categoryCacheKey(String categoryId) =>
      '$_subcategoriesKeyPrefix$categoryId';

  Future<List<dynamic>?> _readCache(String cacheKey, {bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      _logger.error('Error reading cached subcategories: $e');
      return null;
    }
  }

  Future<void> _writeCache(String cacheKey, List<dynamic> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(rows));
      await prefs.setInt(
          '$_timestampKeyPrefix$cacheKey', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _logger.error('Error caching subcategories: $e');
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
      final keys = prefs.getKeys().toList();

      for (final key in keys) {
        if (key.startsWith(_subcategoriesKeyPrefix) ||
            key.startsWith('$_timestampKeyPrefix$_subcategoriesKeyPrefix') ||
            key == _allSubcategoriesKey ||
            key == '$_timestampKeyPrefix$_allSubcategoriesKey') {
          await prefs.remove(key);
        }
      }

      _logger.log('Subcategory cache cleared');
    } catch (e) {
      _logger.error('Error clearing subcategory cache: $e');
    }
  }
}
