// lib/presentation/features/subcategory/widgets/product_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/widgets/favorite_button.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/outlet_provider.dart';
import '../../../../di/infrastructure_providers.dart';
import '../../../providers/outlet_status_provider.dart'; // Add this import for outlet status

class ProductItemWidget extends ConsumerStatefulWidget {
  final ProductModel product;
  final VoidCallback onAddToCart;
  final VoidCallback onToggleFavorite;

  const ProductItemWidget({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  @override
  ConsumerState<ProductItemWidget> createState() => _ProductItemWidgetState();
}

class _ProductItemWidgetState extends ConsumerState<ProductItemWidget> {
  void _addToCart() {
    ref.read(cartProvider.notifier).addItem(widget.product);
  }

  void _incrementQuantity() {
    final cartItems = ref.read(cartItemsProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == widget.product.pCode).toList();
    final currentQuantity = cartItem.isNotEmpty ? cartItem.first.quantity : 0;
    
    if (currentQuantity < widget.product.maxQuantityAllowed) {
      ref.read(cartProvider.notifier).incrementQuantity(widget.product);
    } else {
      _showMaxQuantityMessage();
    }
  }

  void _decrementQuantity() {
    ref.read(cartProvider.notifier).decrementQuantity(widget.product);
  }

  void _navigateToProductDetail() {
    // Ensure p_code is properly formatted
    final pCode = widget.product.pCode;
    
    // Get storeCode from the selected outlet instead of using static value
    final selectedOutlet = ref.read(selectedOutletProvider).value;
    final storeCode = selectedOutlet?.storeCode ?? widget.product.storeCode;
    
    // Use the go_router path parameters format correctly
    context.push('/product/$pCode?storeCode=$storeCode');
  }

  // Handle manual quantity input
  void _handleManualQuantityInput(int newQuantity) {
    final logger = ref.read(loggerProvider);
    
    if (newQuantity <= 0) {
      logger.log('Quantity is 0 or less, removing item from cart');
      ref.read(cartProvider.notifier).removeItem(widget.product);
      return;
    }
    
    // Check against maximum allowed quantity
    if (newQuantity > widget.product.maxQuantityAllowed) {
      logger.log('Quantity $newQuantity exceeds max allowed ${widget.product.maxQuantityAllowed}');
      // Set to maximum allowed quantity
      ref.read(cartProvider.notifier).addItemWithQuantity(widget.product, widget.product.maxQuantityAllowed);
      _showMaxQuantityMessage();
      return;
    }
    
    // Update cart with new quantity
    logger.log('Updating quantity for ${widget.product.productName} to $newQuantity');
    ref.read(cartProvider.notifier).addItemWithQuantity(widget.product, newQuantity);
  }

  // Show max quantity reached message
  void _showMaxQuantityMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${widget.product.maxQuantityAllowed} items allowed'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      height: 32, // Match the height of the normal add button
      width: double.infinity,
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get cart information from provider to check if this product is in cart
    final cartItems = ref.watch(cartItemsProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == widget.product.pCode).toList();
    
    // Determine if product is in cart and its quantity
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;
    
    // Calculate price per unit
    final pricePerUnit = widget.product.packageSize > 0 
        ? (widget.product.ourPrice / widget.product.packageSize) 
        : 0.0;
        
    // Calculate discount
    final discount = widget.product.productMrp - widget.product.ourPrice;
    final discountPercent = widget.product.productMrp > 0 
        ? ((discount / widget.product.productMrp) * 100).round() 
        : 0;

    // Check if cart is enabled from outlet status
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);

    return Container(
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
                // Product image with caching - ONLY this part is tappable
                InkWell(
                  onTap: _navigateToProductDetail,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0), // Reduced padding
                    child: Image.network(
                      widget.product.pcodeImg.isNotEmpty 
                          ? widget.product.pcodeImg 
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
                      errorBuilder: (context, error, stackTrace) {
                        // Tenant fallback (admin panel > Mobile App >
                        // Branding > App Logo) can itself be empty/unset.
                        if (ApiConstants.fallbackImageUrl.isEmpty) {
                          return Container(
                            width: double.infinity,
                            height: 110,
                            color: Colors.grey[100],
                            child: Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                          );
                        }
                        return Image.network(
                          ApiConstants.fallbackImageUrl,
                          width: double.infinity,
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: double.infinity,
                            height: 110,
                            color: Colors.grey[100],
                            child: Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                          ),
                        );
                      },
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
                // IPO badge
                if (widget.product.isIpoProduct && widget.product.ipoImg.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Image.network(
                      widget.product.ipoImg,
                      width: 65,
                      height: 65,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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
                  // Product name - reduced font size and spacing - NOT tappable
                  Text(
                    widget.product.productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4), // Reduced from 6
                  
                  // Package size and price per unit
                  Text(
                    "${widget.product.packageSize} ${widget.product.packageUnit.toLowerCase()} (₹${pricePerUnit.toStringAsFixed(2)}/GM)",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12, // Reduced from 14
                      height: 1.1, // Reduced line height
                    ),
                  ),
                  
                  const SizedBox(height: 6), // Reduced from 8
                  
                  // Price section
                  Row(
                    children: [
                      Text(
                        "₹${widget.product.ourPrice.toStringAsFixed(widget.product.ourPrice.truncateToDouble() == widget.product.ourPrice ? 0 : 2)}",
                        style: const TextStyle(
                          fontSize: 16, // Reduced from 18
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(width: 6), // Reduced from 8
                      
                      Text(
                        "MRP₹${widget.product.productMrp.toStringAsFixed(widget.product.productMrp.truncateToDouble() == widget.product.productMrp ? 0 : 2)}",
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
                            product: widget.product,
                            size: 20, // Increased size
                            showSnackbarMessages: false, // Disable to prevent overlap
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Add to cart button or manual quantity selector with conditional logic
                      Expanded(
                        child: outletStatusAsync.when(
                          data: (status) {
                            // If outlet status is unknown, show normal buttons (fail-safe)
                            if (status == null) {
                              return isInCart
                                  ? _buildManualQuantitySelector(quantity, true)
                                  : _buildAddToCartButton(true);
                            }
                            
                            // If cart is disabled due to outlet status, show disabled state
                            if (!isCartEnabled) {
                              return _buildUnavailabilityMessage(status);
                            }
                            
                            // Normal add to cart button or quantity selector
                            return isInCart
                                ? _buildManualQuantitySelector(quantity, true)
                                : _buildAddToCartButton(true);
                          },
                          loading: () => isInCart
                              ? _buildManualQuantitySelector(quantity, true)
                              : _buildAddToCartButton(true),
                          error: (error, stackTrace) => isInCart
                              ? _buildManualQuantitySelector(quantity, true)
                              : _buildAddToCartButton(true),
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

  // Manual quantity selector with improved styling
  Widget _buildManualQuantitySelector(int quantity, bool enabled) {
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
            color: enabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
            child: InkWell(
              onTap: enabled ? () {
                if (quantity > 1) {
                  _decrementQuantity();
                } else {
                  // Remove item if quantity becomes 0
                  ref.read(cartProvider.notifier).removeItem(widget.product);
                }
              } : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
              child: Container(
                width: 32, // Fixed width to match height
                height: 32, // Fixed height
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                  size: 16, // Smaller icon size for better appearance
                ),
              ),
            ),
          ),
          
          // Manual quantity input field
          Expanded(
            child: Container(
              height: 32,
              color: enabled ? Colors.white : Colors.grey.shade100,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: widget.product.maxQuantityAllowed,
                enabled: enabled,
                onQuantityChanged: _handleManualQuantityInput,
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
                if (quantity < widget.product.maxQuantityAllowed) {
                  _incrementQuantity();
                } else {
                  _showMaxQuantityMessage();
                }
              } : null,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Container(
                width: 32, // Fixed width to match height
                height: 32, // Fixed height
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: enabled ? Colors.white : Colors.grey.shade600,
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
  Widget _buildAddToCartButton(bool enabled) {
    return SizedBox(
      height: 32, // Reduced height to match favorite button
      child: ElevatedButton.icon(
        onPressed: enabled ? _addToCart : null,
        icon: Icon(
          Icons.shopping_cart_outlined,
          color: enabled ? Colors.white : Colors.grey.shade600,
          size: 12, // Reduced icon size
        ),
        label: Text(
          "ADD",
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 11, // Reduced font size
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.primary : Colors.grey.shade300,
          minimumSize: const Size(double.infinity, 32), // Reduced height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
          elevation: enabled ? 2 : 0,
        ),
      ),
    );
  }
}

// Manual quantity input widget
class _ManualQuantityInput extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final bool enabled;
  final ValueChanged<int> onQuantityChanged;

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
            fontSize: 14,
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
          
          // Disable cursor and selection handles on mobile
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