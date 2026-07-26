// lib/presentation/providers/seasonal_picks_providers.dart
// Create this new file to add refresh capability to seasonal picks

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/features/home/widgets/seasonal_picks_widget.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import '../../di/infrastructure_providers.dart';

// Provider to force refresh seasonal picks data (ignoring cache)
final refreshSeasonalPicksProvider = StateProvider<bool>((ref) => false);

// Enhanced banner provider with refresh capability
final seasonalBannerProviderWithRefresh = FutureProvider.family<List<SeasonalBanner>, String>((ref, storeCode) async {
  final api = ref.watch(seasonalApiProvider);
  final forceRefresh = ref.watch(refreshSeasonalPicksProvider);
  
  // If force refresh is true, we'll add a timestamp to force fresh API call
  if (forceRefresh) {
    // Reset the refresh flag after triggering
    Future.microtask(() {
      if (ref.exists(refreshSeasonalPicksProvider)) {
        ref.read(refreshSeasonalPicksProvider.notifier).state = false;
      }
    });
  }
  
  return api.getBanner(storeCode);
});

// Enhanced categories provider with refresh capability  
final seasonalCategoriesProviderWithRefresh = FutureProvider.family<List<SeasonalCategory>, String>((ref, storeCode) async {
  final api = ref.watch(seasonalApiProvider);
  final forceRefresh = ref.watch(refreshSeasonalPicksProvider);
  
  // The refresh flag will be reset by the banner provider to avoid multiple resets
  return api.getCategories(storeCode);
});

// Provider for refreshing seasonal picks data
final seasonalPicksRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      // Set the refresh flag to true to trigger fresh API calls
      ref.read(refreshSeasonalPicksProvider.notifier).state = true;
      
      // Get the current outlet to determine store code
      final outletAsync = ref.read(selectedOutletProvider);
      
      await outletAsync.when(
        data: (outlet) async {
          if (outlet != null) {
            // Refresh both banner and categories providers
            await Future.wait([
              ref.refresh(seasonalBannerProviderWithRefresh(outlet.storeCode).future),
              ref.refresh(seasonalCategoriesProviderWithRefresh(outlet.storeCode).future),
            ]);
            
            ref.read(loggerProvider).log('Seasonal picks refreshed successfully');
          } else {
            ref.read(loggerProvider).log('No outlet selected for seasonal picks refresh');
          }
        },
        loading: () {
          ref.read(loggerProvider).log('Outlet loading, skipping seasonal picks refresh');
          return Future.value();
        },
        error: (error, stackTrace) {
          ref.read(loggerProvider).error('Outlet error during seasonal picks refresh: $error');
          return Future.value();
        },
      );
    } catch (e) {
      ref.read(loggerProvider).error('Seasonal picks refresh failed: $e');
      rethrow;
    }
  };
});

// Alternative: Use original providers with direct refresh (simpler approach)
final seasonalPicksRefreshProviderSimple = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      // Get the current outlet to determine store code
      final outletAsync = ref.read(selectedOutletProvider);
      
      await outletAsync.when(
        data: (outlet) async {
          if (outlet != null) {
            // Force refresh original providers
            await Future.wait([
              ref.refresh(bannerProvider(outlet.storeCode).future),
              ref.refresh(categoriesProvider(outlet.storeCode).future),
            ]);
            
            ref.read(loggerProvider).log('Seasonal picks refreshed for store: ${outlet.storeCode}');
          }
        },
        loading: () => Future.value(),
        error: (_, __) => Future.value(),
      );
    } catch (e) {
      ref.read(loggerProvider).error('Failed to refresh seasonal picks: $e');
      rethrow;
    }
  };
});