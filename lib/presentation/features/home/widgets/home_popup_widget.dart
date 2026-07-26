import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/data/models/popup_model.dart';
import 'package:patelmart/presentation/providers/popup_providers.dart';
import '../../../../di/infrastructure_providers.dart';

class HomePopupWidget extends ConsumerStatefulWidget {
  const HomePopupWidget({super.key});

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
  OverlayEntry? _overlayEntry;

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
      end: 1.0, // Full opacity backdrop to completely block background
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
    _removeOverlay();
    _animationController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlayPopup(PopupResponse popupData) {
    if (_overlayEntry != null) return;
    
    // Create overlay entry that will be rendered at the absolute top level
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildFullScreenBlockingOverlay(popupData),
    );
    
    // Insert overlay at the top level of the app
    Overlay.of(context, rootOverlay: true)?.insert(_overlayEntry!);
    
    // Start animation
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final popupState = ref.watch(popupDisplayStateProvider);
    
    // Listen for popup visibility changes
    ref.listen<PopupDisplayState>(popupDisplayStateProvider, (previous, current) {
      if (current.isVisible && (previous == null || !previous.isVisible)) {
        // Show popup when state becomes visible
        final storeCode = current.currentStoreCode;
        if (storeCode != null) {
          final popupDataAsync = ref.read(popupDataProvider(storeCode));
          popupDataAsync.whenData((popupData) {
            if (popupData?.offerImageUrl.isNotEmpty == true) {
              _showOverlayPopup(popupData!);
            }
          });
        }
      } else if (!current.isVisible && (previous?.isVisible ?? false)) {
        // Hide popup when state becomes hidden
        _closePopup();
      }
    });
    
    // If popup is visible, fetch data and show overlay
    if (popupState.isVisible && popupState.currentStoreCode != null) {
      final popupDataAsync = ref.watch(popupDataProvider(popupState.currentStoreCode!));
      
      popupDataAsync.whenData((popupData) {
        if (popupData?.offerImageUrl.isNotEmpty == true && _overlayEntry == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlayPopup(popupData!);
          });
        } else if (popupData?.offerImageUrl.isEmpty == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(popupDisplayStateProvider.notifier).hidePopup();
          });
        }
      });
      
      popupDataAsync.whenOrNull(
        error: (error, stack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(popupDisplayStateProvider.notifier).hidePopup();
          });
        },
      );
    }
    
    // This widget itself doesn't render anything visible
    // All popup content is rendered via the overlay
    return const SizedBox.shrink();
  }

  Widget _buildFullScreenBlockingOverlay(PopupResponse popupData) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              // This container covers the ENTIRE screen including system UI
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9 * _backdropAnimation.value),
              ),
              child: Stack(
                children: [
                  // Full-screen gesture detector to block ALL interactions
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closePopup,
                      onPanDown: (_) => _closePopup(),
                      onPanStart: (_) => _closePopup(),
                      onPanUpdate: (_) => _closePopup(),
                      onPanEnd: (_) => _closePopup(),
                      onLongPress: _closePopup,
                      onLongPressStart: (_) => _closePopup(),
                      onDoubleTap: _closePopup,
                      onTapDown: (_) => _closePopup(),
                      onTapUp: (_) => _closePopup(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.transparent,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  // Popup content - wrapped in GestureDetector to handle taps on the popup itself
                  Center(
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: GestureDetector(
                        onTap: _closePopup,
                        onPanDown: (_) => _closePopup(),
                        onDoubleTap: _closePopup,
                        onLongPress: _closePopup,
                        behavior: HitTestBehavior.opaque,
                        child: _buildPopupContent(popupData),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopupContent(PopupResponse popupData) {
    final screenSize = MediaQuery.of(context).size;
    final popupWidth = screenSize.width * 0.85;
    final popupHeight = screenSize.height * 0.79;

    return Container(
      width: popupWidth,
      height: popupHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, 20),
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Popup Image - wrapped in GestureDetector for tap to close
            Positioned.fill(
              child: GestureDetector(
                onTap: _closePopup,
                onDoubleTap: _closePopup,
                onLongPress: _closePopup,
                behavior: HitTestBehavior.opaque,
                child: _buildEnhancedImage(popupData.offerImageUrl),
              ),
            ),
            // Close Button with enhanced visibility and larger tap area
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _closePopup,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      // BoxShadow(
                      //   color: Colors.black.withOpacity(0.5),
                      //   blurRadius: 12,
                      //   offset: const Offset(0, 4),
                      // ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            // Larger invisible tap area around close button
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: _closePopup,
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedImage(String imageUrl) {
    final cleanUrl = imageUrl.trim();
    
    ref.read(loggerProvider).log('🖼️ Popup image URL from API: "$cleanUrl"');
    
    if (cleanUrl.isEmpty) {
      ref.read(loggerProvider).log('📭 Empty image URL, using fallback');
      return _buildFallbackImage();
    }
    
    if (!_isValidUrl(cleanUrl)) {
      ref.read(loggerProvider).log('❌ Invalid image URL format, using fallback');
      return _buildFallbackImage();
    }

    return CachedNetworkImage(
      imageUrl: cleanUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) {
        ref.read(loggerProvider).log('⏳ Loading popup image: $url');
        return Container(
          color: AppColors.neutral200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading Special Offer...',
                  style: TextStyle(
                    color: AppColors.neutral700,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(
                    color: AppColors.neutral500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      errorWidget: (context, url, error) {
        ref.read(loggerProvider).error('🚫 API popup image failed to load: $url');
        ref.read(loggerProvider).error('🚫 Error details: $error');
        return _buildFallbackImage();
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
      cacheKey: '${cleanUrl}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}',
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
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading Default Offer...',
                style: TextStyle(
                  color: AppColors.neutral700,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        ref.read(loggerProvider).error('🚫 Fallback popup image also failed: $error');
        return _buildImageError('Unable to load offer image');
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

  Widget _buildImageError(String message) {
    return Container(
      color: AppColors.neutral100,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.neutral500,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Special Offer',
                style: TextStyle(
                  color: AppColors.neutral700,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _closePopup,
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
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
    if (mounted && _overlayEntry != null) {
      // Animate out
      await _animationController.reverse();
      
      // Remove overlay
      _removeOverlay();
      
      // Update state
      ref.read(popupDisplayStateProvider.notifier).hidePopup();
    }
  }
}