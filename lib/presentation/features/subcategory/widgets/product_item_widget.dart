// lib/presentation/features/subcategory/widgets/product_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/favorite_button.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/outlet_provider.dart';
import '../../../providers/launch_flow_provider.dart';

class ProductItemWidget extends ConsumerStatefulWidget {
  final ProductModel product;
  final VoidCallback onAddToCart;
  final VoidCallback onToggleFavorite;

  const ProductItemWidget({
    Key? key,
    required this.product,
    required this.onAddToCart,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  ConsumerState<ProductItemWidget> createState() => _ProductItemWidgetState();
}

class _ProductItemWidgetState extends ConsumerState<ProductItemWidget> {
  void _addToCart() {
    ref.read(cartProvider.notifier).addItem(widget.product);
  }

  void _incrementQuantity() {
    final cartItems = ref.read(cartProvider);
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

  @override
  Widget build(BuildContext context) {
    // Get cart information from provider to check if this product is in cart
    final cartItems = ref.watch(cartProvider);
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

    return GestureDetector(
      onTap: _navigateToProductDetail, // Navigate to product detail on tap
      child: Container(
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
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4 - 16, // Adjusting for margins
              child: Stack(
                children: [
                  // Product image with caching - also tappable
                  InkWell(
                    onTap: _navigateToProductDetail, // Navigate to product detail when image is tapped
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.network(
                        widget.product.pcodeImg.isNotEmpty 
                            ? widget.product.pcodeImg 
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
                    // Product name - also tappable to see product details
                    InkWell(
                      onTap: _navigateToProductDetail,
                      child: Text(
                        widget.product.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Package size and price per unit
                    Text(
                      "${widget.product.packageSize} ${widget.product.packageUnit.toLowerCase()} (₹${pricePerUnit.toStringAsFixed(2)}/GM)",
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
                          "₹${widget.product.ourPrice.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        Text(
                          "MRP₹${widget.product.productMrp.toStringAsFixed(0)}",
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
                        // Favorite button
                      FavoriteButton(
                      product: widget.product,
                      size: 24,
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

  // Manual quantity selector with text input capability
  Widget _buildManualQuantitySelector(int quantity) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Decrement button
          GestureDetector(
            onTap: () {
              if (quantity > 1) {
                _decrementQuantity();
              } else {
                // Remove item if quantity becomes 0
                ref.read(cartProvider.notifier).removeItem(widget.product);
              }
            },
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
          
          // Manual quantity input field
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.center,
              color: Colors.white,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: widget.product.maxQuantityAllowed,
                onQuantityChanged: _handleManualQuantityInput,
              ),
            ),
          ),
          
          // Increment button
          GestureDetector(
            onTap: _incrementQuantity,
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
    );
  }

  // Simple add to cart button
  Widget _buildAddToCartButton() {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: _addToCart,
        icon: const Icon(
          Icons.shopping_cart_outlined,
          color: Colors.white,
          size: 18,
        ),
        label: const Text(
          "ADD",
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
    );
  }
}

// Custom manual quantity input widget
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
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: widget.maxQuantity.toString().length,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        counterText: '', // Hide character counter
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
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