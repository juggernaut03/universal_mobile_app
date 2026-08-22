// lib/presentation/features/cart/widgets/cart_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/steal_deals_provider.dart';

class CartItemWidget extends ConsumerWidget {
  final CartItem cartItem;
  final VoidCallback onIncrementQuantity;
  final VoidCallback onDecrementQuantity;
  final VoidCallback onRemove;

  const CartItemWidget({
    super.key,
    required this.cartItem,
    required this.onIncrementQuantity,
    required this.onDecrementQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = cartItem.product;
    final quantity = cartItem.quantity;

    // Check if this product is an offer product (max 1 qty)
    final offerPCodes = ref.watch(offerProductCodesProvider);
    final isOfferProduct = offerPCodes.contains(product.pCode);
    final maxQty = isOfferProduct ? 1 : product.maxQuantityAllowed;
    
    // Calculate total price and savings
    final totalPrice = product.ourPrice * quantity;
    final totalMrp = product.productMrp * quantity;
    final savings = totalMrp - totalPrice;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.neutral200,
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image with optional IPO badge overlay
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product.pcodeImg.isNotEmpty
                            ? product.pcodeImg
                            : ApiConstants.fallbackImageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          // Tenant fallback (admin panel > Mobile App >
                          // Branding > App Logo) can itself be empty/unset.
                          if (ApiConstants.fallbackImageUrl.isEmpty) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[100],
                              child: Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                            );
                          }
                          return Image.network(
                            ApiConstants.fallbackImageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[100],
                              child: Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                            ),
                          );
                        },
                      ),
                    ),
                    if (product.isIpoProduct && product.ipoImg.isNotEmpty)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Image.network(
                          product.ipoImg,
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Product details
              Expanded(
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

                    // Offer tag
                    if (isOfferProduct)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer,
                                color: AppColors.success,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Offer Claimed',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Weight
                    Text(
                      '${product.packageSize} ${product.packageUnit.toLowerCase()}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Price and savings
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // You pay
                            Text(
                              'You Pay ₹${totalPrice.toStringAsFixed(totalPrice.truncateToDouble() == totalPrice ? 0 : 2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // You save
                            if (savings > 0)
                              Text(
                                'You Save ₹${savings.toStringAsFixed(savings.truncateToDouble() == savings ? 0 : 2)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        
                        const Spacer(),
                        
                        // Quantity controls
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.neutral300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              // Decrement button
                              InkWell(
                                onTap: quantity > 1 ? onDecrementQuantity : null,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: quantity > 1 
                                        ? AppColors.primary 
                                        : AppColors.neutral300,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(3),
                                      bottomLeft: Radius.circular(3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                              
                              // Quantity
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                color: Colors.white,
                                child: Text(
                                  quantity.toString(),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              
                              // Increment button
                              InkWell(
                                onTap: quantity < maxQty 
                                    ? onIncrementQuantity 
                                    : null,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: quantity < maxQty 
                                        ? AppColors.primary 
                                        : AppColors.neutral300,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(3),
                                      bottomRight: Radius.circular(3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Max quantity note
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Max $maxQty items',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Add the remove button at the top right corner
        Positioned(
          top: 12,
          right: 12,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withOpacity(0.6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}