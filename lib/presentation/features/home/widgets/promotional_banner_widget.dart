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

// Custom Page Controller for fade transitions
class FadeBannerController {
  late PageController _pageController;
  Timer? _autoPlayTimer;
  bool _isAutoPlay;
  Duration _autoPlayInterval;
  Duration _animationDuration;
  int _currentIndex = 0;
  List<PromotionalBanner> _banners = [];
  
  FadeBannerController({
    bool autoPlay = true,
    Duration autoPlayInterval = const Duration(seconds: 4),
    Duration animationDuration = const Duration(milliseconds: 800),
  }) : 
    _isAutoPlay = autoPlay,
    _autoPlayInterval = autoPlayInterval,
    _animationDuration = animationDuration {
    _pageController = PageController();
  }
  
  void initialize(List<PromotionalBanner> banners) {
    _banners = banners;
    if (_isAutoPlay && _banners.length > 1) {
      _startAutoPlay();
    }
  }
  
  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (timer) {
      if (_banners.isNotEmpty) {
        _currentIndex = (_currentIndex + 1) % _banners.length;
        _pageController.animateToPage(
          _currentIndex,
          duration: _animationDuration,
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  void stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }
  
  void resumeAutoPlay() {
    if (_isAutoPlay && _banners.length > 1) {
      _startAutoPlay();
    }
  }
  
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
  }
  
  PageController get pageController => _pageController;
  int get currentIndex => _currentIndex;
  
  void updateIndex(int index) {
    _currentIndex = index;
  }
}

// Promotional Banner Widget with Fade Transitions
class PromotionalBannerWidget extends ConsumerStatefulWidget {
  final double? height;
  final double? width;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration fadeTransitionDuration;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final bool showPageIndicator;
  final Color? indicatorActiveColor;
  final Color? indicatorInactiveColor;

  const PromotionalBannerWidget({
    Key? key,
    this.height = 280,
    this.width,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.fadeTransitionDuration = const Duration(milliseconds: 800),
    this.padding,
    this.borderRadius,
    this.showPageIndicator = true,
    this.indicatorActiveColor,
    this.indicatorInactiveColor,
  }) : super(key: key);

  @override
  ConsumerState<PromotionalBannerWidget> createState() => _PromotionalBannerWidgetState();
}

class _PromotionalBannerWidgetState extends ConsumerState<PromotionalBannerWidget>
    with TickerProviderStateMixin {
  late FadeBannerController _bannerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
    _bannerController = FadeBannerController(
      autoPlay: widget.autoPlay,
      autoPlayInterval: widget.autoPlayInterval,
      animationDuration: widget.fadeTransitionDuration,
    );
    
    _fadeController = AnimationController(
      duration: widget.fadeTransitionDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Start with fade in
    _fadeController.forward();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(promotionalBannersProvider);
    
    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) {
          return _buildEmptyPlaceholder(context);
        }
        
        // Initialize controller with banners
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _bannerController.initialize(banners);
        });
        
        return _buildBannerCarousel(context, banners);
      },
      loading: () => _buildLoadingIndicator(),
      error: (_, __) => _buildErrorPlaceholder(context),
    );
  }
  
  Widget _buildBannerCarousel(BuildContext context, List<PromotionalBanner> banners) {
    final finalWidth = widget.width ?? MediaQuery.of(context).size.width;
    
    return Container(
      height: widget.height,
      width: finalWidth,
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          // Banner PageView with Fade Transition
          FadeTransition(
            opacity: _fadeAnimation,
            child: PageView.builder(
              controller: _bannerController.pageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _bannerController.updateIndex(index);
                });
                
                // Add fade effect on page change
                _fadeController.reset();
                _fadeController.forward();
              },
              itemBuilder: (context, index) {
                return _buildBannerItem(context, banners[index]);
              },
            ),
          ),
          
          // Page Indicators
          if (widget.showPageIndicator && banners.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _buildPageIndicator(banners.length),
            ),
        ],
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
        // Pause auto-play briefly on tap
        _bannerController.stopAutoPlay();
        Timer(const Duration(seconds: 2), () {
          _bannerController.resumeAutoPlay();
        });
        
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
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          child: Stack(
            children: [
              // Background color layer
              Container(
                width: double.infinity,
                height: double.infinity,
                color: backgroundColor,
              ),
              
              // Banner image with fade-in loading
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: CachedNetworkImage(
                  key: ValueKey(banner.imageUrl),
                  imageUrl: banner.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: backgroundColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.indicatorActiveColor ?? AppColors.primary,
                        ),
                        strokeWidth: 2,
                      ),
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
                  fadeInDuration: const Duration(milliseconds: 300),
                  fadeOutDuration: const Duration(milliseconds: 200),
                ),
              ),
              
              // Subtle gradient overlay for better text readability (if needed)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPageIndicator(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentIndex == index
                ? widget.indicatorActiveColor ?? AppColors.primary
                : widget.indicatorInactiveColor ?? Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      height: widget.height,
      width: widget.width ?? MediaQuery.of(context).size.width,
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.indicatorActiveColor ?? AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyPlaceholder(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width ?? MediaQuery.of(context).size.width,
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Icon(
              Icons.image_outlined,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width ?? MediaQuery.of(context).size.width,
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
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
      ),
    );
  }
}