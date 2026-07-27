// lib/presentation/providers/best_seller_providers.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/best_seller_models.dart';
import '../../../../data/models/product_model.dart';
import '../../di/repository_providers.dart';
import '../../data/models/home_feed_mappers.dart';
import '../../data/models/home_feed_models.dart';
import 'home_feed_providers.dart';

// Cache manager provider

// Repository provider

// Provider to force refresh best seller data (ignoring cache)
final refreshBestSellerProvider = StateProvider<bool>((ref) => false);

// Provider for best seller banners with family parameter for different section IDs
final bestSellerBannerProvider = FutureProvider.family<List<BestSellerBanner>, int>((ref, bestSellerId) async {
  final repository = ref.watch(bestSellerRepositoryProvider);
  final forceRefresh = ref.watch(refreshBestSellerProvider);
  
  // If force refresh is true, clear cache before fetching
  if (forceRefresh) {
    await repository.clearCache();
    // Reset the refresh flag (since we're clearing cache for all best sellers at once)
    if (bestSellerId == 1) { // Only reset once to avoid multiple resets
      ref.read(refreshBestSellerProvider.notifier).state = false;
    }
  }
  
  return repository.getBestSellerBanners(bestSellerId);
});

// Provider for best seller products with family parameter for different section IDs
final bestSellerProductsProvider = FutureProvider.family<List<ProductModel>, int>((ref, bestSellerId) async {
  // Served from the home feed when it carries this rail; see the note on
  // promoSectionProvider.
  final fromFeed = ref.watch(homeFeedProvider).valueOrNull
      ?.bySequence(
        HomeSectionType.productRail,
        bestSellerId,
        collection: HomeSectionSource.bestSellers,
      );
  if (fromFeed != null && fromFeed.items.isNotEmpty) {
    return fromFeed.toProducts();
  }

  final repository = ref.watch(bestSellerRepositoryProvider);
  // Subscription kept deliberately: the binding was unused but the
  // watch is what rebuilds this on change.
  ref.watch(refreshBestSellerProvider);
  
  // If force refresh is true, the cache will have already been cleared by the banner provider
  // so we don't need to clear it again here
  
  return repository.getBestSellerProducts(bestSellerId);
});

// NEW: Provider for best seller title with family parameter for different section IDs
final bestSellerTitleProvider = FutureProvider.family<String, int>((ref, bestSellerId) async {
  final fromFeed = ref.watch(homeFeedProvider).valueOrNull
      ?.bySequence(
        HomeSectionType.productRail,
        bestSellerId,
        collection: HomeSectionSource.bestSellers,
      );
  if (fromFeed != null && fromFeed.title.isNotEmpty) return fromFeed.title;

  final repository = ref.watch(bestSellerRepositoryProvider);
  return repository.getBestSellerTitle(bestSellerId);
});

// Provider for background color to ensure it refreshes properly
final bestSellerBackgroundColorProvider = Provider.family<Color, int>((ref, bestSellerId) {
  final bannersAsync = ref.watch(bestSellerBannerProvider(bestSellerId));
  
  return bannersAsync.when(
    data: (banners) {
      if (banners.isNotEmpty && banners[0].backgroundColor.isNotEmpty) {
        try {
          // Remove '#' if present
          String hex = banners[0].backgroundColor.replaceAll('#', '');
          
          // Handle different formats: RGB, RRGGBB, AARRGGBB
          if (hex.length == 3) {
            // RGB format, convert to RRGGBB
            hex = hex.split('').map((c) => '$c$c').join('');
          }
          
          // Add FF for alpha if only RGB or RRGGBB is provided
          if (hex.length == 6) {
            hex = 'FF$hex';
          } else if (hex.length != 8) {
            // If not a valid length, return default color
            return Colors.white;
          }
          
          // Parse the hex string to integer
          return Color(int.parse('0x$hex'));
        } catch (e) {
          // Return default color if any error occurs
          return Colors.white;
        }
      }
      return Colors.white;
    },
    loading: () => Colors.white,
    error: (_, __) => Colors.white,
  );
});

// Provider for refreshing all best seller data
final bestSellerRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true to trigger cache clearing
    ref.read(refreshBestSellerProvider.notifier).state = true;
    
    // Refresh all the best seller providers (including titles)
    await Future.wait([
      ref.refresh(bestSellerBannerProvider(1).future),
      ref.refresh(bestSellerProductsProvider(1).future),
      ref.refresh(bestSellerTitleProvider(1).future),
      ref.refresh(bestSellerBannerProvider(2).future),
      ref.refresh(bestSellerProductsProvider(2).future),
      ref.refresh(bestSellerTitleProvider(2).future),
      ref.refresh(bestSellerBannerProvider(3).future),
      ref.refresh(bestSellerProductsProvider(3).future),
      ref.refresh(bestSellerTitleProvider(3).future),
      ref.refresh(bestSellerBannerProvider(4).future),
      ref.refresh(bestSellerProductsProvider(4).future),
      ref.refresh(bestSellerTitleProvider(4).future),
    ]);
  };
});