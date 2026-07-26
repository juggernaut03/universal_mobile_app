// test/data/product_repository_impl_test.dart
//
// Repository behaviour against fake datasources.
//
// No mocking package is needed: because the datasources are interfaces, a fake
// is a dozen lines. That ease is the argument for the interfaces — the old
// ProductRepository could not be tested at all without a live backend and real
// SharedPreferences.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/exceptions.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/data/datasources/local/product_image_prefetcher.dart';
import 'package:patelmart/data/datasources/local/product_local_datasource.dart';
import 'package:patelmart/data/datasources/remote/product_remote_datasource.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/data/repositories/product_cache_policy.dart';
import 'package:patelmart/data/repositories/product_repository_impl.dart';
import 'package:patelmart/domain/entities/product.dart';

// ---- fakes ----

final class _FakeRemote implements IProductRemoteDataSource {
  List<ProductModel> products = const [];
  ProductModel? single;
  Object? throws;
  int fetchProductsCalls = 0;

  @override
  Future<List<ProductModel>> fetchProducts({
    required String storeCode,
    required String departmentId,
    required String categoryId,
    required String subCategoryId,
  }) async {
    fetchProductsCalls++;
    if (throws != null) throw throws!;
    return products;
  }

  @override
  Future<ProductModel> fetchProductByCode({
    required String code,
    required String storeCode,
  }) async {
    if (throws != null) throw throws!;
    final s = single;
    if (s == null) throw NotFoundException('no product $code');
    return s;
  }
}

final class _FakeLocal implements IProductLocalDataSource {
  CachedProducts? stored;
  DateTime? lastClear;
  int clearCalls = 0;
  int writeCalls = 0;
  Object? readThrows;

  @override
  Future<CachedProducts?> readProducts(String key) async {
    if (readThrows != null) throw readThrows!;
    return stored;
  }

  @override
  Future<void> writeProducts(
      String key, List<ProductModel> products, DateTime now) async {
    writeCalls++;
    stored = CachedProducts(products: products, cachedAt: now);
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    stored = null;
  }

  @override
  Future<DateTime?> readLastClearTime() async => lastClear;

  @override
  Future<void> writeLastClearTime(DateTime now) async => lastClear = now;
}

final class _FakePrefetcher implements IProductImagePrefetcher {
  int prefetchCalls = 0;

  @override
  void prefetch(List<ProductModel> products) => prefetchCalls++;

  @override
  Future<String> cachedUrlFor(String productCode, String originalUrl) async =>
      originalUrl;
}

// ---- helpers ----

ProductModel model({
  String code = 'P1',
  double price = 80,
  int stock = 10,
}) {
  return ProductModel(
    id: 'id-$code',
    pCode: code,
    pcodeImg: '',
    barcode: '',
    productName: 'Product $code',
    productDescription: '',
    packageSize: 500,
    packageUnit: 'g',
    productMrp: 100,
    ourPrice: price,
    brandName: 'Brand',
    storeCode: 'KLK',
    pcodestatus: 'active',
    deptId: 'D1',
    categoryId: 'C1',
    subCategoryId: 'S1',
    storeQuantity: stock,
    maxQuantityAllowed: 5,
  );
}

void main() {
  late _FakeRemote remote;
  late _FakeLocal local;
  late _FakePrefetcher prefetcher;

  // Fixed clock: 09:00, safely past the 02:00 daily reset hour.
  final now = DateTime(2026, 7, 26, 9);

  ProductRepositoryImpl build() => ProductRepositoryImpl(
        remote: remote,
        local: local,
        imagePrefetcher: prefetcher,
        logger: Logger(enableLogs: false),
        policy: const ProductCachePolicy(),
        clock: () => now,
      );

  setUp(() {
    remote = _FakeRemote();
    local = _FakeLocal()..lastClear = now; // reset already done today
    prefetcher = _FakePrefetcher();
  });

  Future<Result<List<Product>>> getProducts(ProductRepositoryImpl repo) =>
      repo.getProducts(
        storeCode: 'KLK',
        departmentId: 'D1',
        categoryId: 'C1',
        subCategoryId: 'S1',
      );

  group('getProducts — cache', () {
    test('serves a fresh cache without hitting the network', () async {
      local.stored = CachedProducts(
        products: [model(code: 'CACHED')],
        cachedAt: now.subtract(const Duration(minutes: 30)),
      );

      final result = await getProducts(build());

      expect(result.valueOrNull!.single.code, 'CACHED');
      expect(remote.fetchProductsCalls, 0);
    });

    test('refetches when the cache is stale', () async {
      local.stored = CachedProducts(
        products: [model(code: 'OLD')],
        cachedAt: now.subtract(const Duration(hours: 5)),
      );
      remote.products = [model(code: 'FRESH')];

      final result = await getProducts(build());

      expect(result.valueOrNull!.single.code, 'FRESH');
      expect(remote.fetchProductsCalls, 1);
    });

    test('caches and prefetches images after a successful fetch', () async {
      remote.products = [model()];

      await getProducts(build());

      expect(local.writeCalls, 1);
      expect(prefetcher.prefetchCalls, 1);
    });

    test('a corrupt cache degrades to a network fetch, not an error', () async {
      local.readThrows = const CacheException('corrupt');
      remote.products = [model(code: 'FRESH')];

      final result = await getProducts(build());

      expect(result.isOk, isTrue);
      expect(remote.fetchProductsCalls, 1);
    });
  });

  group('getProducts — filtering', () {
    test('drops out-of-stock and zero-priced products', () async {
      remote.products = [
        model(code: 'OK'),
        model(code: 'NOSTOCK', stock: 0),
        model(code: 'FREE', price: 0),
      ];

      final result = await getProducts(build());

      expect(result.valueOrNull!.map((p) => p.code), ['OK']);
    });

    test('an empty listing is a success, not a failure', () async {
      remote.products = const [];

      final result = await getProducts(build());

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('getProducts — failure handling', () {
    test('falls back to stale cache when the network fails', () async {
      local.stored = CachedProducts(
        products: [model(code: 'STALE')],
        cachedAt: now.subtract(const Duration(hours: 5)),
      );
      remote.throws = const NetworkException('offline');

      final result = await getProducts(build());

      // Preserves the original repository's offline behaviour.
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.single.code, 'STALE');
    });

    test('returns a typed failure when there is no cache to fall back on',
        () async {
      remote.throws = const NetworkException('offline');

      final result = await getProducts(build());

      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('maps a server error to ServerFailure carrying the status', () async {
      remote.throws = const ServerException('boom', statusCode: 503);

      final result = await getProducts(build());

      final failure = result.failureOrNull;
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 503);
      expect(failure.isRetryable, isTrue);
    });

    test('no exception escapes the data layer', () async {
      remote.throws = StateError('unexpected');

      final result = await getProducts(build());

      expect(result.failureOrNull, isA<UnknownFailure>());
    });
  });

  group('getProductByCode', () {
    test('returns the entity on success', () async {
      remote.single = model(code: 'P9');

      final result = await build()
          .getProductByCode(code: 'P9', storeCode: 'KLK');

      expect(result.valueOrNull!.code, 'P9');
    });

    test('distinguishes not-found from offline — the old null could not',
        () async {
      final notFound =
          await build().getProductByCode(code: 'GONE', storeCode: 'KLK');
      expect(notFound.failureOrNull, isA<NotFoundFailure>());

      remote.throws = const NetworkException('offline');
      final offline =
          await build().getProductByCode(code: 'P1', storeCode: 'KLK');
      expect(offline.failureOrNull, isA<NetworkFailure>());
    });

    test('maps expired auth to AuthFailure requiring re-authentication',
        () async {
      remote.throws = const AuthException('expired');

      final result =
          await build().getProductByCode(code: 'P1', storeCode: 'KLK');

      final failure = result.failureOrNull;
      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).requiresReauthentication, isTrue);
      expect(failure.isRetryable, isFalse);
    });
  });

  group('daily reset', () {
    test('clears the cache when due and records the time', () async {
      local.lastClear = now.subtract(const Duration(days: 1));
      remote.products = [model()];

      await getProducts(build());

      expect(local.clearCalls, 1);
      expect(local.lastClear, now);
    });

    test('does not clear twice in one day', () async {
      local.lastClear = now; // already cleared today
      remote.products = [model()];

      await getProducts(build());

      expect(local.clearCalls, 0);
    });
  });

  group('clearCache', () {
    test('delegates to the local datasource', () async {
      final result = await build().clearCache();

      expect(result.isOk, isTrue);
      expect(local.clearCalls, 1);
    });
  });
}
