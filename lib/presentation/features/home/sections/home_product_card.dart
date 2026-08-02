// lib/presentation/features/home/sections/home_product_card.dart
//
// Compact product tile shared by the feed-driven rails.
//
// Deliberately thin: the tap target is what matters, and the existing
// best-seller card is welded to its own providers.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/product_model.dart';

/// Card footprint, shared with the rails so a rail's height is derived from the
/// card rather than guessed. A rail that guesses tall leaves the dead band of
/// background the tile used to sit in.
const double kHomeProductCardWidth = 140;
const double kHomeProductCardImageHeight = 126;
const double kHomeProductCardHeight = 196;

class HomeProductCard extends StatelessWidget {
  final ProductModel product;

  const HomeProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.productMrp > product.ourPrice && product.ourPrice > 0;

    return SizedBox(
      width: kHomeProductCardWidth,
      height: kHomeProductCardHeight,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/product/${product.pCode}'),
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
                SizedBox(
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
                // Flexible rather than fixed: the price stays pinned to the
                // bottom edge across cards, so the rail reads as one line of
                // prices however long the names run.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
