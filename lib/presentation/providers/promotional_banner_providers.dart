// lib/presentation/providers/promotional_banner_providers.dart
//
// Home-screen promotional banners. Moved out of promotional_banner_widget.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/home_feed_mappers.dart';
import '../../data/models/home_feed_models.dart';
import '../../data/services/banner_service.dart';
import '../../di/service_providers.dart';
import 'home_feed_providers.dart';
import 'outlet_provider.dart';

final refreshPromotionalBannersProvider = StateProvider<bool>((ref) => false);

// Provider for promotional banners with refresh capability
final promotionalBannersProvider = FutureProvider<List<PromotionalBanner>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.watch(refreshPromotionalBannersProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        return [];
      }
      
      // Served from the home feed when it carries the hero section — one
      // response for the whole screen instead of a call per section.
      final fromFeed = ref.watch(homeFeedProvider).valueOrNull
          ?.bySequence(HomeSectionType.heroCarousel, 0);
      if (!forceRefresh && fromFeed != null && fromFeed.items.isNotEmpty) {
        return fromFeed.toPromotionalBanners(outlet.storeCode);
      }

      final bannerService = ref.read(bannerServiceProvider);
      
      // If force refresh is true, clear cache before fetching
      if (forceRefresh) {
        await bannerService.clearCache();
        // Reset the refresh flag
        ref.read(refreshPromotionalBannersProvider.notifier).state = false;
      }
      
      return await bannerService.getPromotionalBanners(outlet.storeCode);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// The second banner placement, `home_middle`.
///
/// The admin panel has always offered this placement, but nothing ever asked
/// for it — only the hero was fetched — so banners saved here never appeared
/// however correctly they were configured.
final midBannersProvider = FutureProvider<List<PromotionalBanner>>((ref) async {
  final outlet = ref.watch(selectedOutletProvider).valueOrNull;
  if (outlet == null) return const [];

  // Served from the feed when it carries the strip, same as the hero above.
  final fromFeed = ref.watch(homeFeedProvider).valueOrNull?.sections.where(
        (s) =>
            s.type == HomeSectionType.bannerStrip &&
            s.sourceCollection == HomeSectionSource.banners,
      );
  if (fromFeed != null && fromFeed.isNotEmpty) {
    return fromFeed.first.toPromotionalBanners(outlet.storeCode);
  }

  return ref.read(bannerServiceProvider).getPromotionalBanners(
        outlet.storeCode,
        sectionName: BannerService.homeMiddleSection,
      );
});

// Provider for refreshing promotional banners manually
final promotionalBannerRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true to trigger cache clearing
    ref.read(refreshPromotionalBannersProvider.notifier).state = true;

    // Refresh the promotional banners provider
    // ignore: unused_result — awaited for completion; the value is not needed.
    await ref.refresh(promotionalBannersProvider.future);
    // clearCache() above drops every placement, so the mid strip has to be
    // refetched too or it renders from a cache that no longer exists.
    // ignore: unused_result — awaited for completion; the value is not needed.
    await ref.refresh(midBannersProvider.future);
  };
});
