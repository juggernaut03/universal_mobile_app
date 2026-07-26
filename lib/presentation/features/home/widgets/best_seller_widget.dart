// lib/presentation/features/home/widgets/best_seller_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_constants.dart';
import 'package:patelmart/presentation/widgets/favorite_button.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
// Add this import for outlet status
import 'package:patelmart/presentation/providers/outlet_status_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/product_model.dart';
import '../../../../core/widgets/error_widgets.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../providers/cart_provider.dart';
import '../../../../di/infrastructure_providers.dart';

class BestSellerWidget extends ConsumerWidget {
  final int bestSellerId;
  final double height;
  final EdgeInsetsGeometry padding;

  const BestSellerWidget({
    super.key,
    required this.bestSellerId,
    this.height = 370,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  // Build unavailability message widget
  Widget _buildUnavailabilityMessage(BuildContext context, WidgetRef ref, dynamic status) {
    String title;
    String message;
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    // Determine message and styling based on outlet status
    if (!status.isEnabled) {
      title = 'Store Temporarily Closed';
      message = status.storeMessage.isNotEmpty 
          ? status.storeMessage 
          : 'This store is currently not accepting orders.';
      backgroundColor = AppColors.errorLight;
      textColor = AppColors.error;
      icon = Icons.store_outlined;
    } else if (!status.hasAnyServiceAvailable) {
      title = 'Services Temporarily Unavailable';
      message = status.storeMessage.isNotEmpty 
          ? status.storeMessage 
          : 'Neither delivery nor pickup is currently available.';
      backgroundColor = AppColors.warningLight;
      textColor = AppColors.warning;
      icon = Icons.delivery_dining_outlined;
    } else if (status.hasDeliveryOnly) {
      title = 'Limited Service Available';
      message = status.storeMessage.isNotEmpty 
          ? status.storeMessage 
          : 'Only home delivery is currently available.';
      backgroundColor = AppColors.infoLight;
      textColor = AppColors.info;
      icon = Icons.info_outline;
    } else if (status.hasPickupOnly) {
      title = 'Limited Service Available';
      message = status.storeMessage.isNotEmpty 
          ? status.storeMessage 
          : 'Only store pickup is currently available.';
      backgroundColor = AppColors.infoLight;
      textColor = AppColors.info;
      icon = Icons.info_outline;
    } else {
      // This shouldn't happen if cart is disabled, but just in case
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: textColor,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Refresh button
          IconButton(
            onPressed: () {
              ref.read(refreshOutletStatusProvider)();
            },
            icon: Icon(
              Icons.refresh,
              color: textColor,
              size: 20,
            ),
            tooltip: 'Refresh status',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context, WidgetRef ref) {
  // Get the banner/slider data for this best seller section
  final bannerAsync = ref.watch(bestSellerBannerProvider(bestSellerId));
  
  // Get the background color separately to ensure it triggers a rebuild
  final backgroundColor = ref.watch(bestSellerBackgroundColorProvider(bestSellerId));
  
  // Get outlet status for showing unavailability message
  final outletStatusAsync = ref.watch(currentOutletStatusProvider);
  final isCartEnabled = ref.watch(isCartEnabledProvider);
  
  // Log the color for debugging
  ref.read(loggerProvider).log('Best Seller $bestSellerId background color: $backgroundColor');

  return bannerAsync.when(
    data: (banners) {
      // Container with a unique key based on the background color to force rebuild
      return Container(
        key: ValueKey('best_seller_${bestSellerId}_${backgroundColor.value}'),
        color: backgroundColor, // Apply background color to entire widget
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner/Slider Section - Conditional based on banner count
            if (banners.isEmpty)
              const SizedBox.shrink() // No banner to show
            else if (banners.length == 1)
              // Single banner - no carousel, just a static image
              _buildSingleBanner(context, banners.first)
            else
              // Multiple banners - use carousel with auto-play
              _buildMultipleBannersCarousel(context, banners),
            
            const SizedBox(height: 16),
            
            // Show unavailability message if cart is disabled
            outletStatusAsync.when(
              data: (status) {
                if (status != null && !isCartEnabled) {
                  return _buildUnavailabilityMessage(context, ref, status);
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
            
            // Products Section - Only show if banners are not empty
            if (banners.isNotEmpty) // New condition: Only show products if banners exist
              _buildProductsSection(context, ref),
          ],
        ),
      );
    },
    loading: () => Container(
      color: Colors.white,
      child: Column(
        children: [
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
          // Error state for banner
          Container(
            color: Colors.white,
            height: MediaQuery.of(context).size.width * (200 / 800),
            child: Center(
              child: Text('Error loading banner: $error'),
            ),
          ),
          // We're not showing products in error state at all, as per requirement
        ],
      ),
    ),
  );
}

Widget _buildProductsSection(BuildContext context, WidgetRef ref) {
  final productsAsync = ref.watch(bestSellerProductsProvider(bestSellerId));
  
  return productsAsync.when(
    data: (products) {
      if (products.isEmpty) {
        return const EmptyStateWidget(
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
  );
}

  // Build single banner without carousel
  Widget _buildSingleBanner(BuildContext context, dynamic banner) {
    return GestureDetector(
      onTap: () {
        // Navigate to best seller products screen for this bestSellerId
        context.push('/best-seller/$bestSellerId');
      },
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * (200 / 800), // Maintain 800:200 aspect ratio
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        child: CachedNetworkImageWidget(
          // Use a unique cacheKey that includes the color to force refresh
          cacheKey: 'best_seller_${bestSellerId}_${banner.id}_${banner.backgroundColor}',
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
  }

  // Build multiple banners with carousel
  Widget _buildMultipleBannersCarousel(BuildContext context, List<dynamic> banners) {
    return CarouselSlider(
      options: CarouselOptions(
        height: MediaQuery.of(context).size.width * (200 / 800), // Maintain 800:200 aspect ratio
        viewportFraction: 1.0, // Use full width
        autoPlay: true, // Auto-play enabled for multiple banners
        enlargeCenterPage: false, // No enlargement to use full width
        autoPlayInterval: const Duration(seconds: 5),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        padEnds: false, // No padding at the ends
        enableInfiniteScroll: true, // Enable infinite scroll for multiple banners
      ),
      items: banners.map((banner) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                // Navigate to best seller products screen for this bestSellerId
                context.push('/best-seller/$bestSellerId');
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: EdgeInsets.zero, // No padding
                margin: EdgeInsets.zero, // No margin
                child: CachedNetworkImageWidget(
                  // Use a unique cacheKey that includes the color to force refresh
                  cacheKey: 'best_seller_${bestSellerId}_${banner.id}_${banner.backgroundColor}',
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
  
  return Container(
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
        // Product image with discount badge and favorite button
        Stack(
          children: [
            InkWell(
              onTap: () {
                // Navigate to product detail page
                context.push('/product/${product.pCode}');
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: _buildProductImage(product),
              ),
            ),
            if (discountPercent > 0)
              Positioned(
                top: 0,
                right: 0, // Positioned on right instead of left to avoid overlap with favorite button
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    "$discountPercent% OFF",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Properly positioned favorite button at top left with better styling
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: FavoriteButton(
                  product: product,
                  size: 18,
                  activeColor: Colors.red,
                  inactiveColor: Colors.grey.shade600,
                  showSnackbarMessages: false, // Disable snackbar in horizontal scroll
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
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
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
                    "₹${product.ourPrice.toStringAsFixed(product.ourPrice.truncateToDouble() == product.ourPrice ? 0 : 2)}",
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (product.productMrp > product.ourPrice)
                    Text(
                      "₹${product.productMrp.toStringAsFixed(product.productMrp.truncateToDouble() == product.productMrp ? 0 : 2)}",
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

        // IPO badge + Add to cart button row
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (product.isIpoProduct && product.ipoImg.isNotEmpty)
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
                child: isInCart
                    ? _buildManualQuantitySelector(context, ref, product, quantity)
                    : _buildConditionalAddToCartButton(ref, product),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // Updated product image widget with fallback using ApiConstants
  Widget _buildProductImage(ProductModel product) {
    // Check if product image URL is available and valid
    if (product.pcodeImg.isNotEmpty && 
        product.pcodeImg != 'null' && 
        product.pcodeImg.toLowerCase() != 'null') {
      
      return Image.network(
        product.pcodeImg,
        height: 120,
        width: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey[100],
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // If main image fails, try fallback image
          return _buildFallbackImage();
        },
      );
    } else {
      // If no product image URL, directly show fallback
      return _buildFallbackImage();
    }
  }

  // Fallback image widget using the company logo
  Widget _buildFallbackImage() {
    return Image.network(
      ApiConstants.fallbackImageUrl,
      height: 120,
      width: double.infinity,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 120,
          width: double.infinity,
          color: Colors.grey[100],
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // If even fallback fails, show placeholder with company branding
        return Container(
          height: 120,
          width: double.infinity,
          color: Colors.grey[100],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary.withOpacity(0.6),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Patel Mart',
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Product Image',
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
  }

  // Manual quantity selector with improved styling to match product_item_widget
  Widget _buildManualQuantitySelector(BuildContext context, WidgetRef ref, ProductModel product, int quantity) {
    // Check if cart operations are enabled
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    
    return Container(
      height: 32, // Reduced height to match product_item_widget
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Decrement button
          Material(
            color: isCartEnabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
            child: InkWell(
              onTap: isCartEnabled ? () {
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
                width: 32, // Fixed width to match height
                height: 32, // Fixed height
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: isCartEnabled ? Colors.white : Colors.grey.shade600,
                  size: 16, // Smaller icon size for better appearance
                ),
              ),
            ),
          ),
          
          // Manual quantity input field - using the optimized approach from product_item_widget
          Expanded(
            child: Container(
              height: 32,
              color: isCartEnabled ? Colors.white : Colors.grey.shade100,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: product.maxQuantityAllowed,
                enabled: isCartEnabled,
                onQuantityChanged: (newQuantity) {
                  if (isCartEnabled) {
                    _handleManualQuantityInput(context, ref, product, newQuantity);
                  }
                },
              ),
            ),
          ),
          
          // Increment button
          Material(
            color: isCartEnabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            child: InkWell(
              onTap: isCartEnabled ? () {
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
                width: 32, // Fixed width to match height
                height: 32, // Fixed height
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: isCartEnabled ? Colors.white : Colors.grey.shade600,
                  size: 16, // Smaller icon size for better appearance
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated add to cart button with conditional logic based on outlet status
  Widget _buildConditionalAddToCartButton(WidgetRef ref, ProductModel product) {
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);
    
    return outletStatusAsync.when(
      data: (status) {
        // If outlet status is unknown, show normal button (fail-safe)
        if (status == null) {
          return _buildAddToCartButton(ref, product, isEnabled: true);
        }
        
        // If cart is disabled due to outlet status, show disabled button
        if (!isCartEnabled) {
          return _buildDisabledAddToCartButton(status.statusMessage);
        }
        
        // Normal add to cart button
        return _buildAddToCartButton(ref, product, isEnabled: true);
      },
      loading: () => _buildLoadingAddToCartButton(),
      error: (error, stackTrace) => _buildAddToCartButton(ref, product, isEnabled: true), // Fail-safe: allow cart on error
    );
  }

  // Normal add to cart button with enabled/disabled state
  Widget _buildAddToCartButton(WidgetRef ref, ProductModel product, {required bool isEnabled}) {
    return SizedBox(
      height: 32, // Reduced height to match product_item_widget
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () => ref.read(cartProvider.notifier).addItem(product) : null,
        icon: Icon(
          Icons.shopping_cart_outlined,
          color: isEnabled ? Colors.white : Colors.grey.shade600,
          size: 12, // Reduced icon size
        ),
        label: Text(
          "ADD",
          style: TextStyle(
            color: isEnabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 11, // Reduced font size
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.primary : Colors.grey.shade300,
          minimumSize: const Size(double.infinity, 32), // Reduced height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
          elevation: isEnabled ? 2 : 0,
        ),
      ),
    );
  }

  // Disabled add to cart button with status message
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
                fontSize: 10, // Smaller font for longer text
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

  // Loading add to cart button
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

// Optimized manual quantity input widget to match product_item_widget implementation
class _ManualQuantityInput extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final bool enabled;
  final ValueChanged<int> onQuantityChanged;

  const _ManualQuantityInput({
    required this.initialQuantity,
    required this.maxQuantity,
    required this.enabled,
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