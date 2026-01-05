import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_constants.dart';
import 'package:patelmart/core/widgets/empty_state_widget.dart';
import 'package:patelmart/core/widgets/error_widgets.dart';
import 'package:patelmart/core/widgets/favorite_button.dart';
import 'package:patelmart/core/widgets/bottom_navigation_widget.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/outlet_status_provider.dart';
import '../cart/widgets/persistent_cart_widget.dart';

class BestSellerScreen extends ConsumerStatefulWidget {
  final int bestSellerId;
  
  const BestSellerScreen({
    Key? key, 
    required this.bestSellerId,
  }) : super(key: key);

  @override
  ConsumerState<BestSellerScreen> createState() => _BestSellerScreenState();
}

class _BestSellerScreenState extends ConsumerState<BestSellerScreen> {
  int _currentNavIndex = 0; // Add navigation state management

  @override
  Widget build(BuildContext context) {
    // Get the dynamic title from API instead of hardcoded values
    final titleAsync = ref.watch(bestSellerTitleProvider(widget.bestSellerId));
    
    // Fetch products for this best seller
    final productsAsync = ref.watch(bestSellerProductsProvider(widget.bestSellerId));
    
    // Get the background color too - for consistency in the UI
    final backgroundColor = ref.watch(bestSellerBackgroundColorProvider(widget.bestSellerId));
    
    return Scaffold(
      appBar: AppBar(
        // Use dynamic title from API, with fallback to default
        title: titleAsync.when(
          data: (title) => Text(title),
          loading: () => Text(_getFallbackTitle(widget.bestSellerId)), // Show fallback while loading
          error: (_, __) => Text(_getFallbackTitle(widget.bestSellerId)), // Show fallback on error
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Force refresh the best seller data
              ref.read(refreshBestSellerProvider.notifier).state = true;
              await ref.refresh(bestSellerBannerProvider(widget.bestSellerId).future);
              await ref.refresh(bestSellerProductsProvider(widget.bestSellerId).future);
              await ref.refresh(bestSellerTitleProvider(widget.bestSellerId).future); // Also refresh title
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content with bottom padding for persistent cart
          Positioned.fill(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const EmptyStateWidget(
                    title: 'No products found',
                    subtitle: 'We couldn\'t find any products in this collection',
                    icon: Icons.shopping_bag_outlined,
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 12,
                    bottom: 140, // Increased padding for persistent cart + bottom nav
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _BestSellerProductCard(
                      product: products[index],
                      onNavigateToDetail: () => _navigateToProductDetail(context, ref, products[index]),
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
              error: (error, stackTrace) {
                ref.read(loggerProvider).error('Error loading best seller products: $error');
                return Center(
                  child: AppErrorWidget(
                    errorType: ErrorType.generic,
                    message: 'Error loading products: $error',
                    onRetry: () => ref.refresh(bestSellerProductsProvider(widget.bestSellerId)),
                  ),
                );
              },
            ),
          ),
          
          // Persistent cart widget at the bottom
          Positioned(
            left: 0, 
            right: 0,
            bottom: 0, // Positioned above the bottom navigation
            child: const PersistentCartWidget(),
          ),
        ],
      ),
      // Add bottom navigation bar
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
  
  // Add bottom navigation builder method
  Widget _buildBottomNavigation() {
    return BottomNavigationWidget(
      currentIndex: _currentNavIndex,
      onTap: (index) {
        if (mounted) {
          setState(() {
            _currentNavIndex = index;
          });
          
          switch (index) {
            case 0: // Home
              context.go('/'); // Navigate to home
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
    );
  }
  
  // Fallback title method (used while loading or on error)
  String _getFallbackTitle(int id) {
    switch (id) {
      case 1:
        return 'Best Deals';
      case 2:
        return 'Best Offers';
      case 3:
        return 'Chai Time';
      case 4:
        return 'Top Picks For You';
      default:
        return 'Featured Products';
    }
  }
  
  // Helper method to navigate to product detail
  void _navigateToProductDetail(BuildContext context, WidgetRef ref, ProductModel product) {
    // Ensure p_code is properly formatted
    final pCode = product.pCode;
    
    // Get storeCode from the selected outlet instead of using static value
    final selectedOutlet = ref.read(selectedOutletProvider).value;
    final storeCode = selectedOutlet?.storeCode ?? product.storeCode;
    
    // Use the go_router path parameters format correctly
    context.push('/product/$pCode?storeCode=$storeCode');
  }
}

// Separate widget for product card to manage state properly
class _BestSellerProductCard extends ConsumerWidget {
  final ProductModel product;
  final VoidCallback onNavigateToDetail;

  const _BestSellerProductCard({
    required this.product,
    required this.onNavigateToDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calculate discount percentage
    final discount = product.productMrp - product.ourPrice;
    final discountPercent = product.productMrp > 0 
        ? ((discount / product.productMrp) * 100).round() 
        : 0;
    
    // Get cart information
    final cartItems = ref.watch(cartProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == product.pCode).toList();
    
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;
    
    // Price per unit calculation
    final pricePerUnit = product.packageSize > 0 
        ? (product.ourPrice / product.packageSize) 
        : 0.0;
    
    // Check if cart is enabled
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Image with discount badge (40% width)
          // ONLY THIS PART IS TAPPABLE FOR NAVIGATION
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4 - 16, // Adjusting for margins
            child: Stack(
              children: [
                // Product image with caching - ONLY this is tappable
                InkWell(
                  onTap: onNavigateToDetail, // Navigate to detail ONLY when clicking image
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.network(
                      product.pcodeImg.isNotEmpty 
                          ? product.pcodeImg 
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
          
          // Right side: Product details (60% width)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name - NOT tappable to see product details
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Package size and price per unit
                  Text(
                    "${product.packageSize} ${product.packageUnit.toLowerCase()} (₹${pricePerUnit.toStringAsFixed(2)}/GM)",
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
                        "₹${product.ourPrice.toStringAsFixed(product.ourPrice.truncateToDouble() == product.ourPrice ? 0 : 2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      Text(
                        "MRP₹${product.productMrp.toStringAsFixed(product.productMrp.truncateToDouble() == product.productMrp ? 0 : 2)}",
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Bottom row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Favorite button using FavoriteButton widget
                      FavoriteButton(
                        product: product,
                        size: 24,
                        activeColor: Colors.red,
                        inactiveColor: Colors.grey,
                        showSnackbarMessages: true,
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Add to cart button or manual quantity selector with conditional rendering
                      Expanded(
                        child: outletStatusAsync.when(
                          data: (status) {
                            // If outlet status is unknown, show normal buttons (fail-safe)
                            if (status == null) {
                              return isInCart
                                  ? _buildManualQuantitySelector(context, ref, product, quantity, true)
                                  : _buildAddToCartButton(ref, product, true);
                            }
                            
                            // If cart is disabled due to outlet status, show disabled state
                            if (!isCartEnabled) {
                              return _buildUnavailabilityMessage(status);
                            }
                            
                            // Normal add to cart button or quantity selector
                            return isInCart
                                ? _buildManualQuantitySelector(context, ref, product, quantity, true)
                                : _buildAddToCartButton(ref, product, true);
                          },
                          loading: () => isInCart
                              ? _buildManualQuantitySelector(context, ref, product, quantity, true)
                              : _buildAddToCartButton(ref, product, true),
                          error: (error, stackTrace) => isInCart
                              ? _buildManualQuantitySelector(context, ref, product, quantity, true)
                              : _buildAddToCartButton(ref, product, true),
                        ),
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

  // Build unavailability message widget
  Widget _buildUnavailabilityMessage(dynamic status) {
    String message;
    Color textColor;
    
    // Determine message and styling based on outlet status
    if (!status.isEnabled) {
      message = "UNAVAILABLE";
      textColor = AppColors.error;
    } else if (!status.hasAnyServiceAvailable) {
      message = "UNAVAILABLE";
      textColor = AppColors.warning;
    } else if (status.hasDeliveryOnly) {
      message = "DELIVERY ONLY";
      textColor = AppColors.info;
    } else if (status.hasPickupOnly) {
      message = "PICKUP ONLY";
      textColor = AppColors.info;
    } else {
      // This shouldn't happen if cart is disabled, but just in case
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      height: 40, // Match the height of the normal add button
      width: double.infinity,
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // Manual quantity selector with improved styling
  Widget _buildManualQuantitySelector(BuildContext context, WidgetRef ref, ProductModel product, int quantity, bool enabled) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Decrement button
          Material(
            color: enabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
            child: InkWell(
              onTap: enabled ? () {
                if (quantity > 1) {
                  ref.read(cartProvider.notifier).decrementQuantity(product);
                } else {
                  // Remove item if quantity becomes 0
                  ref.read(cartProvider.notifier).removeItem(product);
                }
              } : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
          
          // Manual quantity input field with improved centering
          Expanded(
            child: Container(
              height: 40,
              color: enabled ? Colors.white : Colors.grey.shade100,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: product.maxQuantityAllowed,
                enabled: enabled,
                onQuantityChanged: (newQuantity) {
                  _handleManualQuantityInput(context, ref, product, newQuantity);
                },
              ),
            ),
          ),
          
          // Increment button
          Material(
            color: enabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            child: InkWell(
              onTap: enabled ? () {
                if (quantity < product.maxQuantityAllowed) {
                  ref.read(cartProvider.notifier).incrementQuantity(product);
                } else {
                  _showMaxQuantityMessage(context, product);
                }
              } : null,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple add to cart button
  Widget _buildAddToCartButton(WidgetRef ref, ProductModel product, bool enabled) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => ref.read(cartProvider.notifier).addItem(product) : null,
        icon: Icon(
          Icons.shopping_cart_outlined,
          color: enabled ? Colors.white : Colors.grey.shade600,
          size: 18,
        ),
        label: Text(
          "ADD",
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.primary : Colors.grey.shade300,
          minimumSize: const Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: enabled ? 2 : 0,
        ),
      ),
    );
  }

  // Handle manual quantity input
  void _handleManualQuantityInput(BuildContext context, WidgetRef ref, ProductModel product, int newQuantity) {
    final logger = ref.read(loggerProvider);
    
    if (newQuantity <= 0) {
      logger.log('Quantity is 0 or less, removing item from cart');
      ref.read(cartProvider.notifier).removeItem(product);
      return;
    }
    
    // Check against maximum allowed quantity
    if (newQuantity > product.maxQuantityAllowed) {
      logger.log('Quantity $newQuantity exceeds max allowed ${product.maxQuantityAllowed}');
      // Set to maximum allowed quantity
      ref.read(cartProvider.notifier).addItemWithQuantity(product, product.maxQuantityAllowed);
      _showMaxQuantityMessage(context, product);
      return;
    }
    
    // Update cart with new quantity
    logger.log('Updating quantity for ${product.productName} to $newQuantity');
    ref.read(cartProvider.notifier).addItemWithQuantity(product, newQuantity);
  }

  // Show max quantity reached message
  void _showMaxQuantityMessage(BuildContext context, ProductModel product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${product.maxQuantityAllowed} items allowed'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Optimized manual quantity input widget to match best_seller_widget implementation
class _ManualQuantityInput extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final ValueChanged<int> onQuantityChanged;
  final bool enabled;

  const _ManualQuantityInput({
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
    this.enabled = true,
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
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: widget.maxQuantity.toString().length,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: widget.enabled ? Colors.black87 : Colors.grey.shade600,
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
          
          // Disable cursor and selection handles on mobile for better UX
          showCursor: false,
          enableInteractiveSelection: false,
          
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.maxQuantity.toString().length),
            _MaxQuantityInputFormatter(widget.maxQuantity),
          ],
          onSubmitted: (_) => _validateAndSubmit(),
          onTap: widget.enabled ? () {
            // Select all text when tapped for easy editing
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          } : null,
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