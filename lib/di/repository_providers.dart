// lib/di/repository_providers.dart
//
// Composition root — repositories.
//
// Every repository is declared exactly once here. Previously they were spread
// across data/ files, presentation/providers/ files and even screens, which is
// how `productRepositoryProvider` ended up declared in
// `subcategory_providers.dart` and `orderRepositoryProvider` twice with two
// different types.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/address_repository.dart';
import '../data/repositories/base_repository.dart';
import '../data/repositories/best_seller_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/favorites_repository.dart';
import '../data/repositories/fcm_token_repository.dart';
import '../data/repositories/location_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/outlet_repository.dart';
import '../data/repositories/popular_category_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/project_config_repository.dart';
import '../data/repositories/subcategory_repository.dart';
import '../presentation/providers/auth_providers.dart'
    show legacyAuthRepositoryProvider;
import 'infrastructure_providers.dart';
import 'service_providers.dart';

// ---- repositories built on BaseRepository's shared dependencies ----

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final deps = ref.watch(baseRepositoryDependenciesProvider);
  return AddressRepository(
    authManager: deps.authManager,
    apiClient: deps.apiClient,
    logger: deps.logger,
  );
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final deps = ref.watch(baseRepositoryDependenciesProvider);
  return FavoritesRepository(
    authManager: deps.authManager,
    apiClient: deps.apiClient,
    logger: deps.logger,
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final deps = ref.watch(baseRepositoryDependenciesProvider);
  return ProfileRepository(
    authManager: deps.authManager,
    apiClient: deps.apiClient,
    logger: deps.logger,
  );
});

// ---- catalogue ----
//
// These four previously built `ApiClient(logger: ...)` inline — a client with
// no auth manager, so `*WithAuth` calls carried no Authorization header. They
// now use the single configured client.

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    apiClient: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
    cacheManager: ref.watch(cacheManagerProvider),
  );
});

final subcategoryRepositoryProvider = Provider<SubcategoryRepository>((ref) {
  return SubcategoryRepository(
    logger: ref.watch(loggerProvider),
    cacheManager: ref.watch(cacheManagerProvider),
  );
});

final bestSellerRepositoryProvider = Provider<BestSellerRepository>((ref) {
  return BestSellerRepository(
    apiClient: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
    cacheManager: ref.watch(cacheManagerProvider),
  );
});

/// Shared by every popular-category section.
///
/// `popular_category_section_providers.dart` declared four copies of this
/// (`section2RepositoryProvider` … `section5RepositoryProvider`), each with its
/// own `DefaultCacheManager`, commented as "completely isolated to avoid state
/// mixing". The isolation was illusory: `DefaultCacheManager()` is a singleton
/// inside flutter_cache_manager, so all four already shared one disk cache.
final popularCategoryRepositoryProvider =
    Provider<PopularCategoryRepository>((ref) {
  return PopularCategoryRepository(
    apiClient: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
    cacheManager: ref.watch(cacheManagerProvider),
  );
});

// ---- location & outlet ----

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(
    locationService: ref.watch(locationServiceProvider),
    apiService: ref.watch(apiServiceProvider),
    storageService: ref.watch(storageServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});

final outletRepositoryProvider = Provider<OutletRepository>((ref) {
  return OutletRepository(
    apiService: ref.watch(apiServiceProvider),
    storageService: ref.watch(storageServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ---- orders ----

/// Was declared twice: `order_history_provider.dart` as
/// `Provider<OrderRepository>` and `reorder_provider.dart` as an untyped
/// `Provider` — two instances, each with its own `http.Client`, and one erasing
/// the type so consumers got `dynamic`.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    client: ref.watch(httpClientProvider),
    authRepository: ref.watch(legacyAuthRepositoryProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ---- misc ----

final fcmTokenRepositoryProvider = Provider<FcmTokenRepository>((ref) {
  return FcmTokenRepository(
    fcmTokenService: ref.watch(fcmTokenServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});

final projectConfigRepositoryProvider =
    Provider<ProjectConfigRepository>((ref) => ProjectConfigRepository());
