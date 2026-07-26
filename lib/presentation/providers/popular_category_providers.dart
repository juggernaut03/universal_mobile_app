// lib/presentation/providers/popular_category_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/popular_category_models.dart';
import 'outlet_provider.dart';
import '../../di/repository_providers.dart';

// Cache manager provider (reuse from category providers if available)

// Repository provider

// Provider to force refresh popular categories (ignoring cache)
final refreshPopularCategoryProvider = StateProvider<bool>((ref) => false);

// Provider for popular categories with family parameter for different section IDs (1-5)
// Provider for popular categories with family parameter for different section IDs (1-5)
final popularCategoryProvider = FutureProvider.family<PopularCategoryResponse, int>((ref, sectionId) async {
  if (sectionId < 1 || sectionId > 5) {
    throw Exception('Section ID must be between 1 and 5');
  }
  
  final repository = ref.watch(popularCategoryRepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  // Use read instead of watch to avoid double-rebuild when we reset the flag
  final forceRefresh = ref.read(refreshPopularCategoryProvider);
  
  // Handle the AsyncValue properly
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      // Default to department ID 1 if not specified
      const defaultDepartmentId = "1";
      
      // Pass forceRefresh to repository to bypass cache when refreshing
      return repository.getPopularCategories(
        sectionId: sectionId,
        departmentId: defaultDepartmentId,
        storeCode: outlet.storeCode,
        forceRefresh: forceRefresh,  // This ensures API is hit on refresh
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// Provider for refreshing all popular category data
final popularCategoryRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // 1. Clear the SharedPreferences cache FIRST to ensure fresh data
    final repository = ref.read(popularCategoryRepositoryProvider);
    await repository.clearCache();
    
    // 2. Set the refresh flag to true to bypass any remaining cache
    ref.read(refreshPopularCategoryProvider.notifier).state = true;
    
    // 3. Refresh all the popular category providers
    // This will trigger a re-fetch because ref.refresh forces invalidation
    await Future.wait([
      ref.refresh(popularCategoryProvider(1).future),
      ref.refresh(popularCategoryProvider(2).future),
      ref.refresh(popularCategoryProvider(3).future),
      ref.refresh(popularCategoryProvider(4).future),
      ref.refresh(popularCategoryProvider(5).future),
    ]);

    // 4. Reset the refresh flag
    ref.read(refreshPopularCategoryProvider.notifier).state = false;
  };
});