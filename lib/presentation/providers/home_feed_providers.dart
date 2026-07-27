// lib/presentation/providers/home_feed_providers.dart
//
// The server-defined home layout. Which sections exist, and in what order, is
// a backend decision from here on; the app only decides how to draw each type.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_branding.dart';
import '../../core/time/clock.dart';
import '../../data/models/home_feed_models.dart';
import '../../di/repository_providers.dart';
import '../features/home/sections/home_section_registry.dart';
import 'cart_provider.dart';
import 'order_history_provider.dart';
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

/// Which audience bucket this device falls into.
///
/// Matched here rather than server-side on purpose: the feed is public and
/// cacheable, so it cannot vary per user. A section targeted at an audience is
/// still delivered to everyone and filtered on arrival.
final homeAudienceProvider = Provider<Set<String>>((ref) {
  final audiences = <String>{HomeSectionAudience.all};

  if (ref.watch(cartItemsProvider).isNotEmpty) {
    audiences.add(HomeSectionAudience.hasCart);
  }

  final orders = ref.watch(orderHistoryProvider).valueOrNull;
  // Unknown history is treated as "new": showing a first-time shopper a
  // returning-user rail is the worse mistake of the two.
  if (orders != null && orders.isNotEmpty) {
    audiences.add(HomeSectionAudience.returning);
  } else {
    audiences.add(HomeSectionAudience.newUser);
  }

  return audiences;
});

/// Sections this build knows how to draw, in order.
///
/// Three things are filtered here rather than at the render site, so a section
/// that should not appear is absent rather than drawing an empty box:
///   - types this app version predates,
///   - campaigns whose window has closed (the feed is cached and can outlive
///     its own schedule),
///   - sections aimed at an audience this device is not in.
final homeSectionsProvider = Provider<List<HomeSection>>((ref) {
  final feed = ref.watch(homeFeedProvider).valueOrNull ?? HomeFeed.fallback;
  final audiences = ref.watch(homeAudienceProvider);
  // Through the clock, so the admin preview can render a chosen date and see
  // which sections would be live then.
  final now = ref.watch(clockProvider).now();

  return feed.sections
      .where((section) => HomeSectionRegistry.canRender(section.type))
      .where((section) => !feed.sectionHasExpired(section, now: now))
      .where((section) => audiences.contains(section.audience))
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
