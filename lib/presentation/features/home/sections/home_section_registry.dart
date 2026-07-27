// lib/presentation/features/home/sections/home_section_registry.dart
//
// The one place a home section type is turned into a widget.
//
// Adding a section type is: one entry here plus its renderer. Removing the
// entry is enough to stop the app drawing that type, whatever the backend
// sends. A type with no entry is skipped silently — that property is what lets
// the backend ship a new section before the app that renders it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/home_feed_models.dart';
import '../../../../di/service_providers.dart';
import '../../../providers/steal_deals_provider.dart';
import 'catalog_sections.dart';
import 'merchandising_sections.dart';
import '../widgets/best_seller_widget.dart';
import '../widgets/popular_category_section_widget.dart';
import '../widgets/promotional_banner_widget.dart';
import '../widgets/seasonal_category_widget.dart';
import '../widgets/seasonal_picks_widget.dart';
import '../widgets/single_offer_section_widget.dart';

typedef HomeSectionBuilder = Widget Function(
  BuildContext context,
  WidgetRef ref,
  HomeSection section,
);

class HomeSectionRegistry {
  const HomeSectionRegistry._();

  static final Map<String, HomeSectionBuilder> _builders = {
    HomeSectionType.categoryStrip: _categoryStrip,
    HomeSectionType.heroCarousel: _heroCarousel,
    HomeSectionType.bannerStrip: _bannerStrip,
    HomeSectionType.categoryGrid: _categoryGrid,
    HomeSectionType.productRail: _productRail,
    HomeSectionType.offerStrip: _offerStrip,
    HomeSectionType.seasonalPicks: _seasonalPicks,

    // Merchandising sections. Each is one entry plus one widget — the whole
    // cost of a new section type.
    HomeSectionType.flashSale: _flashSale,
    HomeSectionType.dealOfDay: _flashSale,
    HomeSectionType.buyAgain: _buyAgain,
    HomeSectionType.freeDeliveryProgress: _freeDeliveryProgress,
    HomeSectionType.uspStrip: _uspStrip,
  };

  static bool canRender(String type) => _builders.containsKey(type);

  /// Draws [section], or nothing if this build does not know the type.
  static Widget build(BuildContext context, WidgetRef ref, HomeSection section) {
    final builder = _builders[section.type];
    if (builder == null) return const SizedBox.shrink();

    return RepaintBoundary(
      key: ValueKey('home_section_${section.id}'),
      child: _TrackedSection(
        section: section,
        child: builder(context, ref, section),
      ),
    );
  }

  // ---- renderers ----
  //
  // Phase 1 reuses the existing widgets unchanged, so the feed can only change
  // order and visibility — not appearance. Each still fetches its own content
  // by section sequence; wiring them to the items the feed already carries is
  // the next step and is what removes the extra calls.

  static Widget _categoryStrip(BuildContext context, WidgetRef ref, HomeSection section) {
    return const SeasonalCategoryWidget(
      departmentId: 2,
      itemWidth: 100,
      itemHeight: 100,
      showTitle: false,
      showViewAll: false,
      spacing: 4,
      padding: EdgeInsets.symmetric(horizontal: 8),
      enablePullToRefresh: false, // home screen owns refresh
    );
  }

  static Widget _heroCarousel(BuildContext context, WidgetRef ref, HomeSection section) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: const PromotionalBannerWidget(
        showPageIndicator: true,
        autoPlay: true,
        autoPlayInterval: Duration(seconds: 5),
        enableRefresh: true,
      ),
    );
  }

  static Widget _categoryGrid(BuildContext context, WidgetRef ref, HomeSection section) {
    final sectionId = section.sourceSequence;
    if (sectionId == null) return const SizedBox.shrink();

    return PopularCategorySectionWidget(
      sectionId: sectionId,
      showTitle: true,
      showViewAll: true,
      itemWidth: 80,
      itemHeight: 95,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      spacing: 6,
    );
  }

  /// The second banner placement, and how advertisements reach home. Drawn
  /// from the items the feed carries, so it costs no extra request.
  static Widget _bannerStrip(BuildContext context, WidgetRef ref, HomeSection section) =>
      BannerStripSection(section: section);

  /// A product rail is backed by either best sellers or top sellers, and the
  /// two can share a sequence. Dispatching on sequence alone would render the
  /// best-seller rail in the top-seller slot.
  static Widget _productRail(BuildContext context, WidgetRef ref, HomeSection section) {
    if (section.sourceCollection == HomeSectionSource.topSellers) {
      return FeedProductRailSection(section: section);
    }

    final sectionId = section.sourceSequence;
    if (sectionId == null) return const SizedBox.shrink();

    return BestSellerWidget(
      bestSellerId: sectionId,
      height: 320,
    );
  }

  /// Cart-dependent, so the server sends an empty placeholder and the client
  /// fills it from its own offers call. A slot with no matching offer collapses.
  static Widget _offerStrip(BuildContext context, WidgetRef ref, HomeSection section) {
    final index = section.sourceIndex;
    if (index == null) return const SizedBox.shrink();

    final offersAsync = ref.watch(stealDealsOffersProvider);
    final offers = offersAsync.valueOrNull ?? const [];
    if (index >= offers.length) return const SizedBox.shrink();

    return SingleOfferSectionWidget(offer: offers[index]);
  }

  static Widget _seasonalPicks(BuildContext context, WidgetRef ref, HomeSection section) {
    return const SeasonalPicksWidget();
  }

  /// Deal-of-the-day is a flash sale with one item; the presentation is the
  /// same, so it shares the renderer rather than duplicating it.
  static Widget _flashSale(BuildContext context, WidgetRef ref, HomeSection section) =>
      FlashSaleSection(section: section);

  static Widget _buyAgain(BuildContext context, WidgetRef ref, HomeSection section) =>
      BuyAgainSection(section: section);

  static Widget _freeDeliveryProgress(
    BuildContext context,
    WidgetRef ref,
    HomeSection section,
  ) =>
      FreeDeliveryProgressSection(section: section);

  static Widget _uspStrip(BuildContext context, WidgetRef ref, HomeSection section) =>
      UspStripSection(section: section);
}

/// Counts a section as seen once it is actually built.
///
/// Impression tracking has to wrap the section rather than live inside each
/// renderer, or every new section type would have to remember to report — and
/// the one that forgot would silently look like it never performed.
class _TrackedSection extends ConsumerStatefulWidget {
  final HomeSection section;
  final Widget child;

  const _TrackedSection({required this.section, required this.child});

  @override
  ConsumerState<_TrackedSection> createState() => _TrackedSectionState();
}

class _TrackedSectionState extends ConsumerState<_TrackedSection> {
  @override
  void initState() {
    super.initState();
    // After the frame: reporting during build would rebuild providers mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeAnalyticsServiceProvider).recordImpression(
            sectionId: widget.section.id,
            sectionType: widget.section.type,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    // A tap anywhere in the section counts as engagement with it.
    //
    // Listener observes pointer events without competing for them, so the
    // section's own taps still work exactly as before. deferToChild means it
    // fires only when something inside was actually hit, not on empty space.
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerUp: (_) => ref.read(homeAnalyticsServiceProvider).recordClick(
            sectionId: widget.section.id,
            sectionType: widget.section.type,
          ),
      child: widget.child,
    );
  }
}
