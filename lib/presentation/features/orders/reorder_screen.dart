// lib/presentation/features/orders/reorder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/features/orders/my_orders_screen.dart'; // Import the ordersProvider
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/bottom_navigation_widget.dart'; // Import the bottom navigation widget
import '../../providers/cart_provider.dart';
import '../../features/cart/widgets/persistent_cart_widget.dart'; // Import the persistent cart widget

class ReorderScreen extends ConsumerStatefulWidget {
  const ReorderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends ConsumerState<ReorderScreen> {
  // Current selected index for bottom navigation
  int _currentNavIndex = 3; // Set to 3 for "Reorder" tab

  @override
  Widget build(BuildContext context) {
    // Use the same ordersProvider from MyOrdersScreen
    final ordersAsync = ref.watch(ordersProvider);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Quick Reorder',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: ordersAsync.when(
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
          
          if (sortedReorderItems.isEmpty) {
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
          
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh the orders
              return ref.refresh(ordersProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              // Add padding at the bottom to account for the persistent cart widget
              itemCount: sortedReorderItems.length,
              itemBuilder: (context, index) {
                return _buildReorderProductItem(
                  context, ref, sortedReorderItems[index]
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
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
        ),
      ),
      
      // Add bottom navigation with persistent cart widget
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent cart widget
          const PersistentCartWidget(),
          
          // Bottom navigation
          BottomNavigationWidget(
            currentIndex: _currentNavIndex,
            onTap: (index) {
              setState(() {
                _currentNavIndex = index;
              });
              
              // Handle navigation based on index
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
                  // Already on this screen, so do nothing
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
              width: MediaQuery.of(context).size.width * 0.4 - 16, // Adjusting for margins
              child: Stack(
                children: [
                  // Product image with caching - also tappable
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