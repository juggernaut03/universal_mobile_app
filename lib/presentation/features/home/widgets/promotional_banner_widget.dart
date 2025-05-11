// lib/presentation/widgets/promotional_banner_widget.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_constants.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';


// Model to represent a promotional banner
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
}

// Provider for the Banner Service
final bannerServiceProvider = Provider<BannerService>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final logger = ref.watch(loggerProvider);
  final cacheManager = DefaultCacheManager();
  
  return BannerService(
    apiClient: apiClient,
    logger: logger,
    cacheManager: cacheManager,
  );
});

// Provider for promotional banners
final promotionalBannersProvider = FutureProvider<List<PromotionalBanner>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        return [];
      }
      
      final bannerService = ref.read(bannerServiceProvider);
      return await bannerService.getPromotionalBanners(outlet.storeCode);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Service to fetch and manage promotional banners
class BannerService {
  final ApiClient _apiClient;
  final Logger _logger;
  final DefaultCacheManager _cacheManager;
  
  // Constants for caching
  static const String _bannerCacheKey = 'promotional_banners';
  static const String _bannerCacheTimestampKey = 'promotional_banners_timestamp';
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
      // Check cache validity
      await _checkAndClearCacheIfNeeded();
      
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_bannerCacheKey);
      final cachedTimestamp = prefs.getInt(_bannerCacheTimestampKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDuration.inMilliseconds)) {
        _logger.log('Using cached promotional banners data');
        
        // Parse cached banners
        final List<dynamic> decodedList = jsonDecode(cachedData);
        final List<PromotionalBanner> banners = decodedList
            .map((item) => PromotionalBanner.fromJson(item))
            .where((banner) => banner.storeCode == storeCode && banner.isActive)
            .toList();
        
        // If we have banners for this store, return them
        if (banners.isNotEmpty) {
          _preCacheBannerImages(banners);
          return banners;
        }
      }
      
      // Fetch fresh banners from API
      _logger.log('Fetching promotional banners from API for store: $storeCode');
      
      final body = {
        "banner_type_id": 2,
        "store_code": storeCode,
        "project_code": ApiConstants.projectCode,
      };
      
      final response = await _apiClient.post(
        'https://newtech.shalviadvision.com/api/get_banner',
        body: body,
      );
      
      if (response is List) {
        final List<PromotionalBanner> banners = response
            .map((item) => PromotionalBanner.fromJson(item))
            .where((banner) => banner.isActive)
            .toList();
        
        // Cache the banners
        await prefs.setString(_bannerCacheKey, jsonEncode(response));
        await prefs.setInt(_bannerCacheTimestampKey, currentTime);
        
        // Pre-cache banner images
        _preCacheBannerImages(banners);
        
        return banners;
      } else {
        _logger.error('Unexpected response format: $response');
        return [];
      }
    } catch (e) {
      _logger.error('Error fetching promotional banners: $e');
      return [];
    }
  }
  
  // Pre-cache banner images in the background
  Future<void> _preCacheBannerImages(List<PromotionalBanner> banners) async {
    for (final banner in banners) {
      if (banner.imageUrl.isNotEmpty) {
        try {
          await _cacheManager.downloadFile(
            banner.imageUrl,
            key: 'banner_${banner.id}',
          );
          _logger.log('Cached banner image: ${banner.imageUrl}');
        } catch (e) {
          _logger.error('Error caching banner image: $e');
        }
      }
    }
  }
  
  // Check if it's time to clear cache (2 AM daily)
  Future<void> _checkAndClearCacheIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastClearTime = prefs.getInt('last_banner_cache_clear_time') ?? 0;
      
      final now = DateTime.now();
      final lastClear = DateTime.fromMillisecondsSinceEpoch(lastClearTime);
      
      // Get today's 2 AM timestamp
      final todayTwoAm = DateTime(now.year, now.month, now.day, 2, 0, 0);
      
      // If current time is after 2 AM today and last clear was before 2 AM today
      if (now.isAfter(todayTwoAm) && lastClear.isBefore(todayTwoAm)) {
        _logger.log('Clearing banner cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt('last_banner_cache_clear_time', now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking cache clear schedule: $e');
    }
  }
  
  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bannerCacheKey);
      await prefs.remove(_bannerCacheTimestampKey);
      
      // Also clear image cache
      await _cacheManager.emptyCache();
      
      _logger.log('Promotional banner cache cleared');
    } catch (e) {
      _logger.error('Error clearing banner cache: $e');
    }
  }
}

// Promotional Banner Widget
class PromotionalBannerWidget extends ConsumerWidget {
  final double? height;
  final double? width;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration autoPlayAnimationDuration;
  final bool enlargeCenterPage;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const PromotionalBannerWidget({
    Key? key,
    this.height = 180,
    this.width,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 3),
    this.autoPlayAnimationDuration = const Duration(milliseconds: 800),
    this.enlargeCenterPage = true,
    this.padding,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(promotionalBannersProvider);
    
    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) {
          return _buildEmptyPlaceholder(context);
        }
        
        return _buildBannerCarousel(context, banners);
      },
      loading: () => _buildLoadingIndicator(),
      error: (_, __) => _buildErrorPlaceholder(context),
    );
  }
  
  Widget _buildBannerCarousel(BuildContext context, List<PromotionalBanner> banners) {
    final finalWidth = width ?? MediaQuery.of(context).size.width;
    
    return Container(
      height: height,
      width: finalWidth,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: CarouselSlider.builder(
        itemCount: banners.length,
        itemBuilder: (context, index, _) {
          return _buildBannerItem(context, banners[index]);
        },
        options: CarouselOptions(
          height: height,
          aspectRatio: 16/9,
          viewportFraction: 0.95,
          enableInfiniteScroll: banners.length > 1,
          autoPlay: autoPlay && banners.length > 1,
          autoPlayInterval: autoPlayInterval,
          autoPlayAnimationDuration: autoPlayAnimationDuration,
          enlargeCenterPage: enlargeCenterPage,
          enlargeFactor: 0.15,
          scrollDirection: Axis.horizontal,
        ),
      ),
    );
  }
  
  Widget _buildBannerItem(BuildContext context, PromotionalBanner banner) {
    // Convert hex color string to Color
    Color backgroundColor;
    try {
      backgroundColor = Color(int.parse(banner.backgroundColor.replaceAll('#', '0xFF')));
    } catch (e) {
      backgroundColor = Colors.white;
    }
    
    return GestureDetector(
      onTap: () {
        if (banner.redirectLink.isNotEmpty) {
          final redirectPath = banner.redirectLink;
          // Check if it's a product detail link
          if (redirectPath.startsWith('product_details/')) {
            final productId = redirectPath.replaceFirst('product_details/', '');
            context.push('/product/$productId');
          }
          // Add other redirection types as needed
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: banner.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 2,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: backgroundColor,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey[400],
                  size: 50,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: height,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
  
  Widget _buildEmptyPlaceholder(BuildContext context) {
    return Container(
      height: height,
      width: width ?? MediaQuery.of(context).size.width,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 50,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      height: height,
      width: width ?? MediaQuery.of(context).size.width,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red[400],
              ),
              const SizedBox(height: 8),
              const Text(
                'Failed to load promotions',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}