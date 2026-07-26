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
import '../../../providers/steal_deals_provider.dart';
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
    HomeSectionType.categoryGrid: _categoryGrid,
    HomeSectionType.productRail: _productRail,
    HomeSectionType.offerStrip: _offerStrip,
    HomeSectionType.seasonalPicks: _seasonalPicks,
  };

  static bool canRender(String type) => _builders.containsKey(type);

  /// Draws [section], or nothing if this build does not know the type.
  static Widget build(BuildContext context, WidgetRef ref, HomeSection section) {
    final builder = _builders[section.type];
    if (builder == null) return const SizedBox.shrink();

    return RepaintBoundary(
      key: ValueKey('home_section_${section.id}'),
      child: builder(context, ref, section),
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

  static Widget _productRail(BuildContext context, WidgetRef ref, HomeSection section) {
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
}
