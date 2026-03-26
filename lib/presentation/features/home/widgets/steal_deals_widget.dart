import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/steal_deals_provider.dart';
import '../../../providers/outlet_status_provider.dart';

/// "Steal deals for you" widget — wide horizontal cards matching reference UI.
class StealDealsWidget extends ConsumerWidget {
  const StealDealsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(stealDealsOffersProvider);

    // Use .when with skipLoadingOnRefresh to keep showing previous data
    // while new data is being fetched
    final offers = offersAsync.whenOrNull(data: (data) => data);
    final previousOffers = offersAsync.valueOrNull;
    final displayOffers = offers ?? previousOffers;

    if (displayOffers == null || displayOffers.isEmpty) {
      // Only hide if we truly have no data (not just refreshing)
      if (offersAsync.isLoading && previousOffers == null) {
        return const SizedBox.shrink();
      }
      if (offersAsync.hasError && previousOffers == null) {
        return const SizedBox.shrink();
      }
      if (displayOffers != null && displayOffers.isEmpty) {
        return const SizedBox.shrink();
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Steal deals for you',
            style: AppTextStyles.h5.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: displayOffers.length,
            itemBuilder: (context, index) {
              return _StealDealCard(offer: displayOffers[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _StealDealCard extends ConsumerWidget {
  final StealDealOffer offer;

  const _StealDealCard({required this.offer});

  String _formatPrice(double price) {
    return price.truncateToDouble() == price
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = offer.product;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.75;

    final cartItems = ref.watch(cartProvider);
    final cartItem =
        cartItems.where((item) => item.product.pCode == product.pCode).toList();
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;
    final isCartEnabled = ref.watch(isCartEnabledProvider);

    // Determine header based on offer deal_status
    final bool isUnlocked = offer.visible;
    final String headerText = offer.offerConditionText;
    final Color headerColor =
        isUnlocked ? AppColors.success : Colors.orange.shade700;
    final IconData headerIcon =
        isUnlocked ? Icons.check_circle_outline : Icons.lock_outline;

    return GestureDetector(
      onTap: () => context.push('/product/${product.pCode}'),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    headerIcon,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      headerText,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body: image left, details right ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image with add/qty button
                    SizedBox(
                      width: cardWidth * 0.38,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildProductImage(product, cardWidth * 0.38),
                          ),
                          if (isUnlocked)
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: isInCart
                                  ? _buildQuantityBadge(ref, product, quantity)
                                  : _buildAddButton(ref, product, isCartEnabled),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Right side — offer name + product name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Package size chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '${product.packageSize % 1 == 0 ? product.packageSize.toInt() : product.packageSize} ${product.packageUnit}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.neutral700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Offer name
                          Text(
                            offer.offerName,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Price row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Deal price — green badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '₹${_formatPrice(product.ourPrice)}',
                      style: AppTextStyles.h6.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "current price ₹XX" with strikethrough on the amount
                  Text(
                    'current price ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                  Text(
                    '₹${_formatPrice(product.productMrp)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.neutral500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _buildProductImage(ProductModel product, double size) {
    if (product.pcodeImg.isNotEmpty &&
        product.pcodeImg != 'null' &&
        product.pcodeImg.toLowerCase() != 'null') {
      return Image.network(
        product.pcodeImg,
        width: size,
        height: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[100],
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackImage(size),
      );
    }
    return _buildFallbackImage(size);
  }

  Widget _buildFallbackImage(double size) {
    return Image.network(
      ApiConstants.fallbackImageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: Colors.grey[100],
        child: Icon(
          Icons.shopping_bag_outlined,
          color: AppColors.primary.withOpacity(0.5),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildAddButton(WidgetRef ref, ProductModel product, bool isCartEnabled) {
    return GestureDetector(
      onTap: isCartEnabled
          ? () => ref.read(cartProvider.notifier).addItem(product)
          : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCartEnabled ? AppColors.primary : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: isCartEnabled ? AppColors.primary : Colors.grey.shade400,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildQuantityBadge(WidgetRef ref, ProductModel product, int quantity) {
    return GestureDetector(
      onTap: () => ref.read(cartProvider.notifier).incrementQuantity(product),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            quantity.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
