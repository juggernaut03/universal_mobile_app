// lib/data/repositories/onboarding_repository.dart
//
// First-launch carousel content, managed in the admin panel under
// Mobile App > Screens > Onboarding (POST /api/onboarding/list).
//
// Onboarding runs before a store is selected, so the list is tenant-wide —
// there is no store_code to scope by.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/onboarding_slide_model.dart';

class OnboardingRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  static const String _cacheKey = 'onboarding_slides_cache';

  OnboardingRepository({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// Slides to show, in display order.
  ///
  /// Never throws and never returns empty: a tenant with no configured slides,
  /// a failed request on a fresh install, or a malformed response all fall back
  /// — to the cache first, then to the app's bundled set. Onboarding is the
  /// first thing a user sees, so an error here must not become a blank screen.
  Future<List<OnboardingSlideModel>> getSlides() async {
    try {
      final response = await _apiClient.post(ApiConstants.onboardingList);

      final raw = response is Map ? (response['data'] as List? ?? const []) : const [];
      final slides = raw
          .whereType<Map<String, dynamic>>()
          .map(OnboardingSlideModel.fromJson)
          .where((slide) => slide.isDisplayable)
          .toList();

      if (slides.isNotEmpty) {
        await _writeCache(slides);
        _logger.log('Onboarding: loaded ${slides.length} slide(s) from API');
        return slides;
      }

      // An empty list is a deliberate "this tenant has none configured", not a
      // failure — show the bundled set rather than a stale cached one.
      _logger.log('Onboarding: no slides configured, using bundled defaults');
      return OnboardingSlideModel.bundledDefaults;
    } catch (e) {
      _logger.error('Onboarding: fetch failed ($e) — falling back');
      final cached = await _readCache();
      if (cached != null && cached.isNotEmpty) {
        _logger.log('Onboarding: using ${cached.length} cached slide(s)');
        return cached;
      }
      return OnboardingSlideModel.bundledDefaults;
    }
  }

  Future<List<OnboardingSlideModel>?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;

      final decoded = jsonDecode(cached);
      if (decoded is! List) return null;

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(OnboardingSlideModel.fromJson)
          .where((slide) => slide.isDisplayable)
          .toList();
    } catch (e) {
      _logger.error('Onboarding: could not read cache: $e');
      return null;
    }
  }

  Future<void> _writeCache(List<OnboardingSlideModel> slides) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(slides.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      _logger.error('Onboarding: could not write cache: $e');
    }
  }
}
