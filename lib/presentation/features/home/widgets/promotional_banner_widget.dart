// lib/presentation/widgets/promotional_banner_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/data/services/banner_service.dart';
import 'package:patelmart/di/service_providers.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../di/infrastructure_providers.dart';

// Responsive breakpoints
class ResponsiveBreakpoints {
  static const double mobile = 650;
  static const double tablet = 900;
  static const double desktop = 1200;
  
  static bool isMobile(BuildContext context) => 
      MediaQuery.of(context).size.width < mobile;
  
  static bool isTablet(BuildContext context) => 
      MediaQuery.of(context).size.width >= mobile && 
      MediaQuery.of(context).size.width < desktop;
      
  static bool isDesktop(BuildContext context) => 
      MediaQuery.of(context).size.width >= desktop;
      
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;
}

// Model to represent a promotional banner

// Provider for the Banner Service



// Custom Page Controller for smooth transitions
class ResponsiveBannerController {
  late PageController _pageController;
  Timer? _autoPlayTimer;
  final bool _isAutoPlay;
  final Duration _autoPlayInterval;
  final Duration _animationDuration;
  int _currentIndex = 0;
  List<PromotionalBanner> _banners = [];
  bool _isDisposed = false;
  
  ResponsiveBannerController({
    bool autoPlay = true,
    Duration autoPlayInterval = const Duration(seconds: 5),
    Duration animationDuration = const Duration(milliseconds: 600),
  }) : 
    _isAutoPlay = autoPlay,
    _autoPlayInterval = autoPlayInterval,
    _animationDuration = animationDuration {
    _pageController = PageController();
  }
  
  void initialize(List<PromotionalBanner> banners) {
    if (_isDisposed) return;
    
    _banners = banners;
    _currentIndex = 0;
    
    if (_isAutoPlay && _banners.length > 1) {
      _startAutoPlay();
    }
  }
  
  void _startAutoPlay() {
    if (_isDisposed) return;
    
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (timer) {
      if (_isDisposed || _banners.isEmpty) {
        timer.cancel();
        return;
      }
      
      try {
        _currentIndex = (_currentIndex + 1) % _banners.length;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentIndex,
            duration: _animationDuration,
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        // Silently handle errors in auto-play
        timer.cancel();
      }
    });
  }
  
  void stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }
  
  void resumeAutoPlay() {
    if (_isAutoPlay && _banners.length > 1 && !_isDisposed) {
      _startAutoPlay();
    }
  }
  
  void dispose() {
    _isDisposed = true;
    _autoPlayTimer?.cancel();
    if (_pageController.hasClients) {
      _pageController.dispose();
    }
  }
  
  PageController get pageController => _pageController;
  int get currentIndex => _currentIndex;
  bool get isDisposed => _isDisposed;
  
  void updateIndex(int index) {
    _currentIndex = index;
  }
}

// Responsive Promotional Banner Widget
class PromotionalBannerWidget extends ConsumerStatefulWidget {
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration transitionDuration;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  final bool showPageIndicator;
  final Color? indicatorActiveColor;
  final Color? indicatorInactiveColor;
  final bool enableRefresh;
  final VoidCallback? onBannerTap;

  const PromotionalBannerWidget({
    Key? key,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.transitionDuration = const Duration(milliseconds: 600),
    this.margin,
    this.borderRadius,
    this.showPageIndicator = true,
    this.indicatorActiveColor,
    this.indicatorInactiveColor,
    this.enableRefresh = true,
    this.onBannerTap,
  }) : super(key: key);

  @override
  ConsumerState<PromotionalBannerWidget> createState() => _PromotionalBannerWidgetState();
}

class _PromotionalBannerWidgetState extends ConsumerState<PromotionalBannerWidget>
    with TickerProviderStateMixin {
  late ResponsiveBannerController _bannerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
    _bannerController = ResponsiveBannerController(
      autoPlay: widget.autoPlay,
      autoPlayInterval: widget.autoPlayInterval,
      animationDuration: widget.transitionDuration,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

  // Calculate responsive height based on screen width and 800x620 aspect ratio
  double _calculateHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final aspectRatio = 800 / 400; // Original banner aspect ratio
    
    if (ResponsiveBreakpoints.isMobile(context)) {
      // Mobile: Calculate height based on full screen width
      double height = screenWidth / aspectRatio;
      
      // Limit height on small screens and landscape mode
      if (ResponsiveBreakpoints.isLandscape(context)) {
        height = (screenHeight * 0.6).clamp(120.0, 200.0);
      } else {
        height = height.clamp(160.0, screenHeight * 0.35);
      }
      
      return height;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      // Tablet: Calculate height based on full screen width
      double height = screenWidth / aspectRatio;
      return height.clamp(200.0, 350.0);
    } else {
      // Desktop: Calculate height based on full screen width with reasonable limits
      double height = screenWidth / aspectRatio;
      return height.clamp(250.0, 500.0); // Increased max height for desktop
    }
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    // Return zero padding since we want full width
    return EdgeInsets.zero;
  }

  BorderRadius _getResponsiveBorderRadius(BuildContext context) {
  if (widget.borderRadius != null) return widget.borderRadius!;
  
  // Use circular border radius of 12 instead of zero
  return BorderRadius.circular(14.0);
}
  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(promotionalBannersProvider);
    
    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }
        
        // Initialize controller with banners
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_bannerController.isDisposed) {
            _bannerController.initialize(banners);
          }
        });
        
        return _buildFullWidthBannerCarousel(context, banners);
      },
      loading: () => _buildLoadingIndicator(context),
      error: (_, __) => _buildErrorState(context),
    );
  }
  
Widget _buildFullWidthBannerCarousel(BuildContext context, List<PromotionalBanner> banners) {
  final height = _calculateHeight(context);
  final screenWidth = MediaQuery.of(context).size.width;
  final borderRadius = _getResponsiveBorderRadius(context);
  
  return SizedBox(
    height: height,
    width: screenWidth, // Full screen width
    child: Stack(
      children: [
        // Banner PageView with ClipRRect for border radius
        ClipRRect(
          borderRadius: borderRadius,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: PageView.builder(
              controller: _bannerController.pageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _bannerController.updateIndex(index);
                });
                
                // Add subtle fade effect on page change
                _fadeController.reset();
                _fadeController.forward();
              },
              itemBuilder: (context, index) {
                return _buildBannerItem(context, banners[index]);
              },
            ),
          ),
        ),
        
        // Page Indicators
        if (widget.showPageIndicator && banners.length > 1)
          _buildResponsivePageIndicator(context, banners.length),
        
        // Refresh button (if enabled)
        if (widget.enableRefresh)
          _buildRefreshButton(context),
      ],
    ),
  );
}

  
  Widget _buildBannerItem(BuildContext context, PromotionalBanner banner) {
  // Convert hex color string to Color
  Color backgroundColor = Colors.white;
  try {
    final colorString = banner.backgroundColor.replaceAll('#', '');
    if (colorString.length == 6) {
      backgroundColor = Color(int.parse('FF$colorString', radix: 16));
    } else if (colorString.length == 8) {
      backgroundColor = Color(int.parse(colorString, radix: 16));
    }
  } catch (e) {
    backgroundColor = Colors.white;
  }
  
  return GestureDetector(
    onTap: () {
      // Pause auto-play briefly on tap
      _bannerController.stopAutoPlay();
      Timer(const Duration(seconds: 3), () {
        _bannerController.resumeAutoPlay();
      });
      
      // Handle custom tap callback
      if (widget.onBannerTap != null) {
        widget.onBannerTap!();
      }
      
      // Handle redirection
      if (banner.redirectLink.isNotEmpty) {
        _handleBannerRedirection(context, banner.redirectLink);
      }
    },
    child: Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: Stack(
        children: [
          // Background color layer
          Container(
            width: double.infinity,
            height: double.infinity,
            color: backgroundColor,
          ),
          
          // Banner image
          CachedNetworkImage(
            key: ValueKey('promotional_${banner.id}_${banner.imageUrl}'),
            imageUrl: banner.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              color: backgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.indicatorActiveColor ?? AppColors.primary,
                      ),
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: backgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey[400],
                      size: ResponsiveBreakpoints.isMobile(context) ? 40 : 50,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Banner unavailable',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: ResponsiveBreakpoints.isMobile(context) ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 200),
          ),
          
          // Subtle gradient overlay for better visual appeal
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  
  Widget _buildResponsivePageIndicator(BuildContext context, int pageCount) {
    final indicatorSize = ResponsiveBreakpoints.isMobile(context) ? 6.0 : 8.0;
    final indicatorActiveWidth = ResponsiveBreakpoints.isMobile(context) ? 18.0 : 24.0;
    final bottomPosition = ResponsiveBreakpoints.isMobile(context) ? 12.0 : 16.0;
    
    return Positioned(
      bottom: bottomPosition,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          pageCount,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentIndex == index ? indicatorActiveWidth : indicatorSize,
            height: indicatorSize,
            decoration: BoxDecoration(
              color: _currentIndex == index
                  ? widget.indicatorActiveColor ?? AppColors.primary
                  : widget.indicatorInactiveColor ?? Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(indicatorSize / 2),
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
      ),
    );
  }
  
  Widget _buildRefreshButton(BuildContext context) {
    final buttonSize = ResponsiveBreakpoints.isMobile(context) ? 32.0 : 36.0;
    final iconSize = ResponsiveBreakpoints.isMobile(context) ? 16.0 : 18.0;
    
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(buttonSize / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final refreshFunction = ref.read(promotionalBannerRefreshProvider);
              refreshFunction();
            },
            borderRadius: BorderRadius.circular(buttonSize / 2),
            child: Icon(
              Icons.refresh,
              size: iconSize,
              color: Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingIndicator(BuildContext context) {
  final height = _calculateHeight(context);
  final screenWidth = MediaQuery.of(context).size.width;
  final borderRadius = _getResponsiveBorderRadius(context);
  
  return ClipRRect(
    borderRadius: borderRadius,
    child: Container(
      height: height,
      width: screenWidth,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.indicatorActiveColor ?? AppColors.primary,
              ),
              strokeWidth: 2,
            ),
            const SizedBox(height: 12),
            Text(
              'Loading promotions...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: ResponsiveBreakpoints.isMobile(context) ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildErrorState(BuildContext context) {
  final height = _calculateHeight(context);
  final screenWidth = MediaQuery.of(context).size.width;
  final borderRadius = _getResponsiveBorderRadius(context);
  
  return ClipRRect(
    borderRadius: borderRadius,
    child: Container(
      height: height,
      width: screenWidth,
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: ResponsiveBreakpoints.isMobile(context) ? 32 : 40,
              color: Colors.red[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load promotions',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: ResponsiveBreakpoints.isMobile(context) ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.enableRefresh)
              TextButton.icon(
                onPressed: () {
                  final refreshFunction = ref.read(promotionalBannerRefreshProvider);
                  refreshFunction();
                },
                icon: Icon(
                  Icons.refresh,
                  size: ResponsiveBreakpoints.isMobile(context) ? 14 : 16,
                  color: AppColors.primary,
                ),
                label: Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: ResponsiveBreakpoints.isMobile(context) ? 12 : 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
  
  void _handleBannerRedirection(BuildContext context, String redirectLink) {
    try {
      final logger = ref.read(loggerProvider);
      logger.log('Banner tapped, redirecting to: $redirectLink');
      
      // Handle different types of redirections
      if (redirectLink.startsWith('product_details/')) {
        final productId = redirectLink.replaceFirst('product_details/', '');
        context.push('/product/$productId');
      } else if (redirectLink.startsWith('/')) {
        // Internal route
        context.push(redirectLink);
      } else if (redirectLink.contains('category_id=')) {
        // Category link
        final uri = Uri.parse(redirectLink);
        final categoryId = uri.queryParameters['category_id'];
        final deptId = uri.queryParameters['dept_id'] ?? '1';
        final categoryName = uri.queryParameters['category_name'] ?? 'Category';
        
        if (categoryId != null) {
          context.push('/subcategory/$categoryId/$deptId/$categoryName');
        }
      } else if (redirectLink.startsWith('http')) {
        // External URL - you might want to use url_launcher for this
        logger.log('External URL redirection not implemented: $redirectLink');
      } else {
        logger.log('Unknown redirection format: $redirectLink');
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error handling banner redirection: $e');
    }
  }
}

// Extension for easy usage in home screen
extension PromotionalBannerExtension on Widget {
  Widget withPromotionalBanner({
    bool autoPlay = true,
    Duration autoPlayInterval = const Duration(seconds: 5),
    bool enableRefresh = true,
  }) {
    return Column(
      children: [
        PromotionalBannerWidget(
          autoPlay: autoPlay,
          autoPlayInterval: autoPlayInterval,
          enableRefresh: enableRefresh,
        ),
        this,
      ],
    );
  }
}

// Utility class for managing banner display preferences
class BannerDisplayPreferences {
  static const String _prefsKey = 'banner_display_preferences';
  
  static Future<bool> shouldShowBanners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKey) ?? true;
    } catch (e) {
      return true; // Default to showing banners
    }
  }
  
  static Future<void> setBannerVisibility(bool visible) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, visible);
    } catch (e) {
      // Silently handle error
    }
  }
}

// Performance optimization widget wrapper
class OptimizedPromotionalBannerWidget extends StatelessWidget {
  final Widget child;
  
  const OptimizedPromotionalBannerWidget({
    Key? key,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: child,
    );
  }
}

final refreshPromotionalBannersProvider = StateProvider<bool>((ref) => false);

// Provider for promotional banners with refresh capability
final promotionalBannersProvider = FutureProvider<List<PromotionalBanner>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.watch(refreshPromotionalBannersProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        return [];
      }
      
      final bannerService = ref.read(bannerServiceProvider);
      
      // If force refresh is true, clear cache before fetching
      if (forceRefresh) {
        await bannerService.clearCache();
        // Reset the refresh flag
        ref.read(refreshPromotionalBannersProvider.notifier).state = false;
      }
      
      return await bannerService.getPromotionalBanners(outlet.storeCode);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for refreshing promotional banners manually
final promotionalBannerRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true to trigger cache clearing
    ref.read(refreshPromotionalBannersProvider.notifier).state = true;
    
    // Refresh the promotional banners provider
    await ref.refresh(promotionalBannersProvider.future);
  };
});
