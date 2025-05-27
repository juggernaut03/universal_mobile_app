// lib/presentation/features/orders/reorder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:patelmart/core/widgets/favorite_button.dart';
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
                                  child: _ReorderProductItemWidget(
                                    reorderItem: filteredItems[index],
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
}

// Reorder Product Item Widget - matching the ProductItemWidget functionality
class _ReorderProductItemWidget extends ConsumerStatefulWidget {
  final ReorderItem reorderItem;

  const _ReorderProductItemWidget({
    required this.reorderItem,
  });

  @override
  ConsumerState<_ReorderProductItemWidget> createState() => _ReorderProductItemWidgetState();
}

class _ReorderProductItemWidgetState extends ConsumerState<_ReorderProductItemWidget> {
  
  void _addToCart() {
    ref.read(cartProvider.notifier).addItem(widget.reorderItem.product);
  }

  void _incrementQuantity() {
    final cartItems = ref.read(cartProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == widget.reorderItem.product.pCode).toList();
    final currentQuantity = cartItem.isNotEmpty ? cartItem.first.quantity : 0;
    
    if (currentQuantity < widget.reorderItem.product.maxQuantityAllowed) {
      ref.read(cartProvider.notifier).incrementQuantity(widget.reorderItem.product);
    } else {
      _showMaxQuantityMessage();
    }
  }

  void _decrementQuantity() {
    ref.read(cartProvider.notifier).decrementQuantity(widget.reorderItem.product);
  }

  void _navigateToProductDetail() {
    // Ensure p_code is properly formatted
    final pCode = widget.reorderItem.product.pCode;
    
    // Get storeCode from the selected outlet instead of using static value
    final selectedOutlet = ref.read(selectedOutletProvider).value;
    final storeCode = selectedOutlet?.storeCode ?? widget.reorderItem.product.storeCode;
    
    // Use the go_router path parameters format correctly
    context.push('/product/$pCode?storeCode=$storeCode');
  }

  // Handle manual quantity input
  void _handleManualQuantityInput(int newQuantity) {
    final logger = ref.read(loggerProvider);
    
    if (newQuantity <= 0) {
      logger.log('Quantity is 0 or less, removing item from cart');
      ref.read(cartProvider.notifier).removeItem(widget.reorderItem.product);
      return;
    }
    
    // Check against maximum allowed quantity
    if (newQuantity > widget.reorderItem.product.maxQuantityAllowed) {
      logger.log('Quantity $newQuantity exceeds max allowed ${widget.reorderItem.product.maxQuantityAllowed}');
      // Set to maximum allowed quantity
      ref.read(cartProvider.notifier).addItemWithQuantity(widget.reorderItem.product, widget.reorderItem.product.maxQuantityAllowed);
      _showMaxQuantityMessage();
      return;
    }
    
    // Update cart with new quantity
    logger.log('Updating quantity for ${widget.reorderItem.product.productName} to $newQuantity');
    ref.read(cartProvider.notifier).addItemWithQuantity(widget.reorderItem.product, newQuantity);
  }

  // Show max quantity reached message
  void _showMaxQuantityMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${widget.reorderItem.product.maxQuantityAllowed} items allowed'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get cart information from provider to check if this product is in cart
    final cartItems = ref.watch(cartProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == widget.reorderItem.product.pCode).toList();
    
    // Determine if product is in cart and its quantity
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;
    
    // Calculate price per unit
    final pricePerUnit = widget.reorderItem.product.packageSize > 0 
        ? (widget.reorderItem.product.ourPrice / widget.reorderItem.product.packageSize) 
        : 0.0;
        
    // Calculate discount
    final discount = widget.reorderItem.product.productMrp - widget.reorderItem.product.ourPrice;
    final discountPercent = widget.reorderItem.product.productMrp > 0 
        ? ((discount / widget.reorderItem.product.productMrp) * 100).round() 
        : 0;
    
    // Format the date
    final lastOrderedDateStr = DateFormat('dd/MM/yyyy').format(widget.reorderItem.lastOrderedDate);

    return GestureDetector(
      onTap: _navigateToProductDetail, // Navigate to product detail on tap
      child: Container(
        margin: const EdgeInsets.only(bottom: 10), // Reduced margin
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Image with discount badge (40% width)
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4 - 16,
              child: Stack(
                children: [
                  // Product image with caching - also tappable
                  InkWell(
                    onTap: _navigateToProductDetail,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0), // Reduced padding
                      child: Image.network(
                        widget.reorderItem.product.pcodeImg.isNotEmpty 
                            ? widget.reorderItem.product.pcodeImg 
                            : ApiConstants.fallbackImageUrl,
                        width: double.infinity,
                        height: 110, // Reduced height
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 110,
                            color: Colors.grey[100],
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Image.network(
                          ApiConstants.fallbackImageUrl,
                          width: double.infinity,
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  
                  // Discount badge
                  if (discountPercent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
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
                          fontSize: 10, // Reduced font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Right side: Product details (60% width)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0), // Reduced vertical padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name - reduced font size and spacing
                    InkWell(
                      onTap: _navigateToProductDetail,
                      child: Text(
                        widget.reorderItem.product.productName,
                        style: const TextStyle(
                          fontSize: 14, // Reduced from 16
                          fontWeight: FontWeight.w600,
                          height: 1.2, // Reduced line height
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 4), // Reduced from 6
                    
                    // Package size and price per unit
                    Text(
                      "${widget.reorderItem.product.packageSize} ${widget.reorderItem.product.packageUnit.toLowerCase()} (₹${pricePerUnit.toStringAsFixed(2)}/GM)",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12, // Reduced from 14
                        height: 1.1, // Reduced line height
                      ),
                    ),
                    
                    const SizedBox(height: 4), // Added spacing
                    
                    // "Last ordered on" text
                    Text(
                      "Last ordered on $lastOrderedDateStr",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11, // Small font for date
                        fontStyle: FontStyle.italic,
                        height: 1.1,
                      ),
                    ),
                    
                    const SizedBox(height: 6), // Reduced from 8
                    
                    // Price section
                    Row(
                      children: [
                        Text(
                          "₹${widget.reorderItem.product.ourPrice.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 16, // Reduced from 18
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(width: 6), // Reduced from 8
                        
                        Text(
                          "MRP₹${widget.reorderItem.product.productMrp.toStringAsFixed(0)}",
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade600,
                            fontSize: 12, // Reduced from 14
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8), // Reduced from 10
                    
                    // Bottom row - now with consistent heights
                    Row(
                      children: [
                        // Favorite button with increased size to match add button
                        SizedBox(
                          width: 32, // Fixed width to match button height
                          height: 32, // Fixed height to match add button
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: FavoriteButton(
                              product: widget.reorderItem.product,
                              size: 20, // Increased size
                              showSnackbarMessages: false, // Disable to prevent overlap
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Add to cart button or manual quantity selector
                        Expanded(
                          child: isInCart
                              ? _buildManualQuantitySelector(quantity)
                              : _buildAddToCartButton(),
                        ),
                      ],
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

  // Manual quantity selector with improved styling - UPDATED to match best seller widget
  Widget _buildManualQuantitySelector(int quantity) {
    return Container(
      height: 32, // Reduced height to match favorite button
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Decrement button
          Material(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
            child: InkWell(
              onTap: () {
                if (quantity > 1) {
                  _decrementQuantity();
                } else {
                  // Remove item if quantity becomes 0
                  ref.read(cartProvider.notifier).removeItem(widget.reorderItem.product);
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
              child: Container(
                width: 32, // Fixed width to match height
                height: 32, // Fixed height
                alignment: Alignment.center,
                child: const Icon(
                  Icons.remove,
                  color: Colors.white,
                  size: 16, // Smaller icon size for better appearance
                ),
              ),
            ),
          ),
          
          // Manual quantity input field - UPDATED to match best seller widget implementation
          Expanded(
            child: Container(
              height: 32,
              color: Colors.white,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: widget.reorderItem.product.maxQuantityAllowed,
                onQuantityChanged: _handleManualQuantityInput,
              ),
            ),
          ),
          
          // Increment button
          Material(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            child: InkWell(
              onTap: _incrementQuantity,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Container(
                width: 32, // Fixed width to match height
                height: 32, // Fixed height
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16, // Smaller icon size for better appearance
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple add to cart button with reduced height
  Widget _buildAddToCartButton() {
    return SizedBox(
      height: 32, // Reduced height to match favorite button
      child: ElevatedButton.icon(
        onPressed: _addToCart,
        icon: const Icon(
          Icons.add_shopping_cart,
          color: Colors.white,
          size: 12, // Reduced icon size
        ),
        label: const Text(
          "REORDER",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11, // Reduced font size
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 32), // Reduced height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
        ),
      ),
    );
  }
}

// UPDATED Manual quantity input widget to match best seller widget implementation
class _ManualQuantityInput extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final ValueChanged<int> onQuantityChanged;

  const _ManualQuantityInput({
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
  });

  @override
  State<_ManualQuantityInput> createState() => _ManualQuantityInputState();
}

class _ManualQuantityInputState extends State<_ManualQuantityInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuantity.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_ManualQuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller only if not currently editing and quantity changed
    if (oldWidget.initialQuantity != widget.initialQuantity && !_isEditing) {
      _controller.text = widget.initialQuantity.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isEditing = _focusNode.hasFocus;
    });
    
    if (!_focusNode.hasFocus) {
      _validateAndSubmit();
    }
  }

  void _validateAndSubmit() {
    final text = _controller.text.trim();
    final quantity = int.tryParse(text);
    
    if (quantity == null || quantity < 1) {
      // Invalid input, reset to current quantity or remove
      if (widget.initialQuantity > 0) {
        _controller.text = widget.initialQuantity.toString();
      } else {
        widget.onQuantityChanged(0); // This will remove the item
      }
      return;
    }
    
    // Valid quantity, notify parent
    widget.onQuantityChanged(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Add alignment to center the TextField both horizontally and vertically
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: widget.maxQuantity.toString().length,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
          decoration: const InputDecoration(
            // Remove all borders and effects
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            
            // Remove padding and set isCollapsed to true to ensure proper vertical centering
            contentPadding: EdgeInsets.zero,
            isDense: true,
            isCollapsed: true,
            
            // Hide counter
            counterText: '',
            
            // Remove fill color
            filled: false,
            fillColor: Colors.transparent,
            
            // Remove helper text space
            helperText: null,
            
            // Disable hover effects
            hoverColor: Colors.transparent,
          ),
          
          // Disable cursor and selection handles on mobile
          showCursor: false,
          enableInteractiveSelection: false,
          
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.maxQuantity.toString().length),
            _MaxQuantityInputFormatter(widget.maxQuantity),
          ],
          onSubmitted: (_) => _validateAndSubmit(),
          onTap: () {
            // Select all text when tapped for easy editing
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          },
        ),
      ),
    );
  }
}

// Custom input formatter to prevent entering values greater than max quantity
class _MaxQuantityInputFormatter extends TextInputFormatter {
  final int maxQuantity;

  _MaxQuantityInputFormatter(this.maxQuantity);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final quantity = int.tryParse(newValue.text);
    if (quantity == null || quantity > maxQuantity) {
      // Don't allow the input if it exceeds max quantity
      return oldValue;
    }

    return newValue;
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