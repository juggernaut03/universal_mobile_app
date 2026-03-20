// lib/presentation/features/product/widgets/suggested_product_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/outlet_status_provider.dart'; // Import for outlet status

class SuggestedProductCard extends ConsumerWidget {
  final ProductModel product;
  final VoidCallback onTap; 

  // Fallback image URL
  static const String fallbackImageUrl = 'https://patelrmart.com/mgmt_panel/product_images/patel_webp/default_img.webp';

  const SuggestedProductCard({
    Key? key,
    required this.product,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get screen dimensions to make card responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.42; // Increased to 42% for better proportions
    
    // Calculate discount
    final discount = product.productMrp - product.ourPrice;
    final hasDiscount = discount > 0;
    final discountPercent = product.productMrp > 0 
        ? ((discount / product.productMrp) * 100).round() 
        : 0;

    // Get cart information
    final cartItems = ref.watch(cartProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == product.pCode).toList();
    
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;

    // Check if cart is enabled from outlet status
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Card(
        color: Colors.white, // Added white background color for card
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with discount badge - ONLY THIS PART IS TAPPABLE
            InkWell(
              onTap: onTap, // Navigation only happens when tapping the image
              child: Stack(
                children: [
                  // Product image container
                  Container(
                    height: cardWidth * 0.85,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white, // Changed to white
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: _buildProductImage(),
                    ),
                  ),
                  
                  // Discount badge
                  if (hasDiscount && discountPercent > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.redAccent],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${discountPercent}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Product info section (not tappable)
            Expanded(
              child: Container(
                color: Colors.white, // Added white background for product info section
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      product.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Weight/Package size
                    Text(
                      '${product.packageSize} ${product.packageUnit}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Prices row
                    Row(
                      children: [
                        Text(
                          '₹${product.ourPrice.toStringAsFixed(product.ourPrice.truncateToDouble() == product.ourPrice ? 0 : 2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.productMrp.toStringAsFixed(product.productMrp.truncateToDouble() == product.productMrp ? 0 : 2)}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey[500],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const Spacer(),

                    // IPO badge + Add to cart button row
                    Row(
                      children: [
                        if (product.ipoImg.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Image.network(
                              product.ipoImg,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        Expanded(
                          child: outletStatusAsync.when(
                      data: (status) {
                        // If outlet status is unknown, show normal buttons (fail-safe)
                        if (status == null) {
                          return isInCart
                              ? _buildQuantitySelector(context, ref, product, quantity, true)
                              : _buildAddToCartButton(ref, product, true);
                        }
                        
                        // If cart is disabled due to outlet status, show disabled state
                        if (!isCartEnabled) {
                          return _buildUnavailabilityMessage(status);
                        }
                        
                        // Normal add to cart button or quantity selector
                        return isInCart
                            ? _buildQuantitySelector(context, ref, product, quantity, true)
                            : _buildAddToCartButton(ref, product, true);
                      },
                      loading: () => isInCart
                          ? _buildQuantitySelector(context, ref, product, quantity, true)
                          : _buildAddToCartButton(ref, product, true),
                      error: (error, stackTrace) => isInCart
                          ? _buildQuantitySelector(context, ref, product, quantity, true)
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
      ),
    );
  }

  // Build product image with fallback support
  Widget _buildProductImage() {
    return Image.network(
      product.pcodeImg,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // If primary image fails, try the fallback image
        return Image.network(
          fallbackImageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, fallbackError, fallbackStackTrace) {
            // If both primary and fallback images fail, show placeholder
            return Container(
              color: Colors.white, // Changed to white
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.grey[400],
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Product image',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        color: Colors.white, // Changed to white
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

  // Manual quantity selector - FIXED to match single product screen (NO outer container border)
  Widget _buildQuantitySelector(BuildContext context, WidgetRef ref, ProductModel product, int quantity, bool enabled) {
    return SizedBox(
      height: 32,
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
                width: 26,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                  size: 14,
                ),
              ),
            ),
          ),
          
          // Manual quantity input field with improved centering
          Expanded(
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? Colors.white : Colors.white, // Changed to white
                border: Border.symmetric(
                  horizontal: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: product.maxQuantityAllowed,
                onQuantityChanged: (newQuantity) {
                  _handleManualQuantityInput(context, ref, product, newQuantity);
                },
                enabled: enabled,
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
                width: 26,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple add to cart button - matching best_seller_screen style
  Widget _buildAddToCartButton(WidgetRef ref, ProductModel product, bool enabled) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => ref.read(cartProvider.notifier).addItem(product) : null,
        icon: Icon(
          Icons.shopping_cart_outlined,
          color: enabled ? Colors.white : Colors.grey.shade600,
          size: 12,
        ),
        label: Text(
          "ADD",
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.primary : Colors.grey.shade300,
          minimumSize: const Size(double.infinity, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Changed from rounded to 4
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: enabled ? 2 : 0, // Changed from 1 to 2
        ),
      ),
    );
  }
  
  // Handle manual quantity input
  void _handleManualQuantityInput(BuildContext context, WidgetRef ref, ProductModel product, int newQuantity) {
    if (newQuantity <= 0) {
      ref.read(cartProvider.notifier).removeItem(product);
      return;
    }
    
    // Check against maximum allowed quantity
    if (newQuantity > product.maxQuantityAllowed) {
      // Set to maximum allowed quantity
      ref.read(cartProvider.notifier).addItemWithQuantity(product, product.maxQuantityAllowed);
      _showMaxQuantityMessage(context, product);
      return;
    }
    
    // Update cart with new quantity
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
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// Custom manual quantity input widget - FIXED to match best_seller_screen
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
      color: Colors.white, // Added white background for input container
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
            fontSize: 12,
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