// lib/presentation/providers/promotional_banner_providers.dart
//
// Home-screen promotional banners. Moved out of promotional_banner_widget.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/banner_service.dart';
import '../../di/infrastructure_providers.dart';
import '../../di/service_providers.dart';
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

// Provider for refreshing promotional banners manually
final promotionalBannerRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true to trigger cache clearing
    ref.read(refreshPromotionalBannersProvider.notifier).state = true;
    
    // Refresh the promotional banners provider
    await ref.refresh(promotionalBannersProvider.future);
  };
});
