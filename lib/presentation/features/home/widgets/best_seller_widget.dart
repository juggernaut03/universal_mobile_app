// lib/presentation/features/home/widgets/best_seller_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/product_model.dart';
import '../../../../core/widgets/error_widgets.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../providers/cart_provider.dart';

class BestSellerWidget extends ConsumerWidget {
  final int bestSellerId;
  final String title;
  final double height;
  final EdgeInsetsGeometry padding;
  final bool showViewAll;
  final VoidCallback? onViewAllTap;

  const BestSellerWidget({
    Key? key,
    required this.bestSellerId,
    required this.title,
    this.height = 320,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.showViewAll = true,
    this.onViewAllTap,
  }) : super(key: key);

  // Helper method to convert hex color string to Color
  Color _hexToColor(String hexString, {Color defaultColor = Colors.white}) {
    try {
      // Remove '#' if present
      String hex = hexString.replaceAll('#', '');
      
      // Handle different formats: RGB, RRGGBB, AARRGGBB
      if (hex.length == 3) {
        // RGB format, convert to RRGGBB
        hex = hex.split('').map((c) => '$c$c').join('');
      }
      
      // Add FF for alpha if only RGB or RRGGBB is provided
      if (hex.length == 6) {
        hex = 'FF$hex';
      } else if (hex.length != 8) {
        // If not a valid length, return default color
        return defaultColor;
      }
      
      // Parse the hex string to integer
      return Color(int.parse('0x$hex'));
    } catch (e) {
      // Return default color if any error occurs
      return defaultColor;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the banner/slider data for this best seller section
    final bannerAsync = ref.watch(bestSellerBannerProvider(bestSellerId));
    
    // Get the product data for this best seller section
    final productsAsync = ref.watch(bestSellerProductsProvider(bestSellerId));

    return bannerAsync.when(
      data: (banners) {
        // Use the background color from the first banner (if available)
        Color backgroundColor = Colors.white;
        if (banners.isNotEmpty && banners[0].backgroundColor.isNotEmpty) {
          backgroundColor = _hexToColor(banners[0].backgroundColor, defaultColor: Colors.white);
          ref.read(loggerProvider).log('Using background color: ${backgroundColor.toString()} from ${banners[0].backgroundColor}');
        }

        return Container(
          color: backgroundColor, // Apply background color to entire widget
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header with title and view all button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (showViewAll)
                      GestureDetector(
                        onTap: onViewAllTap ?? () {
                          // Default action if none provided
                          // For example, navigate to a category with these products
                          context.push('/category');
                        },
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Banner/Slider Section
              if (banners.isEmpty)
                const SizedBox.shrink() // No banner to show
              else
                CarouselSlider(
                  options: CarouselOptions(
                    height: MediaQuery.of(context).size.width * (200 / 800), // Maintain 800:200 aspect ratio
                    viewportFraction: 1.0, // Use full width
                    autoPlay: true,
                    enlargeCenterPage: false, // No enlargement to use full width
                    autoPlayInterval: const Duration(seconds: 5),
                    padEnds: false, // No padding at the ends
                  ),
                  items: banners.map((banner) {
                    return Builder(
                      builder: (BuildContext context) {
                        return GestureDetector(
                          onTap: () {
                            // Handle banner tap - e.g., navigate to a specific page
                            if (banner.actionUrl.isNotEmpty) {
                              // Handle navigation based on action URL
                            }
                          },
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            padding: EdgeInsets.zero, // No padding
                            margin: EdgeInsets.zero, // No margin
                            child: CachedNetworkImageWidget(
                              imageUrl: banner.imageUrl,
                              fit: BoxFit.cover,
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.width * (200 / 800), // Maintain 800:200 aspect ratio
                              errorWidget: Container(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.width * (200 / 800),
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey[400],
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Banner image not available',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 16),
              
              // Products Section
              productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return EmptyStateWidget(
                      title: 'No products available',
                      subtitle: 'Check back soon for new products',
                      icon: Icons.shopping_bag_outlined,
                    );
                  }

                  // Log product image URLs for debugging
                  for (var product in products.take(3)) { // Log only first 3 to avoid spamming
                    ref.read(loggerProvider).log('Product image URL: ${product.productName} -> ${product.pcodeImg}');
                  }

                  return Container(
                    height: height,
                    padding: padding,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _buildProductCard(context, ref, product);
                      },
                    ),
                  );
                },
                loading: () => SizedBox(
                  height: height,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: AppErrorWidget(
                    errorType: ErrorType.generic,
                    message: 'Error loading products: $error',
                    onRetry: () => ref.refresh(bestSellerProductsProvider(bestSellerId)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        color: Colors.white,
        child: Column(
          children: [
            // Title placeholder while loading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Loading indicator for banner
            Container(
              color: Colors.white,
              height: MediaQuery.of(context).size.width * (200 / 800),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => Container(
        color: Colors.white,
        child: Column(
          children: [
            // Title even when there's an error
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Error state for banner
            Container(
              color: Colors.white,
              height: MediaQuery.of(context).size.width * (200 / 800),
              child: Center(
                child: Text('Error loading banner: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    
    return GestureDetector(
      onTap: () {
        // Navigate to product detail page
        context.push('/product/${product.pCode}');
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with discount badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: CachedNetworkImageWidget(
                    imageUrl: product.pcodeImg,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorWidget: Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.grey[400],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Product image',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (discountPercent > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        "${discountPercent}% OFF",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Product details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    product.productName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Package size
                  Text(
                    "${product.packageSize} ${product.packageUnit}",
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Price section
                  Row(
                    children: [
                      Text(
                        "₹${product.ourPrice.toStringAsFixed(0)}",
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (product.productMrp > product.ourPrice)
                        Text(
                          "₹${product.productMrp.toStringAsFixed(0)}",
                          style: AppTextStyles.bodySmall.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Add to cart button or quantity selector
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: isInCart
                  ? Container(
                      height: 36,
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
                              width: 36,
                              height: 36,
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
                                size: 16,
                              ),
                            ),
                          ),
                          
                          // Quantity
                          Expanded(
                            child: Container(
                              height: 36,
                              alignment: Alignment.center,
                              color: Colors.white,
                              child: Text(
                                quantity.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          // Increment button
                          GestureDetector(
                            onTap: () => ref.read(cartProvider.notifier).incrementQuantity(product),
                            child: Container(
                              width: 36,
                              height: 36,
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
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => ref.read(cartProvider.notifier).addItem(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text("ADD"),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}