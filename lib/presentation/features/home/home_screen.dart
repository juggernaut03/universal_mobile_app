// lib/presentation/features/home/optimized_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/bottom_navigation_widget.dart';
import 'package:patelmart/core/widgets/header_widget.dart';
import 'package:patelmart/core/widgets/search_widget.dart';
import 'package:patelmart/presentation/features/cart/widgets/persistent_cart_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_category_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/promotional_banner_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/best_seller_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/seasonal_picks_widget.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/cart_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  // Controllers and scroll management
  late ScrollController _scrollController;
  late TextEditingController _searchController;
  
  // Animation controllers - optimized
  late AnimationController _stickyBarController;
  late Animation<double> _stickyBarAnimation;
  
  // State management
  int _currentNavIndex = 0;
  bool _isSearchSticky = false;
  DateTime? _lastBackPressTime;
  
  // Performance optimizations
  static const double _stickyThreshold = 80.0;
  static const Duration _animationDuration = Duration(milliseconds: 200);
  bool _isScrolling = false;
  
  @override
  bool get wantKeepAlive => true; // Keep alive for better performance
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    
    // Single animation controller for sticky bar
    _stickyBarController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _stickyBarAnimation = CurvedAnimation(
      parent: _stickyBarController,
      curve: Curves.fastOutSlowIn, // Better curve for smooth animation
    );
    
    // Optimized scroll listener with debouncing
    _scrollController.addListener(_onScrollOptimized);
    
    // Search controller listener
    _searchController.addListener(_onSearchChanged);
    
    // Preload critical data
    _preloadCriticalData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollOptimized);
    _scrollController.dispose();
    _searchController.dispose();
    _stickyBarController.dispose();
    super.dispose();
  }

  // Optimized scroll handling with debouncing
  void _onScrollOptimized() {
    if (!mounted) return;
    
    final scrollOffset = _scrollController.offset;
    final shouldBeSticky = scrollOffset > _stickyThreshold;
    
    // Only update if state actually changes
    if (shouldBeSticky != _isSearchSticky) {
      setState(() {
        _isSearchSticky = shouldBeSticky;
      });
      
      // Animate sticky bar
      if (_isSearchSticky) {
        _stickyBarController.forward();
      } else {
        _stickyBarController.reverse();
      }
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

  // Optimized refresh with proper error handling
  Future<void> _refreshHomeData() async {
    try {
      await Future.wait([
        ref.read(bestSellerRefreshProvider)(),
        // Add other refresh operations here
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data refreshed successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _buildOptimizedBody(),
        drawer: _buildOptimizedDrawer(),
        bottomNavigationBar: _buildBottomNavigation(),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      ),
    );
  }

  Widget _buildOptimizedBody() {
    return Stack(
      children: [
        // Main scrollable content
        Column(
          children: [
            // Static app bar
            _buildStaticAppBar(),
            
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshHomeData,
                color: AppColors.primary,
                child: _buildScrollableContent(),
              ),
            ),
          ],
        ),
        
        // Sticky search bar
        _buildStickySearchBar(),
      ],
    );
  }

  Widget _buildStaticAppBar() {
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
        child: AnimatedBuilder(
          animation: _stickyBarAnimation,
          builder: (context, child) {
            return AnimatedContainer(
              duration: _animationDuration,
              height: _isSearchSticky ? 0 : 56,
              child: _isSearchSticky 
                  ? const SizedBox.shrink()
                  : _buildAppBarContent(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBarContent() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        // Menu button
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        
        // Logo - aligned after the drawer icon instead of centered
        Image.asset(
          'assets/images/patelLogo.png',
          height: 42,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => 
              const Icon(Icons.store, color: Colors.white, size: 42),
        ),
        
        // Spacer to push action buttons to the right
        const Spacer(),
        
        // Action buttons
        _buildActionButtons(),
      ],
    ),
  );
}
  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
          onPressed: () => context.push('/favorites'),
        ),
        _buildCartButton(),
      ],
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

  Widget _buildStickySearchBar() {
    return AnimatedBuilder(
      animation: _stickyBarAnimation,
      builder: (context, child) {
        return _isSearchSticky
            ? Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, -56 * (1 - _stickyBarAnimation.value)),
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
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 16),
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
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink();
      },
    );
  }

  Widget _buildScrollableContent() {
    return CustomScrollView(
      controller: _scrollController,
      // Performance optimization: Use cacheExtent to pre-render nearby widgets
      cacheExtent: 500,
      slivers: [
        // Header (disappears when sticky)
        if (!_isSearchSticky)
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

        // Search bar (disappears when sticky)
        if (!_isSearchSticky)
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

        // Spacing
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Popular Categories - using RepaintBoundary for better performance
        SliverToBoxAdapter(
          child: RepaintBoundary(
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
        ),

        // Promotional Banner - wrapped in RepaintBoundary
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: PromotionalBannerWidget(
              height: 300,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              fadeTransitionDuration: const Duration(milliseconds: 800),
              showPageIndicator: true,
              indicatorActiveColor: AppColors.primary,
              indicatorInactiveColor: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        // Best Seller sections - optimized with RepaintBoundary and keys
        ...List.generate(4, (index) {
          final bestSellerId = index + 1;
          return SliverToBoxAdapter(
            child: RepaintBoundary(
              key: ValueKey('best_seller_repaint_$bestSellerId'),
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
            ),
          );
        }),

        // Seasonal Picks
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: const SeasonalPicksWidget(),
          ),
        ),

        // Popular Category sections
        ...List.generate(4, (index) {
          return SliverToBoxAdapter(
            child: RepaintBoundary(
              key: ValueKey('popular_category_repaint_${index + 2}'),
              child: PopularCategoryWidget(
                sectionId: index + 2,
                showTitle: true,
                showViewAll: true,
                itemWidth: 110,
                itemHeight: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                spacing: 12,
              ),
            ),
          );
        }),

        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 60),
        ),
      ],
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

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: AppColors.primary.withOpacity(0.8),
      child: const Icon(Icons.refresh, color: Colors.white),
      onPressed: _refreshHomeData,
    );
  }

  Widget _buildOptimizedDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(child: _buildDrawerItems()),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: BoxDecoration(color: AppColors.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
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
          
          Consumer(
            builder: (context, ref, _) {
              final selectedPincode = ref.watch(selectedPincodeProvider);
              return Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedPincode ?? 'No pincode selected',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/location-change');
                    },
                  ),
                ],
              );
            },
          ),
          
          Image.asset(
            'assets/images/patelLogo.png',
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.store, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItems() {
    final drawerItems = [
      _DrawerItem(
        icon: Icons.grid_view,
        title: 'SHOP BY CATEGORY',
        onTap: () => _navigateFromDrawer('/category'),
      ),
      _DrawerItem(
        icon: Icons.shopping_cart,
        title: 'View Cart',
        onTap: () => _navigateFromDrawer('/cart'),
        trailing: Consumer(
          builder: (context, ref, _) {
            final cartCount = ref.watch(cartCountProvider);
            final cartTotal = ref.watch(cartTotalProvider);
            return cartCount > 0
                ? Text(
                    '₹${cartTotal.toStringAsFixed(2)} (${cartCount.toString()})',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),
      ),
      _DrawerItem(
        icon: Icons.help_outline,
        title: 'Help & Support',
        onTap: () => _navigateFromDrawer('/help-support'),
      ),
      _DrawerItem(
        icon: Icons.info_outline,
        title: 'About Us',
        onTap: () => _navigateFromDrawer('/about-us'),
      ),
      _DrawerItem(
        icon: Icons.store,
        title: 'Store Information',
        onTap: () => _navigateFromDrawer('/store-info'),
      ),
      _DrawerItem(
        icon: Icons.location_on,
        title: 'Change Location',
        onTap: () => _navigateFromDrawer('/location-change'),
      ),
    ];

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: drawerItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = drawerItems[index];
        return ListTile(
          leading: Icon(item.icon, color: AppColors.primary),
          title: Text(item.title),
          trailing: item.trailing ?? const Icon(Icons.navigate_next),
          onTap: item.onTap,
        );
      },
    );
  }

  void _navigateFromDrawer(String route) {
    Navigator.pop(context);
    if (mounted) {
      context.go(route);
    }
  }
}

// Helper class for drawer items
class _DrawerItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });
}