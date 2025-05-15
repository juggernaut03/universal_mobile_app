import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_constants.dart';
import 'package:patelmart/core/widgets/empty_state_widget.dart';
import 'package:patelmart/core/widgets/error_widgets.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';

class BestSellerScreen extends ConsumerWidget {
  final int bestSellerId;
  
  const BestSellerScreen({
    Key? key, 
    required this.bestSellerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the title based on bestSellerId
    String screenTitle = _getBestSellerTitle(bestSellerId);
    
    // Fetch products for this best seller
    final productsAsync = ref.watch(bestSellerProductsProvider(bestSellerId));
    
    // Get the background color too - for consistency in the UI
    final backgroundColor = ref.watch(bestSellerBackgroundColorProvider(bestSellerId));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
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
              await ref.refresh(bestSellerBannerProvider(bestSellerId).future);
              await ref.refresh(bestSellerProductsProvider(bestSellerId).future);
            },
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const EmptyStateWidget(
              title: 'No products found',
              subtitle: 'We couldn\'t find any products in this collection',
              icon: Icons.shopping_bag_outlined,
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(context, ref, products[index]);
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
              onRetry: () => ref.refresh(bestSellerProductsProvider(bestSellerId)),
            ),
          );
        },
      ),
    );
  }
  
  // Helper to get the title based on bestSellerId
  String _getBestSellerTitle(int id) {
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
  
  // Build a product card matching the ProductItemWidget horizontal layout
  Widget _buildProductCard(BuildContext context, WidgetRef ref, ProductModel product) {
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
    
    return GestureDetector(
      onTap: () => _navigateToProductDetail(context, ref, product),
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
                    onTap: () => _navigateToProductDetail(context, ref, product),
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
                    // Product name - also tappable to see product details
                    InkWell(
                      onTap: () => _navigateToProductDetail(context, ref, product),
                      child: Text(
                        product.productName,
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
                          "₹${product.ourPrice.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        Text(
                          "MRP₹${product.productMrp.toStringAsFixed(0)}",
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
                          onPressed: () {}, // Add wishlist functionality later
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Add to cart button or quantity selector
                        Expanded(
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
                                        onTap: () => ref.read(cartProvider.notifier).decrementQuantity(product),
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
                                        onTap: () => ref.read(cartProvider.notifier).incrementQuantity(product),
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
                                    onPressed: () => ref.read(cartProvider.notifier).addItem(product),
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