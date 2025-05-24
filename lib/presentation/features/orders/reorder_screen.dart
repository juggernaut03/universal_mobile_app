// lib/presentation/features/orders/reorder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/features/orders/my_orders_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/bottom_navigation_widget.dart';
import '../../../core/widgets/search_widget.dart';
import '../../providers/cart_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../features/cart/widgets/persistent_cart_widget.dart';
import '../home/home_screen.dart'; // Import for drawer

class ReorderScreen extends ConsumerStatefulWidget {
  const ReorderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends ConsumerState<ReorderScreen> with TickerProviderStateMixin {
  // Current selected index for bottom navigation
  int _currentNavIndex = 3; // Set to 3 for "Reorder" tab
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isSearchActive = false;
  
  // Animation controllers for smooth transitions
  late AnimationController _appBarAnimationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _searchSlideAnimation;
  
  bool _isSearchSticky = false;
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
    
    // Search slide animation
    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _scrollController.addListener(_onScroll);
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _isSearchActive = _searchQuery.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _appBarAnimationController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrollOffset = _scrollController.offset;
    final shouldBeSticky = scrollOffset > _stickyThreshold;
    
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

  void _handleSearch(String query) {
    // Search is handled locally by filtering the list
    ref.read(loggerProvider).log('Search query: $query');
  }

  List<ReorderItem> _filterReorderItems(List<ReorderItem> items) {
    if (_searchQuery.isEmpty) return items;
    
    return items.where((item) {
      return item.product.productName.toLowerCase().contains(_searchQuery) ||
             item.product.brandName.toLowerCase().contains(_searchQuery) ||
             item.product.pCode.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Dynamic App Bar
              _buildDynamicAppBar(),
              
              // Main content
              Expanded(
                child: ordersAsync.when(
                  data: (orders) {
                    // Extract all unique products from all orders
                    final Map<String, ReorderItem> reorderItems = {};
                    
                    for (final order in orders) {
                      for (final item in order.items) {
                        final productId = item.product.pCode;
                        
                        if (reorderItems.containsKey(productId)) {
                          // Update with most recent order's quantity
                          if (order.orderDate.isAfter(reorderItems[productId]!.lastOrderedDate)) {
                            reorderItems[productId] = ReorderItem(
                              product: item.product,
                              quantity: item.quantity,
                              lastOrderedDate: order.orderDate,
                            );
                          }
                        } else {
                          // Add new product
                          reorderItems[productId] = ReorderItem(
                            product: item.product,
                            quantity: item.quantity,
                            lastOrderedDate: order.orderDate,
                          );
                        }
                      }
                    }
                    
                    // Sort by most recently ordered
                    final sortedReorderItems = reorderItems.values.toList()
                      ..sort((a, b) => b.lastOrderedDate.compareTo(a.lastOrderedDate));
                    
                    // Filter based on search query
                    final filteredItems = _filterReorderItems(sortedReorderItems);
                    
                    if (sortedReorderItems.isEmpty) {
                      return _buildEmptyState();
                    }
                    
                    if (filteredItems.isEmpty && _isSearchActive) {
                      return _buildNoSearchResultsState();
                    }
                    
                    return RefreshIndicator(
                      onRefresh: () async {
                        return ref.refresh(ordersProvider.future);
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          // Search bar that disappears when scrolled (only when not sticky)
                          if (!_isSearchSticky)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: SearchWidget(
                                  controller: _searchController,
                                  onSearch: _handleSearch,
                                ),
                              ),
                            ),
                          
                          // Search results summary
                          if (_isSearchActive && filteredItems.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  'Found ${filteredItems.length} item${filteredItems.length == 1 ? '' : 's'} matching "$_searchQuery"',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          
                          // Product list
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: _buildReorderProductItem(
                                    context, ref, filteredItems[index]
                                  ),
                                );
                              },
                              childCount: filteredItems.length,
                            ),
                          ),
                          
                          // Extra space at bottom
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 80),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => _buildErrorState(error),
                ),
              ),
            ],
          ),
          
          // Floating sticky search bar
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
                                  
                                  // Search widget
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      child: SearchWidget(
                                        controller: _searchController,
                                        onSearch: _handleSearch,
                                      ),
                                    ),
                                  ),
                                  
                                  // Action buttons
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
          ),
        ],
      ),
      
      drawer: _buildDrawer(),
      
      // Bottom navigation with persistent cart widget
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersistentCartWidget(),
          BottomNavigationWidget(
            currentIndex: _currentNavIndex,
            onTap: (index) {
              setState(() {
                _currentNavIndex = index;
              });
              
              switch (index) {
                case 0: // Home
                  context.go('/home');
                  break;
                case 1: // Category
                  context.go('/category');
                  break;
                case 2: // Cart/Order
                  context.go('/cart');
                  break;
                case 3: // Reorder (current screen)
                  break;
                case 4: // Account
                  context.go('/account');
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicAppBar() {
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
              height: _isSearchSticky ? 0 : 56,
              child: _isSearchSticky 
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Menu/Back button
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () {
                                Scaffold.of(context).openDrawer();
                              },
                            ),
                          ),
                          
                          // Title with fade animation
                          Expanded(
                            child: Center(
                              child: Transform.scale(
                                scale: _logoScaleAnimation.value,
                                child: Opacity(
                                  opacity: _logoOpacityAnimation.value,
                                  child: const Text(
                                    'Quick Reorder',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Action buttons
                          Opacity(
                            opacity: _logoOpacityAnimation.value,
                            child: _buildActionButtons(),
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

  Widget _buildActionButtons() {
    final cartCount = ref.watch(cartCountProvider);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
          onPressed: () {
            ref.read(loggerProvider).log('Favorites button pressed');
            context.push('/favorites');
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
                context.push('/cart');
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
                        context.go('/location-change');
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
                  leading: Icon(Icons.home, color: AppColors.primary),
                  title: const Text('Home'),
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    logger.log('Home pressed');
                    Navigator.pop(context);
                    context.go('/home');
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.grid_view, color: AppColors.primary),
                  title: const Text('SHOP BY CATEGORY'),
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    logger.log('Shop by category pressed');
                    Navigator.pop(context);
                    context.go('/category');
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
                    context.push('/cart');
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.history, color: AppColors.primary),
                  title: const Text('My Orders'),
                  onTap: () {
                    logger.log('My Orders pressed');
                    Navigator.pop(context);
                    context.push('/my-orders');
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.help_outline, color: AppColors.primary),
                  title: const Text('Help & Support'),
                  onTap: () {
                    logger.log('Help & Support pressed');
                    Navigator.pop(context);
                    context.go('/help-support');
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.description_outlined, color: AppColors.primary),
                  title: const Text('Refund, Terms and Policies'),
                  onTap: () {
                    logger.log('Refund policies pressed');
                    Navigator.pop(context);
                    context.go('/refund-policies');
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.location_on, color: AppColors.primary),
                  title: const Text('Change Location'),
                  onTap: () {
                    logger.log('Change Location pressed');
                    Navigator.pop(context);
                    context.go('/location-change');
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No items to reorder yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ordered items will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _isSearchActive = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading previous orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.refresh(ordersProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReorderProductItem(BuildContext context, WidgetRef ref, ReorderItem reorderItem) {
    // Get cart information to check if this product is in cart
    final cartItems = ref.watch(cartProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == reorderItem.product.pCode).toList();
    
    // Determine if product is in cart and its quantity
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;
    
    // Calculate discount
    final discount = reorderItem.product.productMrp - reorderItem.product.ourPrice;
    final discountPercent = reorderItem.product.productMrp > 0 
        ? ((discount / reorderItem.product.productMrp) * 100).round() 
        : 0;
        
    // Format the date
    final lastOrderedDateStr = DateFormat('dd/MM/yyyy').format(reorderItem.lastOrderedDate);

    return GestureDetector(
      onTap: () {
        // Navigate to product detail page when tapping the item
        context.push('/product/${reorderItem.product.pCode}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 1),
              blurRadius: 2,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Image with discount badge (40% width)
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4 - 16,
              child: Stack(
                children: [
                  // Product image with caching
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.network(
                      reorderItem.product.pcodeImg.isNotEmpty 
                          ? reorderItem.product.pcodeImg 
                          : ApiConstants.fallbackImageUrl,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 120,
                          color: Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Image.network(
                        ApiConstants.fallbackImageUrl,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  // Discount badge
                  if (discountPercent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        "${discountPercent.toStringAsFixed(0)}% OFF",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Right side: Product details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      reorderItem.product.productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Package size
                    Text(
                      "${reorderItem.product.packageSize} ${reorderItem.product.packageUnit.toLowerCase()}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Price section
                    Row(
                      children: [
                        Text(
                          "₹${reorderItem.product.ourPrice.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        Text(
                          "MRP₹${reorderItem.product.productMrp.toStringAsFixed(0)}",
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // "Last ordered on" text
                    Text(
                      "Last ordered on $lastOrderedDateStr",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Add to cart button or quantity selector
                    SizedBox(
                      width: double.infinity,
                      child: isInCart
                          ? Container(
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  // Decrement button
                                  GestureDetector(
                                    onTap: () => ref.read(cartProvider.notifier).decrementQuantity(reorderItem.product),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(3),
                                          bottomLeft: Radius.circular(3),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.remove,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  
                                  // Quantity
                                  Expanded(
                                    child: Container(
                                      height: 40,
                                      alignment: Alignment.center,
                                      color: Colors.white,
                                      child: Text(
                                        quantity.toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Increment button
                                  GestureDetector(
                                    onTap: () => ref.read(cartProvider.notifier).incrementQuantity(reorderItem.product),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(3),
                                          bottomRight: Radius.circular(3),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              height: 40,
                              child: ElevatedButton.icon(
                                onPressed: () => ref.read(cartProvider.notifier).addItem(reorderItem.product),
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  "REORDER",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  minimumSize: const Size(double.infinity, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
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
      ),
    );
  }
}

// Class to hold reorder information
class ReorderItem {
  final ProductModel product;
  final int quantity;
  final DateTime lastOrderedDate;
  
  ReorderItem({
    required this.product,
    required this.quantity,
    required this.lastOrderedDate,
  });
}