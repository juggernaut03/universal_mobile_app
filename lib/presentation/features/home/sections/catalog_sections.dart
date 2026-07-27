// lib/presentation/features/home/sections/catalog_sections.dart
//
// Sections drawn straight from the content the feed already carries, rather
// than by re-fetching through a legacy provider.
//
// These cover the admin collections that previously had no way to reach the
// home screen at all: the second banner placement, advertisements, and top
// sellers. Because they render `section.items`, they cost no extra request.

import 'package:flutter/material.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';
import '../../../../data/models/home_feed_mappers.dart';
import '../../../../data/models/home_feed_models.dart';
import '../../../../data/services/banner_service.dart';
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

  const FeedProductRailSection({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final products = section.toProducts();
    if (products.isEmpty) return const SizedBox.shrink();

    final background = homeSectionBackground(section.style.backgroundColor);

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                section.title,
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => HomeProductCard(product: products[index]),
            ),
          ),
        ],
      ),
    );
  }
}
