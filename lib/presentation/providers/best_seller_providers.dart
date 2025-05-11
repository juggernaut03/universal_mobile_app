// lib/presentation/features/home/providers/best_seller_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../data/models/best_seller_models.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/repositories/best_seller_repository.dart';

// Cache manager provider
final bestSellerCacheManagerProvider = Provider<DefaultCacheManager>((ref) {
  return DefaultCacheManager();
});

// Repository provider
final bestSellerRepositoryProvider = Provider<BestSellerRepository>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final cacheManager = ref.watch(bestSellerCacheManagerProvider);
  
  return BestSellerRepository(
    apiClient: apiClient,
    logger: ref.watch(loggerProvider),
    cacheManager: cacheManager,
  );
});

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
  final repository = ref.watch(bestSellerRepositoryProvider);
  final forceRefresh = ref.watch(refreshBestSellerProvider);
  
  // If force refresh is true, the cache will have already been cleared by the banner provider
  // so we don't need to clear it again here
  
  return repository.getBestSellerProducts(bestSellerId);
});

// Provider for refreshing all best seller data
final bestSellerRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true to trigger cache clearing
    ref.read(refreshBestSellerProvider.notifier).state = true;
    
    // Refresh all the best seller providers
    await Future.wait([
      ref.refresh(bestSellerBannerProvider(1).future),
      ref.refresh(bestSellerProductsProvider(1).future),
      ref.refresh(bestSellerBannerProvider(2).future),
      ref.refresh(bestSellerProductsProvider(2).future),
      ref.refresh(bestSellerBannerProvider(3).future),
      ref.refresh(bestSellerProductsProvider(3).future),
      ref.refresh(bestSellerBannerProvider(4).future),
      ref.refresh(bestSellerProductsProvider(4).future),
    ]);
  };
});