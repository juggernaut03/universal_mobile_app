// lib/presentation/providers/popular_category_section_providers.dart
// Completely separated providers for each section to avoid any state mixing

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/popular_category_models.dart';
import 'outlet_provider.dart';
import '../../di/repository_providers.dart';

// ============================================
// SECTION 2 - Completely Isolated
// ============================================


/// Alias of the shared repository. Sections 2-5 each declared their own
/// instance with its own DefaultCacheManager; that cache manager is a
/// singleton, so the four were never actually isolated.
final section2RepositoryProvider = popularCategoryRepositoryProvider;

final section2RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection2Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section2RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section2RefreshFlagProvider);

  final outlet = outletAsync.valueOrNull;
  if (outlet == null) {
    // Outlet not yet available - return empty rather than throwing
    return PopularCategoryResponse.empty();
  }
  return repository.getPopularCategories(
    sectionId: 2,
    departmentId: "1",
    storeCode: outlet.storeCode,
    forceRefresh: forceRefresh,
  );
});

final section2RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section2RepositoryProvider);
    await repository.clearCache();
    ref.read(section2RefreshFlagProvider.notifier).state = true;
    final future2 = ref.refresh(popularCategorySection2Provider.future);
    await future2;
    ref.read(section2RefreshFlagProvider.notifier).state = false;
  };
});

// ============================================
// SECTION 3 - Completely Isolated
// ============================================


/// Alias of the shared repository. Sections 2-5 each declared their own
/// instance with its own DefaultCacheManager; that cache manager is a
/// singleton, so the four were never actually isolated.
final section3RepositoryProvider = popularCategoryRepositoryProvider;

final section3RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection3Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section3RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section3RefreshFlagProvider);

  final outlet = outletAsync.valueOrNull;
  if (outlet == null) {
    return PopularCategoryResponse.empty();
  }
  return repository.getPopularCategories(
    sectionId: 3,
    departmentId: "1",
    storeCode: outlet.storeCode,
    forceRefresh: forceRefresh,
  );
});

final section3RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section3RepositoryProvider);
    await repository.clearCache();
    ref.read(section3RefreshFlagProvider.notifier).state = true;
    final future3 = ref.refresh(popularCategorySection3Provider.future);
    await future3;
    ref.read(section3RefreshFlagProvider.notifier).state = false;
  };
});

// ============================================
// SECTION 4 - Completely Isolated
// ============================================


/// Alias of the shared repository. Sections 2-5 each declared their own
/// instance with its own DefaultCacheManager; that cache manager is a
/// singleton, so the four were never actually isolated.
final section4RepositoryProvider = popularCategoryRepositoryProvider;

final section4RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection4Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section4RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section4RefreshFlagProvider);

  final outlet = outletAsync.valueOrNull;
  if (outlet == null) {
    return PopularCategoryResponse.empty();
  }
  return repository.getPopularCategories(
    sectionId: 4,
    departmentId: "1",
    storeCode: outlet.storeCode,
    forceRefresh: forceRefresh,
  );
});

final section4RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section4RepositoryProvider);
    await repository.clearCache();
    ref.read(section4RefreshFlagProvider.notifier).state = true;
    final future4 = ref.refresh(popularCategorySection4Provider.future);
    await future4;
    ref.read(section4RefreshFlagProvider.notifier).state = false;
  };
});

// ============================================
// SECTION 5 - Completely Isolated
// ============================================


/// Alias of the shared repository. Sections 2-5 each declared their own
/// instance with its own DefaultCacheManager; that cache manager is a
/// singleton, so the four were never actually isolated.
final section5RepositoryProvider = popularCategoryRepositoryProvider;

final section5RefreshFlagProvider = StateProvider<bool>((ref) => false);

final popularCategorySection5Provider = FutureProvider<PopularCategoryResponse>((ref) async {
  final repository = ref.watch(section5RepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.read(section5RefreshFlagProvider);

  final outlet = outletAsync.valueOrNull;
  if (outlet == null) {
    return PopularCategoryResponse.empty();
  }
  return repository.getPopularCategories(
    sectionId: 5,
    departmentId: "1",
    storeCode: outlet.storeCode,
    forceRefresh: forceRefresh,
  );
});

final section5RefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(section5RepositoryProvider);
    await repository.clearCache();
    ref.read(section5RefreshFlagProvider.notifier).state = true;
    final future5 = ref.refresh(popularCategorySection5Provider.future);
    await future5;
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
