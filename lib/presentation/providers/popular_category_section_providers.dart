// lib/presentation/providers/popular_category_section_providers.dart
// Completely separated providers for each section to avoid any state mixing

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/network/api_client.dart';
import '../../data/models/popular_category_models.dart';
import '../../data/repositories/popular_category_repository.dart';
import 'launch_flow_provider.dart';
import 'outlet_provider.dart';

// ============================================
// SECTION 2 - Completely Isolated
// ============================================

final section2CacheManagerProvider = Provider<DefaultCacheManager>((ref) {
  return DefaultCacheManager();
});

final section2RepositoryProvider = Provider<PopularCategoryRepository>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final cacheManager = ref.watch(section2CacheManagerProvider);
  return PopularCategoryRepository(
    apiClient: apiClient,
    logger: ref.watch(loggerProvider),
    cacheManager: cacheManager,
  );
});

final section2RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection2Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section2RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section2RefreshFlagProvider);
  
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      return repository.getPopularCategories(
        sectionId: 2,
        departmentId: "1",
        storeCode: outlet.storeCode,
        forceRefresh: forceRefresh,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

final section2RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section2RepositoryProvider);
    await repository.clearCache();
    ref.read(section2RefreshFlagProvider.notifier).state = true;
    await ref.refresh(popularCategorySection2Provider.future);
    ref.read(section2RefreshFlagProvider.notifier).state = false;
  };
});

// ============================================
// SECTION 3 - Completely Isolated
// ============================================

final section3CacheManagerProvider = Provider<DefaultCacheManager>((ref) {
  return DefaultCacheManager();
});

final section3RepositoryProvider = Provider<PopularCategoryRepository>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final cacheManager = ref.watch(section3CacheManagerProvider);
  return PopularCategoryRepository(
    apiClient: apiClient,
    logger: ref.watch(loggerProvider),
    cacheManager: cacheManager,
  );
});

final section3RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection3Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section3RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section3RefreshFlagProvider);
  
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      return repository.getPopularCategories(
        sectionId: 3,
        departmentId: "1",
        storeCode: outlet.storeCode,
        forceRefresh: forceRefresh,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

final section3RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section3RepositoryProvider);
    await repository.clearCache();
    ref.read(section3RefreshFlagProvider.notifier).state = true;
    await ref.refresh(popularCategorySection3Provider.future);
    ref.read(section3RefreshFlagProvider.notifier).state = false;
  };
});

// ============================================
// SECTION 4 - Completely Isolated
// ============================================

final section4CacheManagerProvider = Provider<DefaultCacheManager>((ref) {
  return DefaultCacheManager();
});

final section4RepositoryProvider = Provider<PopularCategoryRepository>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final cacheManager = ref.watch(section4CacheManagerProvider);
  return PopularCategoryRepository(
    apiClient: apiClient,
    logger: ref.watch(loggerProvider),
    cacheManager: cacheManager,
  );
});

final section4RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection4Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section4RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section4RefreshFlagProvider);
  
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      return repository.getPopularCategories(
        sectionId: 4,
        departmentId: "1",
        storeCode: outlet.storeCode,
        forceRefresh: forceRefresh,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

final section4RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section4RepositoryProvider);
    await repository.clearCache();
    ref.read(section4RefreshFlagProvider.notifier).state = true;
    await ref.refresh(popularCategorySection4Provider.future);
    ref.read(section4RefreshFlagProvider.notifier).state = false;
  };
});

// ============================================
// SECTION 5 - Completely Isolated
// ============================================

final section5CacheManagerProvider = Provider<DefaultCacheManager>((ref) {
  return DefaultCacheManager();
});

final section5RepositoryProvider = Provider<PopularCategoryRepository>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final cacheManager = ref.watch(section5CacheManagerProvider);
  return PopularCategoryRepository(
    apiClient: apiClient,
    logger: ref.watch(loggerProvider),
    cacheManager: cacheManager,
  );
});

final section5RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection5Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section5RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section5RefreshFlagProvider);
  
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      return repository.getPopularCategories(
        sectionId: 5,
        departmentId: "1",
        storeCode: outlet.storeCode,
        forceRefresh: forceRefresh,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

final section5RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section5RepositoryProvider);
    await repository.clearCache();
    ref.read(section5RefreshFlagProvider.notifier).state = true;
    await ref.refresh(popularCategorySection5Provider.future);
    ref.read(section5RefreshFlagProvider.notifier).state = false;
  };
});

// ============================================
// COMBINED REFRESH - Sequential to avoid race conditions
// ============================================

final allSectionsRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Refresh sequentially to avoid any race conditions
    await ref.read(section2RefreshProvider)();
    await ref.read(section3RefreshProvider)();
    await ref.read(section4RefreshProvider)();
    await ref.read(section5RefreshProvider)();
  };
});
