// lib/data/services/banner_service.dart
//
// Moved out of presentation/features/home/widgets/promotional_banner_widget.dart,
// where the model, the HTTP service and the widget all shared one file and the
// service provider was declared beside the UI that used it.

import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';

class PromotionalBanner {
  final String id;
  final String redirectLink;
  final String imageUrl;
  final bool isActive;
  final int bannerTypeId;
  final int sequenceId;
  final String storeCode;
  final String backgroundColor;

  PromotionalBanner({
    required this.id,
    required this.redirectLink,
    required this.imageUrl,
    required this.isActive,
    required this.bannerTypeId,
    required this.sequenceId,
    required this.storeCode,
    required this.backgroundColor,
  });

  factory PromotionalBanner.fromJson(Map<String, dynamic> json) {
    return PromotionalBanner(
      id: json['_id'] ?? '',
      redirectLink: json['redirect_link'] ?? '',
      imageUrl: json['banner_img'] ?? '',
      isActive: json['is_active'] == 'Enabled',
      bannerTypeId: int.tryParse(json['banner_type_id'].toString()) ?? 1,
      sequenceId: int.tryParse(json['sequence_id'].toString()) ?? 0,
      storeCode: json['store_code'] ?? '',
      backgroundColor: json['banner_bg_color'] ?? '#FFFFFF',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromotionalBanner &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Service to fetch and manage promotional banners
class BannerService {
  final ApiClient _apiClient;
  final Logger _logger;
  final DefaultCacheManager _cacheManager;
  
  // Constants for caching
  static const String _bannerCacheKey = 'promotional_banners';
  static const String _bannerCacheTimestampKey = 'promotional_banners_timestamp';
  static const String _lastCacheClearKey = 'last_banner_cache_clear_time';
  static const Duration _cacheDuration = Duration(hours: 20);
  
  BannerService({
    required ApiClient apiClient,
    required Logger logger,
    required DefaultCacheManager cacheManager,
  }) : 
    _apiClient = apiClient,
    _logger = logger,
    _cacheManager = cacheManager;
  
  Future<List<PromotionalBanner>> getPromotionalBanners(String storeCode) async {
    try {
      // Check if cache should be cleared (2 AM daily)
      await _checkAndClearCacheIfNeeded();
      
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_bannerCacheKey);
      final cachedTimestamp = prefs.getInt(_bannerCacheTimestampKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDuration.inMilliseconds)) {
        _logger.log('Using cached promotional banners data');
        
        try {
          final List<dynamic> decodedList = jsonDecode(cachedData);
          final List<PromotionalBanner> banners = decodedList
              .map((item) => PromotionalBanner.fromJson(item))
              .where((banner) => banner.storeCode == storeCode && banner.isActive)
              .toList();
          
          // Sort by sequence for consistent display order
          banners.sort((a, b) => a.sequenceId.compareTo(b.sequenceId));
          
          if (banners.isNotEmpty) {
            // Pre-cache images for better performance
            _preCacheBannerImages(banners);
            return banners;
          }
        } catch (e) {
          _logger.error('Error parsing cached banner data: $e');
          // Clear corrupted cache
          await prefs.remove(_bannerCacheKey);
          await prefs.remove(_bannerCacheTimestampKey);
        }
      }
      
      // Fetch fresh banners from API
      _logger.log('Fetching promotional banners from API for store: $storeCode');

      // Universal backend: POST /api/banners with the shared 'home_top'
      // section (same convention as the web PWA); response nests
      // data.banner_sections[].banners[].
      final response = await _apiClient.post(
        ApiConstants.banners,
        body: {
          "store_code": storeCode,
          "section_name": "home_top",
        },
      );

      final legacyList = _sectionsToLegacyBanners(response, storeCode);

      if (legacyList.isNotEmpty) {
        final List<PromotionalBanner> banners = legacyList
            .map((item) => PromotionalBanner.fromJson(item))
            .where((banner) => banner.isActive)
            .toList();

        // Sort by sequence for consistent display order
        banners.sort((a, b) => a.sequenceId.compareTo(b.sequenceId));

        // Cache the banners
        await prefs.setString(_bannerCacheKey, jsonEncode(legacyList));
        await prefs.setInt(_bannerCacheTimestampKey, currentTime);
        
        // Pre-cache banner images
        _preCacheBannerImages(banners);
        
        _logger.log('Successfully fetched and cached ${banners.length} promotional banners');
        return banners;
      } else {
        _logger.log('No promotional banners configured for store $storeCode');
        return [];
      }
    } catch (e) {
      _logger.error('Error fetching promotional banners: $e');
      
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_bannerCacheKey);
      
      if (cachedData != null) {
        try {
          _logger.log('Using expired cached banners data due to API error');
          final List<dynamic> decodedList = jsonDecode(cachedData);
          final List<PromotionalBanner> banners = decodedList
              .map((item) => PromotionalBanner.fromJson(item))
              .where((banner) => banner.storeCode == storeCode && banner.isActive)
              .toList();
          
          banners.sort((a, b) => a.sequenceId.compareTo(b.sequenceId));
          return banners;
        } catch (e) {
          _logger.error('Error parsing expired cached data: $e');
        }
      }
      
      return [];
    }
  }
  
  /// Flattens the universal /api/banners response
  /// (data.banner_sections[].banners[]) into legacy-keyed maps that
  /// PromotionalBanner.fromJson understands.
  List<Map<String, dynamic>> _sectionsToLegacyBanners(
      dynamic response, String storeCode) {
    final result = <Map<String, dynamic>>[];
    final data = response is Map ? response['data'] : null;
    final sections = data is Map ? (data['banner_sections'] as List? ?? []) : [];

    for (final section in sections) {
      if (section is! Map) continue;
      final banners = section['banners'];
      if (banners is! List) continue;
      for (final b in banners) {
        if (b is! Map) continue;
        final bannerUrls = b['banner_urls'] is Map ? b['banner_urls'] as Map : {};
        // banner_urls values are {desktop, mobile} maps keyed by asset name
        String imageUrl = (b['image_url'] ?? '').toString();
        for (final asset in bannerUrls.values) {
          if (asset is Map) {
            final mobile = (asset['mobile'] ?? asset['desktop'] ?? '').toString();
            if (mobile.isNotEmpty) {
              imageUrl = mobile;
              break;
            }
          }
        }
        final action = b['action'] is Map ? b['action'] as Map : {};

        result.add({
          '_id': (b['id'] ?? '').toString(),
          'redirect_link': (action['value'] ?? '').toString(),
          'banner_img': imageUrl,
          'is_active': b['is_active'] == false ? 'Disabled' : 'Enabled',
          'banner_type_id': 1,
          'sequence_id': b['sequence'] ?? 0,
          // The API already filtered by store; pin the requested code so the
          // cached-read filter (storeCode equality) keeps matching.
          'store_code': storeCode,
          'banner_bg_color': '#FFFFFF',
        });
      }
    }
    return result;
  }

  // Pre-cache banner images in the background
  Future<void> _preCacheBannerImages(List<PromotionalBanner> banners) async {
    for (final banner in banners) {
      if (banner.imageUrl.isNotEmpty && _isValidImageUrl(banner.imageUrl)) {
        try {
          await _cacheManager.downloadFile(
            banner.imageUrl,
            key: 'promotional_banner_${banner.id}',
          );
          _logger.log('Pre-cached promotional banner image: ${banner.imageUrl}');
        } catch (e) {
          _logger.error('Error pre-caching banner image: $e');
          // Continue with next image on error
        }
      }
    }
  }
  
  // Validate image URL
  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    if (url.contains('null') || url.contains('undefined')) return false;
    
    return url.startsWith('http://') || 
           url.startsWith('https://') || 
           url.startsWith('/');
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
        _logger.log('Clearing promotional banner cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt(_lastCacheClearKey, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking promotional banner cache clear schedule: $e');
    }
  }
  
  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bannerCacheKey);
      await prefs.remove(_bannerCacheTimestampKey);
      
      // Clear image cache for promotional banners
      await _cacheManager.emptyCache();
      
      _logger.log('Promotional banner cache cleared completely');
    } catch (e) {
      _logger.error('Error clearing promotional banner cache: $e');
    }
  }
}
