// lib/presentation/features/subcategory/widgets/product_item_widget.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/product_model.dart';

class ProductItemWidget extends StatefulWidget {
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
  State<ProductItemWidget> createState() => _ProductItemWidgetState();
}

class _ProductItemWidgetState extends State<ProductItemWidget> {
  bool _isInCart = false;
  int _quantity = 1;

  void _addToCart() {
    widget.onAddToCart();
    setState(() {
      _isInCart = true;
    });
  }

  void _incrementQuantity() {
    setState(() {
      if (_quantity < widget.product.maxQuantityAllowed) {
        _quantity++;
      }
    });
    // Here you would call a function to update cart quantity
  }

  void _decrementQuantity() {
    setState(() {
      if (_quantity > 1) {
        _quantity--;
      } else {
        _isInCart = false;
      }
    });
    // Here you would call a function to update cart quantity
  }

void _navigateToProductDetail() {
  // Ensure p_code is properly formatted
  final pCode = widget.product.pCode;
  final storeCode = widget.product.storeCode;
  
  print('Navigating to product: p_code=$pCode, store_code=$storeCode'); // Add logging
  
  // Use the go_router path parameters format correctly
  context.push('/product/$pCode?storeCode=$storeCode');
}

  @override
  Widget build(BuildContext context) {
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
                        "${discountPercent.toStringAsFixed(1)}% OFF",
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
                        IconButton(
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Colors.grey,
                            size: 24,
                          ),
                          onPressed: widget.onToggleFavorite,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Add to cart button or quantity selector
                        Expanded(
                          child: _isInCart
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
                                        onTap: _decrementQuantity,
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
                                            _quantity.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
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
                                )
                              : SizedBox(
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
}