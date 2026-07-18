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
import '../../providers/cart_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/outlet_status_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../features/cart/widgets/persistent_cart_widget.dart';
import 'package:patelmart/core/widgets/brand_logo.dart';

// Define ReorderItem at the top level
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

// Manual quantity input widget to match best seller widget implementation
class _ManualQuantityInput extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final bool enabled;
  final ValueChanged<int> onQuantityChanged;

  const _ManualQuantityInput({
    required this.initialQuantity,
    required this.maxQuantity,
    this.enabled = true,
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
      if (widget.initialQuantity > 0) {
        _controller.text = widget.initialQuantity.toString();
      } else {
        widget.onQuantityChanged(0);
      }
      return;
    }

    widget.onQuantityChanged(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: widget.maxQuantity.toString().length,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: widget.enabled ? Colors.black87 : Colors.grey.shade600,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            isCollapsed: true,
            counterText: '',
            filled: false,
            fillColor: Colors.transparent,
            helperText: null,
            hoverColor: Colors.transparent,
          ),
          showCursor: false,
          enableInteractiveSelection: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.maxQuantity.toString().length),
            _MaxQuantityInputFormatter(widget.maxQuantity),
          ],
          onSubmitted: (_) => _validateAndSubmit(),
          onTap: widget.enabled
              ? () {
                  _controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controller.text.length,
                  );
                }
              : null,
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
      return oldValue;
    }

    return newValue;
  }
}

class ReorderScreen extends ConsumerStatefulWidget {
  const ReorderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends ConsumerState<ReorderScreen>
    with TickerProviderStateMixin {
  int _currentNavIndex = 3;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isSearchActive = false;
  late AnimationController _appBarAnimationController;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _logoScaleAnimation;
  bool _isSearchSticky = false;
  static const double _stickyThreshold = 80.0;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
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
    _searchFocusNode.dispose();
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
      } else {
        _appBarAnimationController.reverse();
      }
    }
  }

  void _handleSearch(String query) {
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

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSearchActive = false;
      FocusScope.of(context).unfocus();
    });
  }

  // Custom back navigation handler
  Future<bool> _handleBackPress() async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on ReorderScreen - navigating to home');
    
    try {
      // Navigate to home using go
      context.go('/home');
      
      // Return false to prevent default back navigation
      return false;
    } catch (e) {
      logger.error('Error handling back navigation: $e');
      // If go fails, try push as fallback
      if (context.mounted) {
        context.pushReplacement('/home');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted - going to home');
          
          // Navigate to home
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: _handleBackPress,
        child: Scaffold(
          backgroundColor: AppColors.primary, // Changed to match app bar color
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildDynamicAppBar(),
                    Expanded(
                      child: Container(
                        color: Colors.white, // Ensure the content area below app bar is white
                        child: ordersAsync.when(
                          data: (orders) {
                            final Map<String, ReorderItem> reorderItems = {};
                            for (final order in orders) {
                              for (final item in order.items) {
                                final productId = item.product.pCode;
                                if (reorderItems.containsKey(productId)) {
                                  if (order.orderDate
                                      .isAfter(reorderItems[productId]!.lastOrderedDate)) {
                                    reorderItems[productId] = ReorderItem(
                                      product: item.product,
                                      quantity: item.quantity,
                                      lastOrderedDate: order.orderDate,
                                    );
                                  }
                                } else {
                                  reorderItems[productId] = ReorderItem(
                                    product: item.product,
                                    quantity: item.quantity,
                                    lastOrderedDate: order.orderDate,
                                  );
                                }
                              }
                            }
                            final sortedReorderItems = reorderItems.values.toList()
                              ..sort((a, b) => b.lastOrderedDate.compareTo(a.lastOrderedDate));
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
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding
                                      child: _buildSearchBar(),
                                    ),
                                  ),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
          drawer: _buildDrawer(),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // const PersistentCartWidget(),
              BottomNavigationWidget(
                currentIndex: _currentNavIndex,
                onTap: (index) {
                  setState(() {
                    _currentNavIndex = index;
                  });
                  switch (index) {
                    case 0:
                      context.go('/home');
                      break;
                    case 1:
                      context.go('/category');
                      break;
                    case 2:
                      context.go('/cart');
                      break;
                    case 3:
                      break;
                    case 4:
                      context.go('/account');
                      break;
                  }
                },
              ),
            ],
          ),
        ),
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
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    ref.read(loggerProvider).log('AppBar back button pressed - navigating to home');
                    context.go('/home');
                  },
                ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildActionButtons(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            color: Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search for previously ordered items',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                border: InputBorder.none, // Ensure no additional borders
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 14,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _handleSearch,
            ),
          ),
          if (_isSearchActive)
            GestureDetector(
              onTap: _clearSearch,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.close,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
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
                const BrandLogo(height: 40, fallbackColor: Colors.white),
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
            onPressed: _clearSearch,
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



class _ReorderProductItemWidget extends ConsumerStatefulWidget {
  final ReorderItem reorderItem;

  const _ReorderProductItemWidget({
    required this.reorderItem,
  });

  @override
  ConsumerState<_ReorderProductItemWidget> createState() =>
      _ReorderProductItemWidgetState();
}

class _ReorderProductItemWidgetState extends ConsumerState<_ReorderProductItemWidget> {
  void _addToCart() {
    ref.read(cartProvider.notifier).addItem(widget.reorderItem.product);
  }

  void _incrementQuantity() {
    final cartItems = ref.read(cartProvider);
    final cartItem =
        cartItems.where((item) => item.product.pCode == widget.reorderItem.product.pCode).toList();
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
    final pCode = widget.reorderItem.product.pCode;
    final selectedOutlet = ref.read(selectedOutletProvider).value;
    final storeCode = selectedOutlet?.storeCode ?? widget.reorderItem.product.storeCode;
    context.push('/product/$pCode?storeCode=$storeCode');
  }

  void _handleManualQuantityInput(int newQuantity) {
    final logger = ref.read(loggerProvider);

    if (newQuantity <= 0) {
      logger.log('Quantity is 0 or less, removing item from cart');
      ref.read(cartProvider.notifier).removeItem(widget.reorderItem.product);
      return;
    }

    if (newQuantity > widget.reorderItem.product.maxQuantityAllowed) {
      logger.log(
          'Quantity $newQuantity exceeds max allowed ${widget.reorderItem.product.maxQuantityAllowed}');
      ref.read(cartProvider.notifier)
          .addItemWithQuantity(widget.reorderItem.product, widget.reorderItem.product.maxQuantityAllowed);
      _showMaxQuantityMessage();
      return;
    }

    logger.log('Updating quantity for ${widget.reorderItem.product.productName} to $newQuantity');
    ref.read(cartProvider.notifier).addItemWithQuantity(widget.reorderItem.product, newQuantity);
  }

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
    final cartItems = ref.watch(cartProvider);
    final cartItem =
        cartItems.where((item) => item.product.pCode == widget.reorderItem.product.pCode).toList();
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;
    final pricePerUnit = widget.reorderItem.product.packageSize > 0
        ? (widget.reorderItem.product.ourPrice / widget.reorderItem.product.packageSize)
        : 0.0;
    final discount = widget.reorderItem.product.productMrp - widget.reorderItem.product.ourPrice;
    final discountPercent = widget.reorderItem.product.productMrp > 0
        ? ((discount / widget.reorderItem.product.productMrp) * 100).round()
        : 0;
    final lastOrderedDateStr = DateFormat('dd/MM/yyyy').format(widget.reorderItem.lastOrderedDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section with navigation only on image tap
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4 - 16,
            child: Stack(
              children: [
                InkWell(
                  onTap: _navigateToProductDetail, // Only image is clickable for navigation
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.network(
                      widget.reorderItem.product.pcodeImg.isNotEmpty
                          ? widget.reorderItem.product.pcodeImg
                          : ApiConstants.fallbackImageUrl,
                      width: double.infinity,
                      height: 110,
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
                if (discountPercent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Product details section - NO navigation on tap
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name - NO navigation wrapper
                  Text(
                    widget.reorderItem.product.productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${widget.reorderItem.product.packageSize} ${widget.reorderItem.product.packageUnit.toLowerCase()} (₹${pricePerUnit.toStringAsFixed(2)}/GM)",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last ordered on $lastOrderedDateStr",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        "₹${widget.reorderItem.product.ourPrice.toStringAsFixed(widget.reorderItem.product.ourPrice.truncateToDouble() == widget.reorderItem.product.ourPrice ? 0 : 2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "MRP₹${widget.reorderItem.product.productMrp.toStringAsFixed(widget.reorderItem.product.productMrp.truncateToDouble() == widget.reorderItem.product.productMrp ? 0 : 2)}",
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: FavoriteButton(
                            product: widget.reorderItem.product,
                            size: 20,
                            showSnackbarMessages: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isInCart
                            ? _buildManualQuantitySelector(quantity, isCartEnabled)
                            : _buildConditionalAddToCartButton(isCartEnabled),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualQuantitySelector(int quantity, bool isCartEnabled) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Material(
            color: isCartEnabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
            child: InkWell(
              onTap: isCartEnabled
                  ? () {
                      if (quantity > 1) {
                        _decrementQuantity();
                      } else {
                        ref.read(cartProvider.notifier).removeItem(widget.reorderItem.product);
                      }
                    }
                  : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: isCartEnabled ? Colors.white : Colors.grey.shade600,
                  size: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 32,
              color: isCartEnabled ? Colors.white : Colors.grey.shade100,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: widget.reorderItem.product.maxQuantityAllowed,
                enabled: isCartEnabled,
                onQuantityChanged: _handleManualQuantityInput,
              ),
            ),
          ),
          Material(
            color: isCartEnabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            child: InkWell(
              onTap: isCartEnabled ? _incrementQuantity : null,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: isCartEnabled ? Colors.white : Colors.grey.shade600,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionalAddToCartButton(bool isCartEnabled) {
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);

    return outletStatusAsync.when(
      data: (status) {
        if (status == null) {
          return _buildAddToCartButton(isEnabled: true);
        }
        if (!isCartEnabled) {
          return _buildDisabledAddToCartButton(status.statusMessage);
        }
        return _buildAddToCartButton(isEnabled: true);
      },
      loading: () => _buildLoadingAddToCartButton(),
      error: (error, stackTrace) => _buildAddToCartButton(isEnabled: true),
    );
  }

  Widget _buildAddToCartButton({required bool isEnabled}) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _addToCart : null,
        icon: Icon(
          Icons.add_shopping_cart,
          color: isEnabled ? Colors.white : Colors.grey.shade600,
          size: 12,
        ),
        label: Text(
          "REORDER",
          style: TextStyle(
            color: isEnabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.primary : Colors.grey.shade300,
          minimumSize: const Size(double.infinity, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: isEnabled ? 2 : 0,
        ),
      ),
    );
  }

  Widget _buildDisabledAddToCartButton(String reason) {
    return Column(
      children: [
        SizedBox(
          height: 32,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: Icon(
              Icons.block,
              color: Colors.grey.shade600,
              size: 12,
            ),
            label: Text(
              "UNAVAILABLE",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              minimumSize: const Size(double.infinity, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingAddToCartButton() {
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          minimumSize: const Size(double.infinity, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
        ),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade500),
          ),
        ),
      ),
    );
  }
}
