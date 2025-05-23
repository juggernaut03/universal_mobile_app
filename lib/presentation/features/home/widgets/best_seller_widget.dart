// lib/presentation/features/home/widgets/best_seller_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/quantity_input_widget.dart';
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
  final double height;
  final EdgeInsetsGeometry padding;

  const BestSellerWidget({
    Key? key,
    required this.bestSellerId,
    this.height = 320,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the banner/slider data for this best seller section
    final bannerAsync = ref.watch(bestSellerBannerProvider(bestSellerId));
    
    // Get the product data for this best seller section
    final productsAsync = ref.watch(bestSellerProductsProvider(bestSellerId));
    
    // Get the background color separately to ensure it triggers a rebuild
    final backgroundColor = ref.watch(bestSellerBackgroundColorProvider(bestSellerId));
    
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
              
              // Products Section
              productsAsync.when(
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
              ),
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
          ],
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
                  borderRadius: const BorderRadius.only(
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
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        "${discountPercent}% OFF",
                        style: const TextStyle(
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
            
            // Enhanced Add to cart button or quantity selector with manual input
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: isInCart
                  ? _buildManualQuantitySelector(context, ref, product, quantity)
                  : _buildAddToCartButton(ref, product),
            ),
          ],
        ),
      ),
    );
  }

  // Manual quantity selector with text input capability
  Widget _buildManualQuantitySelector(BuildContext context, WidgetRef ref, ProductModel product, int quantity) {
    return Container(
      height: 36,
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
                ref.read(cartProvider.notifier).decrementQuantity(product);
              } else {
                // Remove item if quantity becomes 0
                ref.read(cartProvider.notifier).removeItem(product);
              }
            },
            child: Container(
              width: 30,
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
          
          // Manual quantity input field
          Expanded(
            child: Container(
              height: 36,
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
              width: 30,
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
    );
  }

  // Simple add to cart button
  Widget _buildAddToCartButton(WidgetRef ref, ProductModel product) {
    return SizedBox(
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
        fontSize: 14,
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