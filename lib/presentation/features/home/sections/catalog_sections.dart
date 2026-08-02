// lib/presentation/features/home/sections/catalog_sections.dart
//
// Sections drawn straight from the content the feed already carries, rather
// than by re-fetching through a legacy provider.
//
// These cover the admin collections that previously had no way to reach the
// home screen at all: the second banner placement, advertisements, and top
// sellers. Because they render `section.items`, they cost no extra request.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/home_feed_mappers.dart';
import '../../../../data/models/home_feed_models.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/services/banner_service.dart';
import '../../../providers/recently_viewed_providers.dart';
import 'home_product_card.dart';

// ----------------------------------------------------------------------

/// A banner placement other than the hero — `home_middle` banners, or an
/// advertisement category.
///
/// One image is drawn full width; several scroll horizontally. A carousel with
/// a single slide is just a fixed image with extra machinery.
class BannerStripSection extends StatelessWidget {
  final HomeSection section;

  const BannerStripSection({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    // The feed carries banners and advertisements in different shapes; the
    // mapper normalises both onto the model the banner widgets already use.
    final banners = section.toPromotionalBanners('');
    if (banners.isEmpty) return const SizedBox.shrink();

    final background = homeSectionBackground(section.style.backgroundColor);

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                section.title,
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          if (banners.length == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BannerTile(banner: banners.first, width: double.infinity),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: banners.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _BannerTile(banner: banners[index], width: 280),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final PromotionalBanner banner;
  final double width;

  const _BannerTile({required this.banner, required this.width});

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImageWidget(
        imageUrl: banner.imageUrl,
        width: width,
        height: 140,
        fit: BoxFit.cover,
      ),
    );

    // A banner with nowhere to go should not look tappable.
    if (banner.redirectLink.isEmpty) return image;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openBannerTarget(context, banner.redirectLink),
      child: image,
    );
  }
}

// ----------------------------------------------------------------------

/// A product rail rendered from the items the feed already sent.
///
/// Used for top sellers, which have no legacy provider of their own — the
/// best-seller widget addresses its content by sequence within the
/// best_sellers collection and would fetch the wrong rail entirely.
class FeedProductRailSection extends StatelessWidget {
  final HomeSection section;

  /// Supplied products, for rails the server cannot fill — recently viewed is
  /// on-device only. Omit to read the items the feed sent.
  final List<ProductModel>? products;

  /// Heading when the section carries none of its own.
  final String? fallbackTitle;

  const FeedProductRailSection({
    super.key,
    required this.section,
    this.products,
    this.fallbackTitle,
  });

  @override
  Widget build(BuildContext context) {
    final products = this.products ?? section.toProducts();
    if (products.isEmpty) return const SizedBox.shrink();

    final heading = section.title.isNotEmpty ? section.title : (fallbackTitle ?? '');

    final background = homeSectionBackground(section.style.backgroundColor);

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading.isNotEmpty) HomeSectionHeading(title: heading),
          SizedBox(
            height: kHomeProductCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => HomeProductCard(product: products[index]),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------

/// Products the shopper looked at, newest first.
///
/// Personalised: the server sends an empty placeholder and this fills it from
/// on-device history, so browsing behaviour never leaves the phone.
class RecentlyViewedSection extends ConsumerWidget {
  final HomeSection section;

  const RecentlyViewedSection({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(recentlyViewedProvider).valueOrNull ?? const [];

    // A first-time shopper has no history, and an empty "Recently viewed" is
    // worse than no section.
    if (products.isEmpty) return const SizedBox.shrink();

    return FeedProductRailSection(
      section: section,
      products: products,
      fallbackTitle: 'Recently viewed',
    );
  }
}

// ----------------------------------------------------------------------

/// Cart-level coupons: title, saving and the spend that unlocks them.
///
/// Public content — a coupon is the same for everyone — so it travels in the
/// feed rather than being fetched per user.
class CouponStripSection extends StatelessWidget {
  final HomeSection section;

  const CouponStripSection({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final coupons = section.items;
    if (coupons.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: homeSectionBackground(section.style.backgroundColor),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              section.title.isNotEmpty ? section.title : 'Offers for you',
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _CouponCard(coupon: coupons[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;

  const _CouponCard({required this.coupon});

  /// "₹50 off" or "10% off" — the saving is the reason to look, so it leads.
  String get _headline {
    final amount = double.tryParse('${coupon['discount_amount'] ?? ''}') ?? 0;
    if (amount <= 0) return (coupon['title'] ?? 'Offer').toString();

    final isPercent = '${coupon['discount_type']}' == 'percentage';
    return isPercent ? '${amount.toStringAsFixed(0)}% off' : '₹${amount.toStringAsFixed(0)} off';
  }

  String get _condition {
    final min = double.tryParse('${coupon['min_cart_value'] ?? ''}') ?? 0;
    return min > 0 ? 'On orders over ₹${min.toStringAsFixed(0)}' : 'On your order';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (coupon['title'] ?? '').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            _condition,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------

/// Brands in this store, each tapping through to its products.
class BrandStripSection extends StatelessWidget {
  final HomeSection section;

  const BrandStripSection({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final brands = section.items;
    if (brands.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: homeSectionBackground(section.style.backgroundColor),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              section.title.isNotEmpty ? section.title : 'Shop by brand',
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: brands.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _BrandTile(brand: brands[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  final Map<String, dynamic> brand;

  const _BrandTile({required this.brand});

  @override
  Widget build(BuildContext context) {
    final name = (brand['brand_name'] ?? '').toString();
    if (name.isEmpty) return const SizedBox.shrink();

    return InkWell(
      // Search matches brand names as well as product names, so this lands on
      // the brand's products. There is no brand landing page to route to.
      onTap: () => context.push('/search?query=${Uri.encodeComponent(name)}'),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: CachedNetworkImageWidget(
                imageUrl: (brand['image_url'] ?? '').toString(),
                width: 62,
                height: 62,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
