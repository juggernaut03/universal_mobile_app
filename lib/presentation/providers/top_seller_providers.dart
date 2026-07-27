// lib/presentation/providers/top_seller_providers.dart
//
// Top-seller rails for the home screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/home_feed_models.dart';
import '../../di/repository_providers.dart';
import 'home_feed_providers.dart';
import 'outlet_provider.dart';

/// Top-seller sections for the selected outlet.
///
/// Served from the home feed when it carries them, so the feed path costs no
/// extra request; the legacy path falls through to the endpoint.
final topSellerSectionsProvider = FutureProvider<List<HomeSection>>((ref) async {
  final outlet = ref.watch(selectedOutletProvider).valueOrNull;
  if (outlet == null) return const [];

  final feed = ref.watch(homeFeedProvider).valueOrNull;
  if (feed != null) {
    final fromFeed =
        feed.sections.where((s) => s.sourceCollection == HomeSectionSource.topSellers).toList();
    if (fromFeed.isNotEmpty) return fromFeed;
  }

  return ref.watch(topSellerRepositoryProvider).getSections(outlet.storeCode);
});

/// Re-fetches the rails, for the home screen's pull-to-refresh.
final topSellerRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // ignore: unused_result — awaited for completion; the value is not needed.
    await ref.refresh(topSellerSectionsProvider.future);
  };
});
