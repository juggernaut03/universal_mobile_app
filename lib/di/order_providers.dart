// lib/di/order_providers.dart
//
// Composition root — orders and addresses (Phase 6).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/address_repository_impl.dart';
import '../data/repositories/favorites_repository_impl.dart';
import '../data/repositories/order_repository_impl.dart';
import '../domain/repositories/i_address_repository.dart';
import '../domain/repositories/i_favorites_repository.dart';
import '../domain/repositories/i_order_repository.dart';
import '../domain/usecases/address/save_address.dart';
import '../domain/usecases/order/cancel_order.dart';
import '../domain/usecases/order/get_order_history.dart';
import 'repository_providers.dart';

// ---- repositories (domain-typed) ----

final orderRepositoryDomainProvider = Provider<IOrderRepository>(
  (ref) => OrderRepositoryImpl(delegate: ref.watch(orderRepositoryProvider)),
);

final addressRepositoryDomainProvider = Provider<IAddressRepository>(
  (ref) => AddressRepositoryImpl(delegate: ref.watch(addressRepositoryProvider)),
);

// ---- use cases ----

final getOrderHistoryUseCaseProvider = Provider<GetOrderHistory>(
  (ref) => GetOrderHistory(ref.watch(orderRepositoryDomainProvider)),
);

final cancelOrderUseCaseProvider = Provider<CancelOrder>(
  (ref) => CancelOrder(ref.watch(orderRepositoryDomainProvider)),
);

final saveAddressUseCaseProvider = Provider<SaveAddress>(
  (ref) => SaveAddress(ref.watch(addressRepositoryDomainProvider)),
);

// ---- favourites ----

final favoritesRepositoryDomainProvider = Provider<IFavoritesRepository>(
  (ref) =>
      FavoritesRepositoryImpl(delegate: ref.watch(favoritesRepositoryProvider)),
);
