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
import '../../providers/subcategory_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import 'widgets/product_item_widget.dart';
import '../../../di/infrastructure_providers.dart';
import '../../../domain/entities/catalogue.dart';

class SubcategoryScreen extends ConsumerStatefulWidget {
  final String categoryName;
  final String categoryId;
  final String deptId;

  const SubcategoryScreen({
    super.key,
    required this.categoryName,
    required this.categoryId,
    required this.deptId,
  });

  @override
  ConsumerState<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends ConsumerState<SubcategoryScreen> 
    with TickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  int _selectedIndex = 0;
  int _navIndex = 1;
  bool _isRefreshing = false;
  
  // Simplified state management - no jerky boolean switches
  double _scrollOffset = 0.0;
  
  // Single animation controller for smooth transitions
  late AnimationController _headerAnimationController;
  late Animation<double> _headerOpacity;
  late Animation<double> _headerScale;
  
  // Smooth thresholds
  static const double _headerFadeStart = 30.0;
  static const double _headerFadeEnd = 80.0;
  static const double _stickyHeaderThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    
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
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
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

  // Get sort option display name
  String _getSortOptionName(SortOption option) {
    switch (option) {
      case SortOption.priceLowToHigh:
        return "Price: Low to High";
      case SortOption.priceHighToLow:
        return "Price: High to Low";
      case SortOption.none:
        return "Default";
    }
  }

  SubcategoryQuery _subcategoryQuery(String storeCode) => SubcategoryQuery(
        categoryId: widget.categoryId,
        deptId: widget.deptId,
        storeCode: storeCode,
      );

  // Handle refresh action
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      ref.read(refreshSubcategoryProvider.notifier).state = true;

      final selectedOutlet = ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? "TTL";
      final query = _subcategoryQuery(storeCode);

      // ignore: unused_result — awaited for completion; the value is not needed.
      await ref.refresh(subcategoriesProvider(query).future);

      final subcategoriesAsync = ref.read(subcategoriesProvider(query));
      // Index 0 is the ALL tab; anything else names a real subcategory.
      String subCategoryId = kAllSubcategories;

      if (_selectedIndex > 0) {
        subcategoriesAsync.whenData((subcategories) {
          if (_selectedIndex <= subcategories.length) {
            subCategoryId = subcategories[_selectedIndex - 1].code;
          }
        });
      }

      final filterParams = ProductFilterParams(
        deptId: widget.deptId,
        categoryId: widget.categoryId,
        subCategoryId: subCategoryId,
        storeCode: storeCode,
      );
      
      // ignore: unused_result — awaited for completion; the value is not needed.
      await ref.refresh(productsProvider(filterParams).future);
    } catch (e) {
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

  // Build the tab bar widget
  // Typed. Was a bare `List`, i.e. List<dynamic> — member access compiled
  // against anything and would only fail at runtime.
  Widget _buildTabBarWidget(List<Subcategory> subcategories) {
    if (_tabController == null) return const SizedBox.shrink();
    
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 2,
            offset: const Offset(0, 1),
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
              subcategory.name, 
              _selectedIndex == subcategories.indexOf(subcategory) + 1
            )
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  // Build the filter section widget
  Widget _buildFilterSection(List products, SortOption currentSortOption) {
    return Container(
      color: Colors.white,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final storeCode = selectedOutletAsync.asData?.value?.storeCode ?? "TTL";

    final subcategoriesAsync =
        ref.watch(subcategoriesProvider(_subcategoryQuery(storeCode)));
    // Subscription kept deliberately: the binding was unused but the
    // watch is what rebuilds this on change.
    ref.watch(selectedPincodeProvider);
    final logger = ref.read(loggerProvider);
    
    // Setup tab controller when data is available
    subcategoriesAsync.whenData((subcategories) {
      final tabCount = subcategories.length + 1;
      
      if (_tabController == null || _tabController!.length != tabCount) {
        _tabController?.dispose();
        
        _tabController = TabController(
          length: tabCount,
          vsync: this,
          initialIndex: _selectedIndex < tabCount ? _selectedIndex : 0,
        );
        
        _tabController!.addListener(() {
          if (!_tabController!.indexIsChanging && mounted) {
            setState(() {
              _selectedIndex = _tabController!.index;
            });
          }
        });
      }
    });
    
    final filterParams = subcategoriesAsync.valueOrNull != null &&
                         subcategoriesAsync.valueOrNull!.isNotEmpty && 
                         _selectedIndex > 0 && 
                         _selectedIndex <= subcategoriesAsync.valueOrNull!.length
        ? ProductFilterParams(
            deptId: widget.deptId,
            categoryId: widget.categoryId,
            subCategoryId: subcategoriesAsync.valueOrNull![_selectedIndex - 1].code,
            storeCode: storeCode,
          )
        : ProductFilterParams(
            deptId: widget.deptId,
            categoryId: widget.categoryId,
            subCategoryId: kAllSubcategories,
            storeCode: storeCode,
          );
    
    final productsAsync = ref.watch(productsProvider(filterParams));
    // Subscription kept deliberately: the binding was unused but the
    // watch is what rebuilds this on change.
    ref.watch(cartTotalProvider);
    final cartCount = ref.watch(cartCountProvider);
    final currentSortOption = ref.watch(sortOptionProvider);
    
    // Check if we should show sticky header
    final showStickyHeader = _scrollOffset > _stickyHeaderThreshold;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content with NestedScrollView for smoother sticky behavior
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
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  title: AnimatedBuilder(
                    animation: _headerOpacity,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _headerScale.value,
                        child: Opacity(
                          opacity: _headerOpacity.value,
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
                      );
                    },
                  ),
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
                                icon: const Icon(Icons.search, color: Colors.white),
                                onPressed: () {
                                  logger.log('Search button pressed');
                                  context.push('/search');
                                },
                              ),
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
                        );
                      },
                    ),
                  ],
                ),
                
                // Sticky Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: subcategoriesAsync.when(
                      data: (subcategories) => _buildTabBarWidget(subcategories),
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
                ),
                
                // Filter Section
                SliverToBoxAdapter(
                  child: productsAsync.when(
                    data: (products) => _buildFilterSection(products, currentSortOption),
                    loading: () => _buildFilterShimmer(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ];
            },
            body: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppColors.primary,
              child: productsAsync.when(
                data: (products) {
                  final sortedProducts = ref.watch(sortedProductsProvider(products));
                  
                  if (sortedProducts.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: sortedProducts.length,
                    itemBuilder: (context, index) {
                      final product = sortedProducts[index];
                      return ProductItemWidget(
                        product: product,
                        onAddToCart: () {
                          // Handled in ProductItemWidget
                        },
                        onToggleFavorite: () {
                          // TODO: Implement favorite functionality
                        },
                      );
                    },
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
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
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {
                          logger.log('Search button pressed');
                          context.push('/search');
                        },
                      ),
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
        ],
      ),
      
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersistentCartWidget(),
          BottomNavigationWidget(
            currentIndex: _navIndex,
            onTap: (index) {
              setState(() {
                _navIndex = index;
              });
              if (index == 0) {
                context.go('/home');
              } else if (index == 1) {
                context.go('/category');
              } else if (index == 2) {
                context.push('/cart');
              } else if (index == 3) {
                context.push('/reorder');
              } else if (index == 4) {
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
            _buildSortOption(context, "Default", SortOption.none),
            _buildSortOption(context, "Price: Low to High", SortOption.priceLowToHigh),
            _buildSortOption(context, "Price: High to Low", SortOption.priceHighToLow),
          ],
        ),
      ),
    );
  }
  
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

  // Shimmer for filter section loading
  Widget _buildFilterShimmer() {
    return Container(
      color: Colors.white,
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
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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
        itemCount: 5,
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: 5,
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
    );
  }

  Widget _buildTab(String title, bool isSelected) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

// Custom delegate for sticky tab bar
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}