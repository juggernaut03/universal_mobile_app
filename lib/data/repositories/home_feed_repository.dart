// lib/data/repositories/home_feed_repository.dart
//
// Fetches the server-defined home layout (POST /api/home/feed) and caches it.
//
// Like onboarding, this never throws and never returns empty: feed → cache →
// the layout the app shipped with. Home is the screen users land on, so a
// backend problem must degrade to "the old home" rather than to nothing.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/home_feed_models.dart';

class HomeFeedRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  static const String _cacheKeyPrefix = 'home_feed_cache_';

  HomeFeedRepository({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  String _cacheKey(String storeCode) => '$_cacheKeyPrefix$storeCode';

  Future<HomeFeed> getFeed({required String storeCode}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.homeFeed,
        body: {'store_code': storeCode},
      );

      if (response is! Map<String, dynamic>) {
        throw const FormatException('home feed response was not an object');
      }

      final feed = HomeFeed.fromJson(response);

      if (feed.isEmpty) {
        // A tenant with nothing configured still gets a working home rather
        // than a blank scroll view.
        _logger.log('Home feed: server returned no sections, using fallback layout');
        return HomeFeed.fallback;
      }

      await _writeCache(storeCode, feed);
      _logger.log('Home feed: ${feed.sections.length} section(s) from API');
      return feed;
    } catch (e) {
      _logger.error('Home feed: fetch failed ($e) — falling back');

      final cached = await _readCache(storeCode);
      if (cached != null && !cached.isEmpty) {
        _logger.log('Home feed: using ${cached.sections.length} cached section(s)');
        return cached;
      }

      return HomeFeed.fallback;
    }
  }

  Future<HomeFeed?> _readCache(String storeCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey(storeCode));
      if (cached == null) return null;

      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) return null;
      return HomeFeed.fromJson(decoded);
    } catch (e) {
      _logger.error('Home feed: could not read cache: $e');
      return null;
    }
  }

  Future<void> _writeCache(String storeCode, HomeFeed feed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(storeCode), jsonEncode(feed.toJson()));
    } catch (e) {
      _logger.error('Home feed: could not write cache: $e');
    }
  }
}
