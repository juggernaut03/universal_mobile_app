// lib/presentation/providers/home_feed_providers.dart
//
// The server-defined home layout. Which sections exist, and in what order, is
// a backend decision from here on; the app only decides how to draw each type.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_branding.dart';
import '../../data/models/home_feed_models.dart';
import '../../di/repository_providers.dart';
import '../features/home/sections/home_section_registry.dart';
import 'outlet_provider.dart';

/// Whether this tenant renders home from the feed.
///
/// Rollout switch: off means the previously hardcoded layout, which is still
/// compiled in. Flipping it is a config edit, not a release.
final homeFeedEnabledProvider = Provider<bool>((ref) {
  return AppBranding.instance.homeFeedEnabled;
});

final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final storeCode = ref.watch(selectedOutletProvider).valueOrNull?.storeCode;

  // Home builds before a store is chosen; the shipped layout is the right
  // answer until there is a store to ask about.
  if (storeCode == null || storeCode.isEmpty) return HomeFeed.fallback;

  return ref.watch(homeFeedRepositoryProvider).getFeed(storeCode: storeCode);
});

/// Sections this build knows how to draw, in order.
///
/// Unknown types are dropped here rather than at the render site, so a section
/// added to the backend before this app version existed is simply absent
/// instead of throwing.
final homeSectionsProvider = Provider<List<HomeSection>>((ref) {
  final feed = ref.watch(homeFeedProvider).valueOrNull ?? HomeFeed.fallback;

  return feed.sections
      .where((section) => HomeSectionRegistry.canRender(section.type))
      .toList(growable: false);
});

/// Refreshes the layout itself. Section *content* is refreshed by the existing
/// per-section refresh providers.
final homeFeedRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // ignore: unused_result — awaited for completion; the value is not needed.
    await ref.refresh(homeFeedProvider.future);
  };
});
