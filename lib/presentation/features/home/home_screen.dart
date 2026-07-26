import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/widgets/app_drawer_widget.dart';
import 'package:patelmart/core/widgets/bottom_navigation_widget.dart';
import 'package:patelmart/core/widgets/header_widget.dart';
import 'package:patelmart/presentation/widgets/search_widget.dart';
import 'package:patelmart/presentation/features/cart/widgets/persistent_cart_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/home_popup_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_category_section_2_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_category_section_3_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_category_section_4_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_category_section_5_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/promotional_banner_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/best_seller_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/seasonal_category_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/seasonal_picks_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/single_offer_section_widget.dart';
import 'package:patelmart/presentation/providers/steal_deals_provider.dart';
import 'package:patelmart/presentation/features/orders/order_tracking_widget.dart';
import 'package:patelmart/presentation/features/orders/order_detail_screen.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import 'package:patelmart/presentation/providers/popular_category_section_providers.dart';
import 'package:patelmart/presentation/providers/order_history_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/outlet_model.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/home_refresh_provider.dart';
// POPUP IMPORTS
import '../../providers/popup_providers.dart';
// APP LIFECYCLE HANDLER
import '../../../presentation/handlers/app_lifecycle_handler.dart';
// FORCE UPDATE IMPORTS
import '../../providers/force_update_providers.dart';
import '../../widgets/force_update_dialog.dart';
import 'package:patelmart/core/widgets/brand_logo.dart';
import '../../../di/infrastructure_providers.dart';
import '../../providers/promotional_banner_providers.dart';
import '../../providers/seasonal_picks_widget_providers.dart';
import '../../providers/seasonal_category_widget_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  
  // Controllers and scroll management
  late ScrollController _scrollController;
  late TextEditingController _searchController;
  
  // Single animation controller for smooth transitions
  late AnimationController _headerAnimationController;
  late Animation<double> _headerOpacity;
  late Animation<double> _headerScale;
  
  // State management
  int _currentNavIndex = 0;
  DateTime? _lastBackPressTime;
  String? _lastOutletStoreCode; // Track outlet changes
  bool _hasInitializedPopup = false; // Track if popup has been initialized for this session
  
  // Smooth scroll tracking
  double _scrollOffset = 0.0;
  
  // Smooth thresholds for better UX
  static const double _headerFadeStart = 40.0;
  static const double _headerFadeEnd = 100.0;
  static const double _stickyHeaderThreshold = 120.0;
  
  @override
  bool get wantKeepAlive => true; // Keep alive for better performance
  
  @override
  void initState() {
    super.initState();
    
    // Initialize app lifecycle handler - FIXED: Moved to post frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appLifecycleHandlerProvider);
      }
    });
    
    // Initialize controllers
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    
    // Single animation controller for all header animations
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Smooth fade animation
    _headerOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    // Smooth scale animation
    _headerScale = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    // Optimized scroll listener
    _scrollController.addListener(_onScrollOptimized);
    
    // Search controller listener
    _searchController.addListener(_onSearchChanged);
    
    // Preload critical data and initialize popup
    _preloadCriticalData();
    _initializePopupWithDelay();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollOptimized);
    _scrollController.dispose();
    _searchController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  // ENHANCED POPUP INITIALIZATION - Shows IMMEDIATELY on app launch
  void _initializePopupWithDelay() {
    // Initialize popup immediately after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Minimal delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _initializePopup();
        }
      });
    });
  }

  void _initializePopup() {
    final outletAsync = ref.read(selectedOutletProvider);
    outletAsync.whenData((outlet) {
      if (outlet != null && mounted && !_hasInitializedPopup) {
        ref.read(popupDisplayStateProvider.notifier).initializePopupState(outlet.storeCode);
        _lastOutletStoreCode = outlet.storeCode;
        _hasInitializedPopup = true;
      }
    });
  }

  /// Check for force update after popup is completed
  void _checkForceUpdate() {
    // DEBUG: Add initial debug logs
    debugPrint('🔍 FORCE UPDATE CHECK TRIGGERED');
    debugPrint('📍 Current time: ${DateTime.now()}');
    
    // Only check if not already checked
    final hasChecked = ref.read(forceUpdateCheckedProvider);
    debugPrint('✅ Has already checked: $hasChecked');
    
    if (hasChecked) {
      debugPrint('⚠️ Force update already checked, skipping...');
      return;
    }

    // Mark as checked to prevent multiple calls
    ref.read(forceUpdateCheckedProvider.notifier).state = true;
    debugPrint('🔒 Marked force update as checked');

    // DEBUG: Log the provider call
    debugPrint('🚀 Starting force update API call...');

    // Get the future directly and handle it
    final updateFuture = ref.read(updateCheckProvider.future);
    
    updateFuture.then((updateInfo) {
      debugPrint('📦 FORCE UPDATE DATA RECEIVED:');
      debugPrint('   └─ Force Update Required: ${updateInfo.forceUpdate}');
      debugPrint('   └─ Latest Version: ${updateInfo.latestVersion}');
      debugPrint('   └─ Update Message: ${updateInfo.updateMessage}');
      debugPrint('   └─ Download URL: "${updateInfo.downloadUrl}"');
      
      // Only show dialog if force update is required
      if (updateInfo.forceUpdate && mounted) {
        debugPrint('🚨 FORCE UPDATE REQUIRED - Showing blocking dialog');
        debugPrint('   └─ Widget mounted: $mounted');
        debugPrint('   └─ Context available: ${context != null}');
        debugPrint('   └─ Download URL: "${updateInfo.downloadUrl}"');
        debugPrint('   └─ URL Empty: ${updateInfo.downloadUrl.isEmpty}');
        
        // Show full-screen blocking dialog immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('📱 Showing full-screen force update dialog...');
          try {
            showForceUpdateDialog(context, updateInfo);
            debugPrint('✅ Force update dialog displayed successfully');
          } catch (e) {
            debugPrint('❌ Error showing force update dialog: $e');
          }
        });
      } else {
        debugPrint('✅ No force update required or widget not mounted');
        debugPrint('   └─ Force Update: ${updateInfo.forceUpdate}');
        debugPrint('   └─ Widget Mounted: $mounted');
      }
    }).catchError((error, stack) {
      // Log error details
      debugPrint('❌ FORCE UPDATE CHECK FAILED:');
      debugPrint('   └─ Error: $error');
      debugPrint('   └─ Stack: $stack');
      ref.read(loggerProvider).error('Force update check failed: $error');
    });

    debugPrint('🏁 Force update check initiated');
  }

  // Handle outlet changes for popup reinitialization
  void _handleOutletChange(OutletModel? outlet) {
    if (outlet != null && _lastOutletStoreCode != outlet.storeCode) {
      final currentState = ref.read(popupDisplayStateProvider);
      if (currentState.currentStoreCode != outlet.storeCode) {
        ref.read(popupDisplayStateProvider.notifier).resetForNewStore(outlet.storeCode);
        ref.read(popupDisplayStateProvider.notifier).initializePopupState(outlet.storeCode);
        _hasInitializedPopup = true;
      }
      _lastOutletStoreCode = outlet.storeCode;
    }
  }

  // FIXED: Optimized scroll handling without jerky boolean switches
  void _onScrollOptimized() {
    if (!mounted) return;
    
    final offset = _scrollController.offset;
    
    // Only update if there's a significant change to prevent excessive rebuilds
    if ((offset - _scrollOffset).abs() > 2.0) {
      setState(() {
        _scrollOffset = offset;
      });
      
      // Smooth animation based on scroll position
      final progress = ((offset - _headerFadeStart) / (_headerFadeEnd - _headerFadeStart)).clamp(0.0, 1.0);
      _headerAnimationController.animateTo(progress);
    }
  }

  void _onSearchChanged() {
    // Debounced search handling can be added here if needed
  }

  // Preload critical data to prevent loading delays
  void _preloadCriticalData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Warm up providers
      ref.read(selectedOutletProvider);
      ref.read(selectedPincodeProvider);
      ref.read(cartCountProvider);
    });
  }

  // Optimized back press handling
  Future<bool> _handleBackPress() async {
    final now = DateTime.now();
    const exitConfirmTime = Duration(seconds: 2);

    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > exitConfirmTime) {
      
      _lastBackPressTime = now;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      return false;
    } else {
      await SystemNavigator.pop();
      return true;
    }
  }

  // COMPREHENSIVE REFRESH METHOD FOR ALL HOME SCREEN WIDGETS
  Future<void> _refreshHomeData() async {
    try {
      // Add haptic feedback
      HapticFeedback.lightImpact();
      
      // Clear/invalidate all cached data BEFORE starting the refresh
      // This ensures old data isn't shown during the refresh
      ref.read(homeScreenRefreshStateProvider.notifier).state = true;
      
      // Show loading indicator with descriptive message
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Refreshing all home screen data...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Execute all refresh operations in parallel for better performance
      final refreshOperations = <Future<void>>[];

      // 1. Best Seller sections (1-4) - using existing provider
      refreshOperations.add(
        ref.read(bestSellerRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Best seller refresh failed: $e');
        })
      );

      // 2. Popular Categories (2-5) - using NEW isolated providers for complete separation
      refreshOperations.add(
        ref.read(allSectionsRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Popular categories refresh failed: $e');
        })
      );

      // 3. Promotional Banner - using existing provider
      refreshOperations.add(
        ref.read(promotionalBannerRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Promotional banner refresh failed: $e');
        })
      );

      // 4. Seasonal Picks - manual refresh since no dedicated provider exists
      refreshOperations.add(
        _refreshSeasonalPicksData().catchError((e) {
          ref.read(loggerProvider).error('Seasonal picks refresh failed: $e');
        })
      );

      // 5. Seasonal Categories - using the provider refresh
      refreshOperations.add(
        ref.read(seasonalCategoryRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Seasonal categories refresh failed: $e');
        })
      );

      // 6. Pending Order / Last Order Status widget
      refreshOperations.add(
        Future(() async {
          try {
            final future = ref.refresh(lastOrderStatusProvider.future);
            await future;
          } catch (e) {
            ref.read(loggerProvider).error('Last order status refresh failed: $e');
          }
        })
      );

      // Wait for all refresh operations to complete
      await Future.wait(refreshOperations);

      if (mounted) {
        // Add success haptic feedback
        HapticFeedback.mediumImpact();
        
        // Dismiss the loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Show success message with animation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline, 
                  color: Colors.white, 
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Home screen refreshed successfully!',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        
        // Optional: Smooth scroll to top after refresh
        if (_scrollController.hasClients && _scrollController.offset > 100) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          );
        }
      }

      // Log successful refresh
      ref.read(loggerProvider).log('Home screen refresh completed successfully');
      
      // Reset loading state
      ref.read(homeScreenRefreshStateProvider.notifier).state = false;

    } catch (e) {
      // Add error haptic feedback
      HapticFeedback.heavyImpact();
      
      // Handle any unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline, 
                  color: Colors.white, 
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Refresh failed. Tap retry to try again.',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              backgroundColor: Colors.red[800],
              onPressed: _refreshHomeData,
            ),
          ),
        );
      }
      
      // Log the error with details
      ref.read(loggerProvider).error('Home screen refresh failed with error: $e');
      
      // Reset loading state on error
      ref.read(homeScreenRefreshStateProvider.notifier).state = false;
    }
  }

  // Helper method to refresh seasonal picks data specifically
  Future<void> _refreshSeasonalPicksData() async {
    try {
      final outletAsync = ref.read(selectedOutletProvider);
      // Use valueOrNull to avoid the when() async-not-awaited pitfall
      final outlet = outletAsync.valueOrNull;

      if (outlet != null) {
        // Refresh both seasonal banner and categories, and properly await them
        await Future.wait([
          ref.refresh(bannerProvider(outlet.storeCode).future),
          ref.refresh(categoriesProvider(outlet.storeCode).future),
        ]);

        ref.read(loggerProvider).log('Seasonal picks refreshed for store: ${outlet.storeCode}');
      } else {
        ref.read(loggerProvider).log('No outlet selected, skipping seasonal picks refresh');
      }
    } catch (e) {
      ref.read(loggerProvider).error('Failed to refresh seasonal picks: $e');
      rethrow; // Re-throw to be caught by the main refresh method
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Auto-remove offer products when their offer locks back
    ref.watch(offerProductAutoRemovalProvider);

    // Watch for outlet changes and handle popup reinitialization
    final outletAsync = ref.watch(selectedOutletProvider);
    outletAsync.whenData((outlet) => _handleOutletChange(outlet));
    
    // Setup popup listener for force update check (must be in build method)
    ref.listen<PopupDisplayState>(popupDisplayStateProvider, (previous, next) {
      // DEBUG: Log popup state changes
      debugPrint('🎯 POPUP STATE CHANGE DETECTED:');
      debugPrint('   └─ Previous: ${previous?.isVisible ?? 'null'}');
      debugPrint('   └─ Current: ${next.isVisible}');
      debugPrint('   └─ Store Code: ${next.currentStoreCode ?? 'null'}');
      debugPrint('   └─ Initialized: ${next.isInitialized}');
      
      // ONLY trigger force update when popup is completed (visible -> hidden)
      if (previous?.isVisible == true && next.isVisible == false) {
        debugPrint('🎉 POPUP COMPLETED - Triggering force update check');
        debugPrint('   └─ This is the ONLY trigger for force update');
        
        // Reset the check state and immediately trigger force update
        ref.read(forceUpdateCheckedProvider.notifier).state = false;
        debugPrint('   └─ Reset force update check state for fresh check');
        
        // Popup just finished - check for force update with delay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              debugPrint('🚀 POPUP CLOSE DELAY COMPLETE - Starting force update check');
              _checkForceUpdate();
            }
          });
        });
      } else {
        debugPrint('⏸️ Popup state change but not completion - NO force update trigger');
        debugPrint('   └─ Previous visible: ${previous?.isVisible}');
        debugPrint('   └─ Current visible: ${next.isVisible}');
      }
    });
    
    // Check if we should show sticky header
    final showStickyHeader = _scrollOffset > _stickyHeaderThreshold;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Main content with NestedScrollView for smooth sticky behavior
            NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Dynamic App Bar as Sliver
                  SliverAppBar(
                    expandedHeight: 56,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    elevation: 2,
                    leading: Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    title: AnimatedBuilder(
                      animation: _headerOpacity,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _headerScale.value,
                          child: Opacity(
                            opacity: _headerOpacity.value,
                            child: const BrandLogo(
                              height: 42,
                              fallbackColor: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    centerTitle: false,
                    actions: [
                      AnimatedBuilder(
                        animation: _headerOpacity,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _headerOpacity.value,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
                                  onPressed: () => context.push('/favorites'),
                                ),
                                _buildCartButton(),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  // Header section (pincode display)
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final selectedPincode = ref.watch(selectedPincodeProvider);
                        return HeaderWidget(
                          pincode: selectedPincode ?? 'Not Set',
                          onChangeTap: () => context.go('/location-change'),
                        );
                      },
                    ),
                  ),
                  
                  // Search bar
                  SliverToBoxAdapter(
                    child: SearchWidget(
                      controller: _searchController,
                      onSearch: (query) {
                        if (query.isNotEmpty) {
                          context.push('/search?query=${Uri.encodeComponent(query)}');
                        }
                      },
                      showSuggestions: false,
                    ),
                  ),
                ];
              },
              body: RefreshIndicator(
                onRefresh: _refreshHomeData,
                color: AppColors.primary,
                child: _buildScrollableContent(),
              ),
            ),
            
            // Floating sticky header only when scrolled far enough
            if (showStickyHeader)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  child: Container(
                    height: 56,
                    color: AppColors.primary,
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: SearchWidget(
                              controller: _searchController,
                              onSearch: (query) {
                                if (query.isNotEmpty) {
                                  context.push('/search?query=${Uri.encodeComponent(query)}');
                                }
                              },
                              showSuggestions: false,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
                          onPressed: () => context.push('/favorites'),
                        ),
                        _buildCartButton(),
                      ],
                    ),
                  ),
                ),
              ),
            
            // POPUP OVERLAY - This is the key addition
            const HomePopupWidget(),
          ],
        ),
        drawer: const AppDrawerWidget(), // ✅ Using reusable drawer
        bottomNavigationBar: _buildBottomNavigation(),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      ),
    );
  }

  Widget _buildCartButton() {
    return Consumer(
      builder: (context, ref, _) {
        final cartCount = ref.watch(cartCountProvider);
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              onPressed: () => context.push('/cart'),
            ),
            if (cartCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    cartCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      // Performance optimization: Use cacheExtent to pre-render nearby widgets
      child: Column(
        children: [
          // REDUCED SPACING: Smaller gap after search
          const SizedBox(height: 8), // Reduced from 16 to 8

          // Order Tracking Widget Positioned AFTER Search Bar
          Consumer(
            builder: (context, ref, child) {
              final lastOrderStatusAsync = ref.watch(lastOrderStatusProvider);
              
              return lastOrderStatusAsync.when(
                data: (orderStatus) {
                  if (orderStatus == null || !orderStatus.isVisible || orderStatus.orderStatusTxt.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: OrderTrackingWidget(
                      orderId: orderStatus.actualOrderNo,
                      title: orderStatus.orderStatusTxt,
                      imageUrl: orderStatus.orderStatusImg,
                      onViewOrderTap: () {
                        if (orderStatus.lastOrder != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailScreen(
                                order: orderStatus.lastOrder!,
                              ),
                            ),
                          );
                        } else {
                          // Fallback to orders list if order details not available
                          context.push('/my-orders');
                        }
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(height: 4),

          // Popular Categories - using RepaintBoundary for better performance
          RepaintBoundary(
            child: const SeasonalCategoryWidget(
              departmentId: 2, // Your department ID
              itemWidth: 100,
              itemHeight: 100,
              showTitle: false,
              showViewAll: false,
              spacing: 4,
              padding: EdgeInsets.symmetric(horizontal: 8),
              enablePullToRefresh: false, // Disabled - using home screen's unified refresh
            ),
          ),

          // Promotional Banner - wrapped in RepaintBoundary
          RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
              // Reduced vertical margin
              child: const PromotionalBannerWidget(
                showPageIndicator: true,
                autoPlay: true,
                autoPlayInterval: Duration(seconds: 5),
                enableRefresh: true,
              ),
            ),
          ),

          // Offers interleaved with Best Sellers and Popular Categories
          Consumer(
            builder: (context, ref, _) {
              final offersAsync = ref.watch(stealDealsOffersProvider);
              final offers = offersAsync.whenOrNull(data: (data) => data);
              final previousOffers = offersAsync.valueOrNull;
              final displayOffers = offers ?? previousOffers ?? [];

              const int bestSellerCount = 4;
              final int maxPairs = displayOffers.length > bestSellerCount
                  ? displayOffers.length
                  : bestSellerCount;

              return Column(
                children: [
                  for (int i = 0; i < maxPairs; i++) ...[
                    // Popular Category sections interleaved (Rendered FIRST)
                    if (i == 0)
                      const RepaintBoundary(
                        key: ValueKey('popular_category_section_2'),
                        child: PopularCategorySection2Widget(
                          showTitle: true,
                          showViewAll: true,
                          itemWidth: 80,
                          itemHeight: 95,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          spacing: 6,
                        ),
                      ),
                    if (i == 1)
                      const RepaintBoundary(
                        key: ValueKey('popular_category_section_3'),
                        child: PopularCategorySection3Widget(
                          showTitle: true,
                          showViewAll: true,
                          itemWidth: 80,
                          itemHeight: 95,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          spacing: 6,
                        ),
                      ),
                    if (i == 2)
                      const RepaintBoundary(
                        key: ValueKey('popular_category_section_4'),
                        child: PopularCategorySection4Widget(
                          showTitle: true,
                          showViewAll: true,
                          itemWidth: 80,
                          itemHeight: 95,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          spacing: 6,
                        ),
                      ),
                    if (i == 3)
                      const RepaintBoundary(
                        key: ValueKey('popular_category_section_5'),
                        child: PopularCategorySection5Widget(
                          showTitle: true,
                          showViewAll: true,
                          itemWidth: 80,
                          itemHeight: 95,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          spacing: 6,
                        ),
                      ),

                    // Best seller at index i (if exists)
                    if (i < bestSellerCount)
                      RepaintBoundary(
                        key: ValueKey('best_seller_repaint_${i + 1}'),
                        child: Consumer(
                          builder: (context, ref, _) {
                            final backgroundColor = ref.watch(
                              bestSellerBackgroundColorProvider(i + 1),
                            );
                            return BestSellerWidget(
                              key: ValueKey(
                                  'best_seller_${i + 1}_${backgroundColor.value}'),
                              bestSellerId: i + 1,
                              height: 320,
                            );
                          },
                        ),
                      ),
                    
                    // Offer at index i (if exists)
                    if (i < displayOffers.length)
                      RepaintBoundary(
                        key: ValueKey('offer_section_$i'),
                        child: SingleOfferSectionWidget(
                            offer: displayOffers[i]),
                      ),
                  ],
                ],
              );
            },
          ),

          // Seasonal Picks
          const RepaintBoundary(
            child: SeasonalPicksWidget(),
          ),

          // Bottom spacing
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PersistentCartWidget(),
        BottomNavigationWidget(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            if (mounted) {
              setState(() {
                _currentNavIndex = index;
              });
              
              switch (index) {
                case 0: // Home
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  break;
                case 1: // Category
                  context.go('/category');
                  break;
                case 2: // Cart/Order
                  context.go('/cart');
                  break;
                case 3: // Reorder
                  context.go('/reorder');
                  break;
                case 4: // Account
                  context.go('/account');
                  break;
              }
            }
          },
        ),
      ],
    );
  }

  // ENHANCED FLOATING ACTION BUTTON WITH LOADING STATES
  Widget _buildFloatingActionButton() {
    return Consumer(
      builder: (context, ref, _) {
        // Watch for loading states from all major providers
        final bestSellerLoading = ref.watch(bestSellerBannerProvider(1)).isLoading ||
                                  ref.watch(bestSellerBannerProvider(2)).isLoading ||
                                  ref.watch(bestSellerBannerProvider(3)).isLoading ||
                                  ref.watch(bestSellerBannerProvider(4)).isLoading;
        
        // Use isolated section providers for loading state
        final popularCategoryLoading = ref.watch(popularCategorySection2Provider).isLoading ||
                                       ref.watch(popularCategorySection3Provider).isLoading ||
                                       ref.watch(popularCategorySection4Provider).isLoading ||
                                       ref.watch(popularCategorySection5Provider).isLoading;
        
        final promotionalBannerLoading = ref.watch(promotionalBannersProvider).isLoading;
        
        // Check seasonal picks loading
        final outletAsync = ref.watch(selectedOutletProvider);
        final seasonalLoading = outletAsync.when(
          data: (outlet) {
            if (outlet != null) {
              return ref.watch(bannerProvider(outlet.storeCode)).isLoading ||
                     ref.watch(categoriesProvider(outlet.storeCode)).isLoading;
            }
            return false;
          },
          loading: () => false,
          error: (_, __) => false,
        );
        
        final isRefreshing = bestSellerLoading || 
                            popularCategoryLoading || 
                            promotionalBannerLoading || 
                            seasonalLoading;
        
        return AnimatedScale(
          scale: isRefreshing ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton(
            mini: true,
            backgroundColor: isRefreshing 
                ? AppColors.primary.withOpacity(0.7)
                : AppColors.primary.withOpacity(0.8),
            elevation: isRefreshing ? 2 : 4,
            onPressed: isRefreshing ? null : _refreshHomeData,
            tooltip: isRefreshing ? 'Refreshing...' : 'Refresh home screen',
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: isRefreshing
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      key: const ValueKey('refresh_icon'),
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        );
      },
    );
  }


}