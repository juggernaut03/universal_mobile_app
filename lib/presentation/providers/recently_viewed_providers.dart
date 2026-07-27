// lib/presentation/providers/recently_viewed_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_model.dart';
import '../../data/services/recently_viewed_service.dart';
import '../../di/infrastructure_providers.dart';
import 'outlet_provider.dart';

final recentlyViewedServiceProvider = Provider<RecentlyViewedService>((ref) {
  return RecentlyViewedService(logger: ref.watch(loggerProvider));
});

/// Products the shopper looked at, most recent first.
final recentlyViewedProvider = FutureProvider<List<ProductModel>>((ref) async {
  final outlet = ref.watch(selectedOutletProvider).valueOrNull;
  if (outlet == null) return const [];

  return ref.watch(recentlyViewedServiceProvider).load(storeCode: outlet.storeCode);
});

/// Records a view and refreshes the rail.
///
/// Returned as a callback rather than watched, so the product screen can fire
/// it without subscribing to the history it is writing to.
final recordProductViewProvider = Provider<Future<void> Function(ProductModel)>((ref) {
  return (product) async {
    await ref.read(recentlyViewedServiceProvider).record(product);
    ref.invalidate(recentlyViewedProvider);
  };
});
