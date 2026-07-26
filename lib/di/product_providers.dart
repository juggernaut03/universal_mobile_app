// lib/di/product_providers.dart
//
// Composition root — the Product slice (Phase 2 reference implementation).
//
// Shows the wiring shape every later feature copies:
//   datasources -> repository impl -> domain interface -> use cases
//
// Note what the UI is given: only the use case providers. It cannot reach
// ProductRepositoryImpl or either datasource, because nothing exposes them as
// a concrete type — `productRepositoryProvider` is typed to the domain
// interface, so the compiler prevents a screen from calling an implementation
// detail.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/product_image_prefetcher.dart';
import '../data/datasources/local/product_local_datasource.dart';
import '../data/datasources/remote/product_remote_datasource.dart';
import '../data/repositories/product_cache_policy.dart';
import '../data/repositories/product_repository_impl.dart';
import '../domain/repositories/i_product_repository.dart';
import '../domain/usecases/product/get_product_by_code.dart';
import '../domain/usecases/product/get_products.dart';
import 'infrastructure_providers.dart';

// ---- datasources ----

final productRemoteDataSourceProvider = Provider<IProductRemoteDataSource>(
  (ref) => ProductRemoteDataSource(client: ref.watch(httpClientProvider)),
);

final productLocalDataSourceProvider = Provider<IProductLocalDataSource>(
  (ref) => ProductLocalDataSource(prefs: ref.watch(sharedPreferencesProvider)),
);

final productImagePrefetcherProvider = Provider<IProductImagePrefetcher>(
  (ref) => ProductImagePrefetcher(
    cacheManager: ref.watch(cacheManagerProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// Cache freshness and daily-reset rules.
///
/// Exposed as its own provider so a build flavour or a test can substitute a
/// different policy without touching the repository.
final productCachePolicyProvider = Provider<ProductCachePolicy>(
  (ref) => const ProductCachePolicy(),
);

// ---- repository ----

/// Typed to the DOMAIN interface, never the implementation. This is what makes
/// the dependency rule enforceable rather than merely documented.
final productRepositoryProvider = Provider<IProductRepository>(
  (ref) => ProductRepositoryImpl(
    remote: ref.watch(productRemoteDataSourceProvider),
    local: ref.watch(productLocalDataSourceProvider),
    imagePrefetcher: ref.watch(productImagePrefetcherProvider),
    policy: ref.watch(productCachePolicyProvider),
    logger: ref.watch(loggerProvider),
  ),
);

// ---- use cases ----
//
// The only product entry points the presentation layer may use.

final getProductsUseCaseProvider = Provider<GetProducts>(
  (ref) => GetProducts(ref.watch(productRepositoryProvider)),
);

final getProductByCodeUseCaseProvider = Provider<GetProductByCode>(
  (ref) => GetProductByCode(ref.watch(productRepositoryProvider)),
);
