// lib/presentation/features/home/sections/home_product_card.dart
//
// Compact product tile shared by the feed-driven rails (flash sale, recently
// viewed, top sellers, buy again).
//
// Carries its own add-to-cart control so a shopper can act on a rail without
// leaving the home screen — previously only the best-seller card could do
// that, so these rails were browse-only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/outlet_status_provider.dart';

/// Card footprint, shared with the rails so a rail's height is derived from the
/// card rather than guessed. A rail that guesses tall leaves the dead band of
/// background the tile used to sit in.
const double kHomeProductCardWidth = 140;
const double kHomeProductCardImageHeight = 110;
const double kHomeProductCardHeight = 228;

class HomeProductCard extends ConsumerWidget {
  final ProductModel product;

  const HomeProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDiscount = product.productMrp > product.ourPrice && product.ourPrice > 0;

    final cartItems = ref.watch(cartItemsProvider);
    final cartItem = cartItems.where((item) => item.product.pCode == product.pCode);
    final quantity = cartItem.isEmpty ? 0 : cartItem.first.quantity;
    final isCartEnabled = ref.watch(isCartEnabledProvider);

    // Only the image and text navigate to the product page — the add-to-cart
    // control below sits outside that tap region so the two never fight over
    // the same gesture (matching ProductItemWidget's split elsewhere).
    void openProduct() => context.push('/product/${product.pCode}');

    return SizedBox(
      width: kHomeProductCardWidth,
      height: kHomeProductCardHeight,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // `contain`, not `cover`: packaged goods are shot on white with
              // the label centred, and cropping to fill cut the brand off the
              // top of every tile.
              InkWell(
                onTap: openProduct,
                child: SizedBox(
                  height: kHomeProductCardImageHeight,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    child: CachedNetworkImageWidget(
                      imageUrl: product.pcodeImg,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Flexible rather than fixed: the name can run one or two lines,
              // but price and the add-to-cart control always sit pinned to the
              // bottom edge, so the rail reads as one line however long names run.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: openProduct,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              product.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 11.5,
                                height: 1.25,
                                letterSpacing: 0,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${product.ourPrice.toStringAsFixed(0)}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                              height: 1.2,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '₹${product.productMrp.toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                  height: 1.2,
                                  letterSpacing: 0,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 28,
                        width: double.infinity,
                        child: quantity > 0
                            ? _QuantityStepper(
                                product: product,
                                quantity: quantity,
                                enabled: isCartEnabled,
                              )
                            : _AddButton(
                                product: product,
                                enabled: isCartEnabled,
                              ),
                      ),
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
}

/// "ADD" — the card's resting state, before the product is in the cart.
class _AddButton extends ConsumerWidget {
  final ProductModel product;
  final bool enabled;

  const _AddButton({required this.product, required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: enabled ? AppColors.primary : AppColors.neutral200,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? () => ref.read(cartProvider.notifier).addItem(product) : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 12,
              color: enabled ? AppColors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'ADD',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: enabled ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the add button once the product is in the cart: −, quantity, +.
class _QuantityStepper extends ConsumerWidget {
  final ProductModel product;
  final int quantity;
  final bool enabled;

  const _QuantityStepper({
    required this.product,
    required this.quantity,
    required this.enabled,
  });

  void _showMaxQuantityMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${product.maxQuantityAllowed} items allowed'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Material(
      color: enabled ? AppColors.primary : AppColors.neutral200,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
            onTap: enabled
                ? () {
                    if (quantity > 1) {
                      notifier.decrementQuantity(product);
                    } else {
                      notifier.removeItem(product);
                    }
                  }
                : null,
            child: SizedBox(
              width: 26,
              height: 28,
              child: Icon(
                Icons.remove,
                size: 14,
                color: enabled ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: enabled ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
            onTap: enabled
                ? () {
                    if (quantity < product.maxQuantityAllowed) {
                      notifier.incrementQuantity(product);
                    } else {
                      _showMaxQuantityMessage(context);
                    }
                  }
                : null,
            child: SizedBox(
              width: 26,
              height: 28,
              child: Icon(
                Icons.add,
                size: 14,
                color: enabled ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heading for a feed rail.
///
/// One style for every rail: the sections used to each set their own, so a
/// tenant-supplied title landed at a different weight depending on which
/// collection filled the slot.
class HomeSectionHeading extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const HomeSectionHeading({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h6.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A section's `style.background_color` as a colour, or null when unset or
/// malformed — in which case the caller keeps its own default.
Color? homeSectionBackground(String hex) {
  final value = hex.replaceFirst('#', '').trim();
  if (value.length != 6 && value.length != 8) return null;
  final parsed = int.tryParse(value.length == 6 ? 'ff$value' : value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Routes a banner tap.
///
/// Shared so every banner placement resolves targets identically — the hero
/// carousel has always understood four formats, and a strip that only handled
/// in-app paths would swallow three of them as dead taps.
void openBannerTarget(BuildContext context, String target) {
  if (target.isEmpty) return;

  if (target.startsWith('product_details/')) {
    context.push('/product/${target.replaceFirst('product_details/', '')}');
    return;
  }

  if (target.startsWith('/')) {
    context.push(target);
    return;
  }

  if (target.contains('category_id=')) {
    final uri = Uri.tryParse(target);
    final categoryId = uri?.queryParameters['category_id'];
    if (categoryId != null) {
      final deptId = uri?.queryParameters['dept_id'] ?? '1';
      final categoryName = uri?.queryParameters['category_name'] ?? 'Category';
      context.push('/subcategory/$categoryId/$deptId/$categoryName');
    }
    return;
  }

  // External URLs need url_launcher, which the hero has never wired up either;
  // ignored rather than pushed onto the router as a bogus path.
}
