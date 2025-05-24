// lib/presentation/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/bottom_navigation_widget.dart';
import 'package:patelmart/core/widgets/empty_state_widget.dart';
import 'package:patelmart/core/widgets/header_widget.dart';
import 'package:patelmart/core/widgets/search_widget.dart';
import 'package:patelmart/presentation/features/cart/widgets/persistent_cart_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/category_grid_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/home_categories_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_categories_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_category_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/promotional_banner_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/best_seller_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/seasonal_picks_widget.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/back_handler.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/category_providers.dart';
import '../../providers/cart_provider.dart';
import 'dart:async';

// Create a search state class
class SearchState {
  final List<dynamic> results;
  final String query;
  final bool isLoading;
  final String? error;

  SearchState({
    this.results = const [],
    this.query = '',
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    List<dynamic>? results,
    String? query,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error : this.error,
    );
  }
}

// Create a notifier to handle search state
class SearchStateNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  Timer? _debounce;

  SearchStateNotifier(this._ref) : super(SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    
    if (query.length >= 2) {
      _debounceSearch();
    } else if (query.isEmpty) {
      state = state.copyWith(results: []);
    }
  }

  void _debounceSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      search();
    });
  }

  Future<void> search() async {
    if (state.query.isEmpty) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final logger = _ref.read(loggerProvider);
      logger.log('Performing search for: ${state.query}');
      
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? 'TTL';
      
      final apiClient = _ref.read(apiClientProvider);
      
      final response = await apiClient.post(
        'https://newtech.shalviadvision.com/api/get_search_autocomplete_results',
        body: {
          'product_name': state.query,
          'store_code': storeCode,
          'project_code': 'RET5890',
        },
      );
      
      List<dynamic> results = [];
      
      if (response is List) {
        results = response;
      } else if (response is Map && response.containsKey('products')) {
        results = response['products'] as List;
      }
      
      state = state.copyWith(results: results, isLoading: false);
      
    } catch (e) {
      state = state.copyWith(
        error: 'Search failed: $e',
        isLoading: false,
      );
    }
  }

  void clearResults() {
    state = state.copyWith(results: []);
  }
}

// Create a provider for search state
final searchStateProvider = StateNotifierProvider<SearchStateNotifier, SearchState>((ref) {
  return SearchStateNotifier(ref);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> 
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // Animation controllers for smooth transitions
  late AnimationController _appBarAnimationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _searchSlideAnimation;
  
  int _currentNavIndex = 0;
  bool _isSearchSticky = false;
  DateTime? _lastBackPressTime;
  bool _isHandlingBackPress = false;

  // Scroll thresholds
  static const double _stickyThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    
    // Animation controllers
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    // Logo animations
    _logoOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _logoScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Search slide animation - now slides from top
    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    
    _searchController.addListener(() {
      ref.read(searchStateProvider.notifier).setQuery(_searchController.text);
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loggerProvider).log('HomeScreen initialized with top-sticky search');
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _appBarAnimationController.dispose();
    _searchAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final logger = ref.read(loggerProvider);
    logger.log('App lifecycle state changed to: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        logger.log('App resumed - resetting back press handler');
        _isHandlingBackPress = false;
        _lastBackPressTime = null;
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onScroll() {
    final scrollOffset = _scrollController.offset;
    final shouldBeSticky = scrollOffset > _stickyThreshold;
    
    // Handle sticky search bar animation
    if (shouldBeSticky != _isSearchSticky) {
      setState(() {
        _isSearchSticky = shouldBeSticky;
      });
      
      if (_isSearchSticky) {
        _appBarAnimationController.forward();
        _searchAnimationController.forward();
        ref.read(loggerProvider).log('Search bar became top-sticky, logo hidden');
      } else {
        _appBarAnimationController.reverse();
        _searchAnimationController.reverse();
        ref.read(loggerProvider).log('Search bar returned to normal, logo visible');
      }
    }
  }

  Future<bool> _handleBackPress() async {
    if (_isHandlingBackPress) {
      return false;
    }

    final logger = ref.read(loggerProvider);
    final now = DateTime.now();
    const exitConfirmTime = Duration(seconds: 2);

    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > exitConfirmTime) {
      
      _lastBackPressTime = now;
      logger.log('First back press on Home, showing exit confirmation');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Press back again to exit'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      
      return false;
    } else {
      logger.log('Second back press on Home, exiting app');
      _isHandlingBackPress = true;
      
      try {
        await SystemNavigator.pop();
        return true;
      } catch (e) {
        logger.error('Error exiting app: $e');
        _isHandlingBackPress = false;
        return false;
      }
    }
  }

  Future<void> _refreshHomeData() async {
    ref.read(loggerProvider).log('Refreshing home data...');
    
    try {
      await ref.read(bestSellerRefreshProvider)();
      ref.refresh(promotionalBannersProvider);
      ref.refresh(departmentsProvider);
      ref.read(loggerProvider).log('Home data refreshed successfully');
    } catch (e) {
      ref.read(loggerProvider).error('Error refreshing home data: $e');
    }
  }

 void _handleSearch(String query) {
  ref.read(loggerProvider).log('Search query submitted: $query');
  
  if (query.isEmpty) return;
  
  if (mounted) {
    // Navigate to dedicated search screen
    context.push('/search?query=${Uri.encodeComponent(query)}');
  }
}

  @override
 Widget build(BuildContext context) {
  final selectedPincode = ref.watch(selectedPincodeProvider);
  final logger = ref.read(loggerProvider);
  
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
          // Main content
          Column(
            children: [
              // Dynamic App Bar - changes height based on scroll
              _buildDynamicAppBar(),
              
              // Main scrollable content
              Expanded(
                child: RefreshIndicator(
                  key: _refreshIndicatorKey,
                  onRefresh: _refreshHomeData,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Original header that disappears when scrolled
                      if (!_isSearchSticky)
                        SliverToBoxAdapter(
                          child: HeaderWidget(
                            pincode: selectedPincode ?? 'Not Set',
                            onChangeTap: () {
                              logger.log('Change location pressed');
                              if (mounted) {
                                context.go('/location-change');
                              }
                            },
                          ),
                        ),

                      // Original search bar that fades out when scrolled
                      if (!_isSearchSticky)
                        SliverToBoxAdapter(
                          child: SearchWidget(
                            controller: _searchController,
                            onSearch: (query) {
                              if (query.isNotEmpty && mounted) {
                                // Clear any existing search results first
                                ref.read(searchStateProvider.notifier).clearResults();
                                // Navigate to search screen
                                context.push('/search?query=${Uri.encodeComponent(query)}');
                              }
                            },
                            showSuggestions: false, // Disable suggestions on home screen
                          ),
                        ),

                      // Add some spacing after search
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Popular Categories Widget
                      SliverToBoxAdapter(
                        child: const PopularCategoryWidget(
                          sectionId: 1,
                          showTitle: false,
                          showViewAll: false,
                          itemWidth: 110,
                          itemHeight: 120,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          spacing: 12,
                        ),
                      ),
                      
                      // Rest of your content...
                      // Main Promotional Banner
                      SliverToBoxAdapter(
                        child: PromotionalBannerWidget(
                          height: 300,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 4),
                          fadeTransitionDuration: const Duration(milliseconds: 800),
                          showPageIndicator: true,
                          indicatorActiveColor: AppColors.primary,
                          indicatorInactiveColor: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        )
                      ),
                      
                      // Best Seller sections
                      ...List.generate(4, (index) {
                        final bestSellerId = index + 1;
                        return SliverToBoxAdapter(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final backgroundColor = ref.watch(
                                bestSellerBackgroundColorProvider(bestSellerId)
                              );
                              
                              return BestSellerWidget(
                                key: ValueKey('best_seller_${bestSellerId}_${backgroundColor.value}'),
                                bestSellerId: bestSellerId,
                                height: 320,
                              );
                            },
                          ),
                        );
                      }),
                      
                      // Seasonal Picks
                      const SliverToBoxAdapter(
                        child: SeasonalPicksWidget(),
                      ),
                      
                      // Popular Category sections
                      ...List.generate(4, (index) {
                        return SliverToBoxAdapter(
                          child: PopularCategoryWidget(
                            sectionId: index + 2,
                            showTitle: true,
                            showViewAll: true,
                            itemWidth: 110,
                            itemHeight: 120,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            spacing: 12,
                          ),
                        );
                      }),
                      
                      // Extra space at the bottom
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 60),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Floating sticky search bar that appears at the very top
          AnimatedBuilder(
            animation: _searchSlideAnimation,
            builder: (context, child) {
              return _isSearchSticky
                  ? Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _searchSlideAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  // Search widget takes most space
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 16),
                                      child: SearchWidget(
                                        controller: _searchController,
                                        onSearch: (query) {
                                          if (query.isNotEmpty && mounted) {
                                            context.push('/search?query=${Uri.encodeComponent(query)}');
                                          }
                                        },
                                        showSuggestions: false, // Disable suggestions in sticky mode
                                      ),
                                    ),
                                  ),
                                  
                                  // Action buttons (Cart & Wishlist)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
                                        onPressed: () {
                                          ref.read(loggerProvider).log('Favorites button pressed');
                                          if (mounted) {
                                            context.push('/favorites');
                                          }
                                        },
                                      ),
                                      // Cart icon with badge
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                                            onPressed: () {
                                              ref.read(loggerProvider).log('Cart button pressed');
                                              if (mounted) {
                                                context.push('/cart');
                                              }
                                            },
                                          ),
                                          Consumer(
                                            builder: (context, ref, _) {
                                              final cartCount = ref.watch(cartCountProvider);
                                              return cartCount > 0
                                                  ? Positioned(
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
                                                    )
                                                  : const SizedBox.shrink();
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      
      drawer: _buildDrawer(),
      
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersistentCartWidget(),
          BottomNavigationWidget(
            currentIndex: _currentNavIndex,
            onTap: (index) {
              logger.log('Bottom navigation tapped: $index');
              
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
      ),
      
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: AppColors.primary.withOpacity(0.8),
        child: const Icon(Icons.refresh, color: Colors.white),
        onPressed: () {
          logger.log('Refresh button pressed');
          _refreshIndicatorKey.currentState?.show();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    ),
  );
}

Widget _buildSearchResults() {
  final searchState = ref.watch(searchStateProvider);
  
  // Don't show results if query is too short or empty
  if (searchState.query.length < 3 || searchState.results.isEmpty) {
    return const SizedBox.shrink();
  }
  
  return Positioned(
    top: _isSearchSticky ? 100 : 170, // Adjust based on search bar position
    left: 16,
    right: 16,
    child: Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: searchState.isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: searchState.results.length > 5 
                    ? 5 
                    : searchState.results.length, // Limit to 5 items
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = searchState.results[index];
                  final productName = result['product_name'] ?? 'Unknown Product';
                  final productImage = result['pcode_img'] ?? '';
                  final pCode = result['p_code'] ?? '';
                  final ourPrice = double.tryParse(result['our_price']?.toString() ?? '0') ?? 0.0;
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: productImage.isNotEmpty
                            ? Image.network(
                                productImage,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.image_not_supported_outlined),
                              )
                            : const Icon(Icons.search, color: Colors.grey),
                      ),
                    ),
                    title: Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: ourPrice > 0 
                        ? Text(
                            '₹${ourPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () {
                      // Clear search results
                      ref.read(searchStateProvider.notifier).clearResults();
                      
                      if (pCode.isNotEmpty) {
                        context.push('/product/$pCode');
                      }
                    },
                  );
                },
              ),
      ),
    ),
  );
}

  Widget _buildDynamicAppBar() {
  final cartCount = ref.watch(cartCountProvider);
  
  return AnimatedBuilder(
    animation: Listenable.merge([_logoOpacityAnimation, _logoScaleAnimation]),
    builder: (context, child) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchSticky ? 0 : 56, // Collapse height when sticky
            child: _isSearchSticky 
                ? const SizedBox.shrink() // Completely hide when sticky
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Menu button
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          ),
                        ),
                        
                        // Space between menu and logo
                        const SizedBox(width: 8),
                        
                        // Logo with fade and scale animation - now left-aligned after drawer
                        Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Opacity(
                            opacity: _logoOpacityAnimation.value,
                            child: Image.asset(
                              'assets/images/patelLogo.png',
                              height: 42, // Increased from 32 to 42
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                ref.read(loggerProvider).error('Error loading logo: $error');
                                return const Icon(Icons.store, color: Colors.white, size: 42); // Increased error icon size too
                              },
                            ),
                          ),
                        ),
                        
                        // Spacer to push action buttons to the right
                        const Spacer(),
                        
                        // Action buttons with fade animation
                        Opacity(
                          opacity: _logoOpacityAnimation.value,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
                                onPressed: () {
                                  ref.read(loggerProvider).log('Favorites button pressed');
                                  if (mounted) {
                                    context.push('/favorites');
                                  }
                                },
                              ),
                              // Cart icon with badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                                    onPressed: () {
                                      ref.read(loggerProvider).log('Cart button pressed');
                                      if (mounted) {
                                        context.push('/cart');
                                      }
                                    },
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
  Widget _buildDrawer() {
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final logger = ref.read(loggerProvider);
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        logger.log('Drawer back button pressed');
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      'Hi, Guest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    selectedOutletAsync.when(
                      data: (outlet) => Expanded(
                        child: Text(
                          ref.watch(selectedPincodeProvider) ?? 'No pincode selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      loading: () => const Text(
                        'Loading...',
                        style: TextStyle(color: Colors.white),
                      ),
                      error: (_, __) => const Text(
                        'Error loading location',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      onPressed: () {
                        logger.log('Edit location pressed from drawer');
                        Navigator.pop(context);
                        if (mounted) {
                          context.go('/location-change');
                        }
                      },
                    ),
                  ],
                ),
                
                Image.asset(
                  'assets/images/patelLogo.png',
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    logger.error('Error loading drawer logo: $error');
                    return const Icon(Icons.store, color: Colors.white, size: 40);
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.grid_view, color: AppColors.primary),
                  title: const Text('SHOP BY CATEGORY'),
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    logger.log('Shop by category pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/category');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.shopping_cart, color: AppColors.primary),
                  title: const Text('View Cart'),
                  trailing: cartCount > 0
                      ? Text(
                          '₹${cartTotal.toStringAsFixed(2)} (${cartCount.toString()})',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  onTap: () {
                    logger.log('View Cart pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.push('/cart');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.help_outline, color: AppColors.primary),
                  title: const Text('Help & Support'),
                  onTap: () {
                    logger.log('Help & Support pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/help-support');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.description_outlined, color: AppColors.primary),
                  title: const Text('Refund, Terms and Policies'),
                  onTap: () {
                    logger.log('Refund policies pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/refund-policies');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  title: const Text('Frequently Asked Questions'),
                  onTap: () {
                    logger.log('FAQ pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/faq');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('About Us'),
                  onTap: () {
                    logger.log('About Us pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/about-us');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.store, color: AppColors.primary),
                  title: const Text('Store Information'),
                  onTap: () {
                    logger.log('Store Information pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/store-info');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.location_on, color: AppColors.primary),
                  title: const Text('Change Location'),
                 onTap: () {
                    logger.log('Change Location pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/location-change');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.refresh, color: AppColors.primary),
                  title: const Text('Refresh All Best Sellers'),
                  onTap: () async {
                    logger.log('Refresh Best Sellers pressed');
                    Navigator.pop(context);
                    await ref.read(bestSellerRefreshProvider)();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Best seller data refreshed'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Version 5.2.1',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}