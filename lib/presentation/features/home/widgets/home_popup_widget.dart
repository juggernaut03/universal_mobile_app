import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/data/models/popup_model.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/popup_providers.dart';

class HomePopupWidget extends ConsumerStatefulWidget {
  const HomePopupWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePopupWidget> createState() => _HomePopupWidgetState();
}

class _HomePopupWidgetState extends ConsumerState<HomePopupWidget>
    with TickerProviderStateMixin {
  Timer? _displayTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _backdropAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startImmediateDisplayTimer();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _backdropAnimation = Tween<double>(
      begin: 0.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));
  }

  void _startImmediateDisplayTimer() {
    // Show popup immediately when home screen is ready
    _displayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(popupDisplayStateProvider.notifier).showPopup();
      }
    });
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popupState = ref.watch(popupDisplayStateProvider);
    
    // Listen for popup visibility changes
    ref.listen<PopupDisplayState>(popupDisplayStateProvider, (previous, current) {
      if (current.isVisible && (previous == null || !previous.isVisible)) {
        _animationController.forward();
      } else if (!current.isVisible && (previous?.isVisible ?? false)) {
        _animationController.reverse();
      }
    });
    
    if (!popupState.isVisible || popupState.currentStoreCode == null) {
      return const SizedBox.shrink();
    }

    final popupDataAsync = ref.watch(popupDataProvider(popupState.currentStoreCode!));

    return popupDataAsync.when(
      data: (popupData) {
        if (popupData?.offerImageUrl.isEmpty ?? true) {
          // If no popup data, hide the popup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(popupDisplayStateProvider.notifier).hidePopup();
          });
          return const SizedBox.shrink();
        }
        return _buildPopupOverlay(popupData!);
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) {
        // On error, hide the popup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(popupDisplayStateProvider.notifier).hidePopup();
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPopupOverlay(PopupResponse popupData) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              color: Colors.black.withOpacity(_backdropAnimation.value),
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildPopupContent(popupData),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopupContent(PopupResponse popupData) {
    final screenSize = MediaQuery.of(context).size;
    final popupWidth = screenSize.width * 0.75;
    final popupHeight = screenSize.height * 0.7;

    return Container(
      width: popupWidth,
      height: popupHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Popup Image - Enhanced loading with multiple fallbacks
            Positioned.fill(
              child: _buildEnhancedImage(popupData.offerImageUrl),
            ),
            // Close Button
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _closePopup,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            // Tap to dismiss overlay
            Positioned.fill(
              child: GestureDetector(
                onTap: _closePopup,
                behavior: HitTestBehavior.translucent,
                child: Container(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedImage(String imageUrl) {
    // Clean and validate the image URL
    final cleanUrl = imageUrl.trim();
    
    // Debug logging to see what URL we're getting from API
    ref.read(loggerProvider).log('🖼️ Popup image URL from API: "$cleanUrl"');
    
    // If URL is empty, use fallback image
    if (cleanUrl.isEmpty) {
      ref.read(loggerProvider).log('📭 Empty image URL, using fallback');
      return _buildFallbackImage();
    }
    
    // If URL is invalid, use fallback image
    if (!_isValidUrl(cleanUrl)) {
      ref.read(loggerProvider).log('❌ Invalid image URL format, using fallback');
      return _buildFallbackImage();
    }

    // Try to load the API image with enhanced error handling
    return CachedNetworkImage(
      imageUrl: cleanUrl,
      fit: BoxFit.cover,
      // Enhanced loading indicator
      placeholder: (context, url) {
        ref.read(loggerProvider).log('⏳ Loading popup image: $url');
        return Container(
          color: AppColors.neutral200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading offer...',
                  style: TextStyle(
                    color: AppColors.neutral600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'From: ${_getDomainFromUrl(url)}',
                  style: TextStyle(
                    color: AppColors.neutral400,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      // Enhanced error handling with detailed logging
      errorWidget: (context, url, error) {
        ref.read(loggerProvider).error('🚫 API popup image failed to load: $url');
        ref.read(loggerProvider).error('🚫 Error details: $error');
        
        // Compare with fallback URL to see if they're the same
        const fallbackUrl = 'https://upload.wikimedia.org/wikipedia/commons/0/0f/Eiffel_Tower_Vertical.JPG';
        if (cleanUrl == fallbackUrl) {
          ref.read(loggerProvider).log('⚠️ API URL is same as fallback but still failed!');
          // If API URL is same as fallback and still fails, show error
          return _buildImageError('Network connectivity issue');
        }
        
        // Try fallback image
        ref.read(loggerProvider).log('🔄 Switching to fallback image...');
        return _buildFallbackImage();
      },
      // Enhanced HTTP headers for better compatibility
      httpHeaders: {
        'User-Agent': 'Patel Mart Mobile App/1.0',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
      // Timeout and caching settings
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      // Force refresh if needed
      cacheKey: '${cleanUrl}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}', // Cache for 1 minute
    );
  }

  Widget _buildFallbackImage() {
    const fallbackUrl = 'https://patelrmart.com/mgmt_panel/product_images/popup/popup.webp';
    
    ref.read(loggerProvider).log('🛡️ Loading fallback popup image: $fallbackUrl');
    
    return CachedNetworkImage(
      imageUrl: fallbackUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: AppColors.neutral200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading default offer...',
                style: TextStyle(
                  color: AppColors.neutral600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // If even fallback fails, show error UI
        ref.read(loggerProvider).error('🚫 Fallback popup image also failed: $error');
        return _buildImageError('Unable to load any offer image');
      },
      httpHeaders: {
        'User-Agent': 'Patel Mart Mobile App/1.0',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  String _getDomainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return 'unknown';
    }
  }

  Widget _buildImageError(String message) {
    return Container(
      color: AppColors.neutral100,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.neutral500,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Offer Image',
                style: TextStyle(
                  color: AppColors.neutral700,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _closePopup,
                icon: Icon(Icons.close, color: AppColors.primary),
                label: Text(
                  'Close',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  void _closePopup() async {
    if (mounted) {
      await _animationController.reverse();
      ref.read(popupDisplayStateProvider.notifier).hidePopup();
    }
  }
}