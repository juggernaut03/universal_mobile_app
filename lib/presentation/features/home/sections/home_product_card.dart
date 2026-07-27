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

class HomeProductCard extends StatelessWidget {
  final ProductModel product;

  const HomeProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.productMrp > product.ourPrice && product.ourPrice > 0;

    return InkWell(
      onTap: () => context.push('/product/${product.pCode}'),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImageWidget(
                  imageUrl: product.pcodeImg,
                  fit: BoxFit.cover,
                  width: 150,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '₹${product.ourPrice.toStringAsFixed(0)}',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                if (hasDiscount) ...[
                  const SizedBox(width: 6),
                  Text(
                    '₹${product.productMrp.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
