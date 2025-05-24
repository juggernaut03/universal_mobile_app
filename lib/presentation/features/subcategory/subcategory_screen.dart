// lib/presentation/features/subcategory/subcategory_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/features/cart/widgets/persistent_cart_widget.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bottom_navigation_widget.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../core/widgets/search_widget.dart';
import '../../providers/subcategory_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/best_seller_providers.dart';
import 'widgets/product_item_widget.dart';

class SubcategoryScreen extends ConsumerStatefulWidget {
  final String categoryName;
  final String categoryId;
  final String deptId;

  const SubcategoryScreen({
    Key? key,
    required this.categoryName,
    required this.categoryId,
    required this.deptId,
  }) : super(key: key);

  @override
  ConsumerState<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends ConsumerState<SubcategoryScreen> 
    with TickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  int _selectedIndex = 0;
  int _navIndex = 1; // Starting on category tab index
  bool _isRefreshing = false;
  bool _isSearchSticky = false;
  
  // Animation controllers for smooth transitions
  late AnimationController _appBarAnimationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _titleOpacityAnimation;
  late Animation<double> _titleScaleAnimation;
  late Animation<Offset> _searchSlideAnimation;
  
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
    
    // Title animations
    _titleOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _titleScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Search slide animation - slides from top
    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _scrollController.addListener(_onScroll);
    
    _searchController.addListener(() {
      // Handle search functionality if needed
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _appBarAnimationController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
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
      } else {
        _appBarAnimationController.reverse();
        _searchAnimationController.reverse();
      }
    }
  }

  // Get sort option display name
  String _getSortOptionName(SortOption option) {
    switch (option) {
      case SortOption.priceLowToHigh:
        return "Price: Low to High";
      case SortOption.priceHighToLow:
        return "Price: High to Low";
      case SortOption.none:
      default:
        return "Default";
    }
  }

  // Handle refresh action
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Set the refresh flag to true which will trigger cache clearing in the providers
      ref.read(refreshSubcategoryProvider.notifier).state = true;
      
      // Re-fetch the subcategories
      await ref.refresh(subcategoriesProvider(widget.categoryId).future);
      
      // Get the subcategories data, handling the AsyncValue properly
      final subcategoriesAsync = ref.read(subcategoriesProvider(widget.categoryId));
      
      // Setup filter parameters based on selected tab
      String subCategoryId = "0"; // Default to "ALL"
      
      // Only try to access subcategory ID if we have data and the selected index is valid
      if (_selectedIndex > 0) {
        subcategoriesAsync.whenData((subcategories) {
          if (_selectedIndex <= subcategories.length) {
            subCategoryId = subcategories[_selectedIndex - 1].subCategoryId;
          }
        });
      }
      
      // Get store code from selected outlet
      final selectedOutlet = ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? "TTL"; // Fallback to TTL if no outlet selected
      
      final filterParams = ProductFilterParams(
        deptId: widget.deptId,
        categoryId: widget.categoryId,
        subCategoryId: subCategoryId,
        storeCode: storeCode,
      );
      
      // Re-fetch the products
      await ref.refresh(productsProvider(filterParams).future);
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _handleSearch(String query) {
    ref.read(loggerProvider).log('Search query submitted: $query');
    
    if (query.isEmpty) return;
    
    if (mounted) {
      context.push('/search?query=$query');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subcategoriesAsync = ref.watch(subcategoriesProvider(widget.categoryId));
    final selectedPincode = ref.watch(selectedPincodeProvider);
    final logger = ref.read(loggerProvider);
    
    // Setup tab controller when data is available
    subcategoriesAsync.whenData((subcategories) {
      final tabCount = subcategories.length + 1; // +1 for "ALL" tab
      
      if (_tabController == null || _tabController!.length != tabCount) {
        // Dispose existing controller if it exists
        _tabController?.dispose();
        
        // Create new controller with correct number of tabs
        _tabController = TabController(
          length: tabCount,
          vsync: this,
          initialIndex: _selectedIndex < tabCount ? _selectedIndex : 0,
        );
        
        // Add listener for tab changes
        _tabController!.addListener(() {
          if (!_tabController!.indexIsChanging && mounted) {
            setState(() {
              _selectedIndex = _tabController!.index;
            });
          }
        });
      }
    });
    
    // Get the store code from the selected outlet
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final storeCode = selectedOutletAsync.asData?.value?.storeCode ?? "TTL";
    
    // Setup filter parameters based on selected tab
    final filterParams = subcategoriesAsync.valueOrNull != null && 
                         subcategoriesAsync.valueOrNull!.isNotEmpty && 
                         _selectedIndex > 0 && 
                         _selectedIndex <= subcategoriesAsync.valueOrNull!.length
        ? ProductFilterParams(
            deptId: widget.deptId,
            categoryId: widget.categoryId,
            subCategoryId: subcategoriesAsync.valueOrNull![_selectedIndex - 1].subCategoryId,
            storeCode: storeCode,
          )
        : ProductFilterParams(
            deptId: widget.deptId,
            categoryId: widget.categoryId,
            subCategoryId: "0", // Default to "ALL"
            storeCode: storeCode,
          );
    
    final productsAsync = ref.watch(productsProvider(filterParams));
    final cartTotal = ref.watch(cartTotalProvider);
    final cartCount = ref.watch(cartCountProvider);
    final currentSortOption = ref.watch(sortOptionProvider);
    
    return Scaffold(
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
                  onRefresh: _handleRefresh,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Tab Bar
                      SliverToBoxAdapter(
                        child: subcategoriesAsync.when(
                          data: (subcategories) {
                            // Check if tab controller is initialized
                            if (_tabController == null) return const SizedBox.shrink();
                            
                            return Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.black87,
                                indicatorColor: Colors.transparent,
                                labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
                                unselectedLabelStyle: AppTextStyles.labelMedium,
                                tabs: [
                                  _buildTab("ALL", _selectedIndex == 0),
                                  ...subcategories.map((subcategory) => 
                                    _buildTab(
                                      subcategory.subCategoryName, 
                                      _selectedIndex == subcategories.indexOf(subcategory) + 1
                                    )
                                  ).toList(),
                                ],
                                onTap: (index) {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                              ),
                            );
                          },
                          loading: () => _buildTabBarShimmer(),
                          error: (_, __) => Container(
                            height: 50,
                            alignment: Alignment.center,
                            child: Text(
                              'Failed to load subcategories',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                            ),
                          ),
                        ),
                      ),
                      
                      // Product Count & List
                      SliverFillRemaining(
                        child: productsAsync.when(
                          data: (products) {
                            // Apply sorting through the provider
                            final sortedProducts = ref.watch(sortedProductsProvider(products));
                            
                            return Column(
                              children: [
                                // Product Count with Sort Option
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${products.length} Products",
                                        style: AppTextStyles.labelMedium.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      // Sort dropdown button
                                      InkWell(
                                        onTap: () {
                                          _showSortOptions(context);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: AppColors.neutral300),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Sort: ${_getSortOptionName(currentSortOption)}",
                                                style: AppTextStyles.labelSmall.copyWith(
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.sort,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Product List
                                Expanded(
                                  child: sortedProducts.isEmpty
                                      ? _buildEmptyState()
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                          itemCount: sortedProducts.length,
                                          itemBuilder: (context, index) {
                                            final product = sortedProducts[index];
                                            return ProductItemWidget(
                                              product: product,
                                              onAddToCart: () {
                                                // This is now handled directly in the ProductItemWidget
                                              },
                                              onToggleFavorite: () {
                                                // TODO: Implement favorite functionality
                                              },
                                            );
                                          },
                                        ),
                                ),
                              ],
                            );
                          },
                          loading: () => _buildProductsShimmer(),
                          error: (error, _) => Center(
                            child: AppErrorWidget(
                              errorType: ErrorType.server,
                              message: 'Error loading products: ${error.toString()}',
                              onRetry: () => ref.refresh(productsProvider(filterParams)),
                            ),
                          ),
                        ),
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
                                  // Back button
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                                    onPressed: () => context.pop(),
                                  ),
                                  
                                  // Title
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        widget.categoryName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  
                                  // Search icon
                                  IconButton(
                                    icon: const Icon(
                                      Icons.search,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      logger.log('Search button pressed');
                                      context.push('/search');
                                    },
                                  ),
                                  
                                  // Cart icon with badge
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                                        onPressed: () {
                                          logger.log('Cart button pressed');
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
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // This is our persistent cart widget
          const PersistentCartWidget(),
          
          // The existing bottom navigation bar
          BottomNavigationWidget(
            currentIndex: _navIndex,
            onTap: (index) {
              setState(() {
                _navIndex = index;
              });
              // Handle navigation based on index
              if (index == 0) { // Home
                context.go('/home');
              } else if (index == 1) { // Category
                context.go('/category');
              } else if (index == 2) { // Cart
                context.push('/cart');
              } else if (index == 3) { // Reorder
                context.push('/reorder');
              } else if (index == 4) { // Account
                context.go('/account');
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
          _handleRefresh();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }

  Widget _buildDynamicAppBar() {
    final cartCount = ref.watch(cartCountProvider);
    
    return AnimatedBuilder(
      animation: Listenable.merge([_titleOpacityAnimation, _titleScaleAnimation]),
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
                          // Back button
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => context.pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          
                          // Category title with fade and scale animation
                          Expanded(
                            child: Transform.scale(
                              scale: _titleScaleAnimation.value,
                              child: Opacity(
                                opacity: _titleOpacityAnimation.value,
                                child: Text(
                                  widget.categoryName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          
                          // Action buttons with fade animation
                          Opacity(
                            opacity: _titleOpacityAnimation.value,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Search icon
                                IconButton(
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  onPressed: () {
                                    ref.read(loggerProvider).log('Search button pressed');
                                    context.push('/search');
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                
                                const SizedBox(width: 16),
                                
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
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    if (cartCount > 0)
                                      Positioned(
                                        right: -5,
                                        top: -5,
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
  
  // Show sort options modal
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Sort By",
                    style: AppTextStyles.h6,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(),
            _buildSortOption(
              context,
              "Default",
              SortOption.none,
            ),
            _buildSortOption(
              context,
              "Price: Low to High",
              SortOption.priceLowToHigh,
            ),
            _buildSortOption(
              context,
              "Price: High to Low",
              SortOption.priceHighToLow,
            ),
          ],
        ),
      ),
    );
  }
  
  // Build a sort option item
  Widget _buildSortOption(BuildContext context, String title, SortOption option) {
    final currentOption = ref.watch(sortOptionProvider);
    bool isSelected = currentOption == option;
    
    return InkWell(
      onTap: () {
        ref.read(sortOptionProvider.notifier).state = option;
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLighter.withOpacity(0.2) : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
  
  // Empty state when no products are found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.neutral400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different subcategory',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Shimmer for tab bar loading
  Widget _buildTabBarShimmer() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5, // Show 5 tab placeholders
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            width: index == 0 ? 80 : 120,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  // Shimmer for products loading
  Widget _buildProductsShimmer() {
    return Column(
      children: [
        // Product Count shimmer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 100,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Product list shimmer
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: 5, // Show 5 shimmer items
            itemBuilder: (context, index) {
              return Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String title, bool isSelected) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}