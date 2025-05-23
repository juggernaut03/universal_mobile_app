// lib/presentation/features/product/widgets/suggested_product_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';

class SuggestedProductCard extends ConsumerWidget {
  final ProductModel product;
  final VoidCallback onTap;

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

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image with discount badge
              Stack(
                children: [
                  // Product image container
                  Container(
                    height: cardWidth * 0.85,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
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
                      child: Image.network(
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
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[100],
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
                        ),
                      ),
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
              
              // Product info section
              Expanded(
                child: Padding(
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
                            '₹${product.ourPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 6),
                            Text(
                              '₹${product.productMrp.toStringAsFixed(0)}',
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
                      
                      // Add to cart button or quantity selector
                      isInCart
                          ? _buildQuantitySelector(context, ref, product, quantity)
                          : _buildAddToCartButton(ref, product),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Manual quantity selector with text input capability
  Widget _buildQuantitySelector(BuildContext context, WidgetRef ref, ProductModel product, int quantity) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Decrement button
          GestureDetector(
            onTap: () {
              if (quantity > 1) {
                ref.read(cartProvider.notifier).decrementQuantity(product);
              } else {
                // Remove item if quantity becomes 0
                ref.read(cartProvider.notifier).removeItem(product);
              }
            },
            child: Container(
              width: 26,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
              child: const Icon(
                Icons.remove,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          
          // Manual quantity input field
          Expanded(
            child: Container(
              height: 32,
              alignment: Alignment.center,
              color: Colors.white,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: product.maxQuantityAllowed,
                onQuantityChanged: (newQuantity) {
                  _handleManualQuantityInput(context, ref, product, newQuantity);
                },
              ),
            ),
          ),
          
          // Increment button
          GestureDetector(
            onTap: () {
              if (quantity < product.maxQuantityAllowed) {
                ref.read(cartProvider.notifier).incrementQuantity(product);
              } else {
                _showMaxQuantityMessage(context, product);
              }
            },
            child: Container(
              width: 26,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple add to cart button
  Widget _buildAddToCartButton(WidgetRef ref, ProductModel product) {
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => ref.read(cartProvider.notifier).addItem(product),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: const Text(
          "ADD",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
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
        fontSize: 12,
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