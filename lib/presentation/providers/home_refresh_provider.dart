// lib/presentation/providers/home_refresh_provider.dart
// Optional unified provider for better organization

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/features/home/widgets/promotional_banner_widget.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import 'package:patelmart/presentation/providers/popular_category_providers.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/features/home/widgets/seasonal_picks_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/seasonal_category_widget.dart';

// Provider to track overall home screen refresh state
final homeScreenRefreshStateProvider = StateProvider<bool>((ref) => false);

// Provider to track refresh timestamp for rate limiting
final lastRefreshTimestampProvider = StateProvider<DateTime?>((ref) => null);

// Unified refresh provider that handles all home screen components
final unifiedHomeRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      // Rate limiting: Prevent refreshes within 3 seconds
      final lastRefresh = ref.read(lastRefreshTimestampProvider);
      final now = DateTime.now();
      
      if (lastRefresh != null && now.difference(lastRefresh).inSeconds < 3) {
        ref.read(loggerProvider).log('Refresh rate limited - too frequent');
        return;
      }
      
      // Set loading state and timestamp
      ref.read(homeScreenRefreshStateProvider.notifier).state = true;
      ref.read(lastRefreshTimestampProvider.notifier).state = now;
      
      ref.read(loggerProvider).log('Starting unified home screen refresh');
      
      // Execute all refresh operations in parallel
      final refreshOperations = <Future<void>>[];
      
      // 1. Best Seller sections (1-4)
      refreshOperations.add(
        ref.read(bestSellerRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Best seller refresh failed: $e');
        })
      );
      
      // 2. Popular Categories (1-5)
      refreshOperations.add(
        ref.read(popularCategoryRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Popular categories refresh failed: $e');
        })
      );
      
      // 3. Promotional Banner
      refreshOperations.add(
        ref.read(promotionalBannerRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Promotional banner refresh failed: $e');
        })
      );
      
      // 4. Seasonal Picks
      refreshOperations.add(
        _refreshSeasonalPicksUnified(ref as WidgetRef).catchError((e) {
          ref.read(loggerProvider).error('Seasonal picks refresh failed: $e');
        })
      );
      
      // 5. Seasonal Categories - using the provider refresh
      refreshOperations.add(
        ref.read(seasonalCategoryRefreshProvider)().catchError((e) {
          ref.read(loggerProvider).error('Seasonal categories refresh failed: $e');
        })
      );
      
      // Wait for all operations to complete
      await Future.wait(refreshOperations);
      
      ref.read(loggerProvider).log('Unified home screen refresh completed successfully');
      
    } catch (e) {
      ref.read(loggerProvider).error('Unified home refresh failed: $e');
      rethrow;
    } finally {
      // Always reset loading state
      ref.read(homeScreenRefreshStateProvider.notifier).state = false;
    }
  };
});

// Helper function for seasonal picks refresh
Future<void> _refreshSeasonalPicksUnified(WidgetRef ref) async {
  final outletAsync = ref.read(selectedOutletProvider);
  
  return outletAsync.when(
    data: (outlet) async {
      if (outlet != null) {
        await Future.wait([
          ref.refresh(bannerProvider(outlet.storeCode).future),
          ref.refresh(categoriesProvider(outlet.storeCode).future),
        ]);
      }
    },
    loading: () => Future.value(),
    error: (_, __) => Future.value(),
  );
}

// Provider to get refresh statistics
final homeRefreshStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final isRefreshing = ref.watch(homeScreenRefreshStateProvider);
  final lastRefresh = ref.watch(lastRefreshTimestampProvider);
  
  return {
    'isRefreshing': isRefreshing,
    'lastRefresh': lastRefresh,
    'canRefresh': lastRefresh == null || 
                  DateTime.now().difference(lastRefresh).inSeconds >= 3,
  };
});

// Provider to check if any home screen component is loading
final homeScreenLoadingProvider = Provider<bool>((ref) {
  // Check if unified refresh is active
  final isUnifiedRefreshing = ref.watch(homeScreenRefreshStateProvider);
  if (isUnifiedRefreshing) return true;
  
  // Check individual component loading states
  final bestSellerLoading = ref.watch(bestSellerBannerProvider(1)).isLoading ||
                           ref.watch(bestSellerBannerProvider(2)).isLoading ||
                           ref.watch(bestSellerBannerProvider(3)).isLoading ||
                           ref.watch(bestSellerBannerProvider(4)).isLoading;
  
  final popularCategoryLoading = ref.watch(popularCategoryProvider(1)).isLoading ||
                                ref.watch(popularCategoryProvider(2)).isLoading ||
                                ref.watch(popularCategoryProvider(3)).isLoading ||
                                ref.watch(popularCategoryProvider(4)).isLoading ||
                                ref.watch(popularCategoryProvider(5)).isLoading;
  
  final promotionalBannerLoading = ref.watch(promotionalBannersProvider).isLoading;
  
  // Check seasonal picks loading
  final outletAsync = ref.watch(selectedOutletProvider);
  final seasonalLoading = outletAsync.when(
    data: (outlet) {
      if (outlet != null) {
        return ref.watch(bannerProvider(outlet.storeCode)).isLoading ||
               ref.watch(categoriesProvider(outlet.storeCode)).isLoading;
      }
      return false;
    },
    loading: () => false,
    error: (_, __) => false,
  );
  
  return bestSellerLoading || popularCategoryLoading || promotionalBannerLoading || seasonalLoading;
});

// Provider for refresh button state
final refreshButtonStateProvider = Provider<RefreshButtonState>((ref) {
  final stats = ref.watch(homeRefreshStatsProvider);
  final isLoading = ref.watch(homeScreenLoadingProvider);
  
  return RefreshButtonState(
    isLoading: isLoading,
    canRefresh: stats['canRefresh'] as bool,
    isRefreshing: stats['isRefreshing'] as bool,
    lastRefresh: stats['lastRefresh'] as DateTime?,
  );
});

// Data class for refresh button state
class RefreshButtonState {
  final bool isLoading;
  final bool canRefresh;
  final bool isRefreshing;
  final DateTime? lastRefresh;
  
  const RefreshButtonState({
    required this.isLoading,
    required this.canRefresh,
    required this.isRefreshing,
    this.lastRefresh,
  });
  
  bool get shouldShowLoading => isLoading || isRefreshing;
  bool get isEnabled => canRefresh && !shouldShowLoading;
  
  String get tooltipText {
    if (shouldShowLoading) return 'Refreshing...';
    if (!canRefresh) return 'Please wait before refreshing again';
    return 'Refresh home screen';
  }
}