// lib/preview/preview_controller.dart
//
// Preview state, and the providers the host reads.
//
// The important property here is granularity. The admin sends a whole feed on
// load but a single section on edit, and [previewSectionProvider] is a family
// selecting one section by id — so a keystroke in a title field rebuilds that
// section's subtree and nothing else. Watching a list of sections instead
// would rebuild every rail on every keystroke, which is the difference
// between a preview that feels live and one that flickers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/home_feed_models.dart';
import 'preview_state.dart';

// ----------------------------------------------------------------------

class PreviewSession {
  final HomeFeed feed;
  final PreviewContext context;
  final DeviceSpec device;
  final NetworkProfile network;
  final DebugFlags debug;

  /// Where "now" sits for scheduling. Null means the real clock.
  final DateTime? clockOverride;

  /// Section the admin has selected, highlighted in the preview.
  final String? selectedSectionId;

  /// Bumped whenever the admin asks for a refresh, so widgets that key off it
  /// refetch without the host having to reach into every provider.
  final int refreshToken;

  const PreviewSession({
    this.feed = const HomeFeed(),
    this.context = const PreviewContext(),
    this.device = DeviceSpec.iphone15Pro,
    this.network = NetworkProfile.unthrottled,
    this.debug = const DebugFlags(),
    this.clockOverride,
    this.selectedSectionId,
    this.refreshToken = 0,
  });

  PreviewSession copyWith({
    HomeFeed? feed,
    PreviewContext? context,
    DeviceSpec? device,
    NetworkProfile? network,
    DebugFlags? debug,
    DateTime? clockOverride,
    bool clearClock = false,
    String? selectedSectionId,
    bool clearSelection = false,
    int? refreshToken,
  }) =>
      PreviewSession(
        feed: feed ?? this.feed,
        context: context ?? this.context,
        device: device ?? this.device,
        network: network ?? this.network,
        debug: debug ?? this.debug,
        clockOverride: clearClock ? null : (clockOverride ?? this.clockOverride),
        selectedSectionId:
            clearSelection ? null : (selectedSectionId ?? this.selectedSectionId),
        refreshToken: refreshToken ?? this.refreshToken,
      );
}

// ----------------------------------------------------------------------

class PreviewController extends StateNotifier<PreviewSession> {
  PreviewController() : super(const PreviewSession());

  void setFeed(HomeFeed feed) => state = state.copyWith(feed: feed);

  /// Replaces one section in place, keeping every other section's identity.
  ///
  /// Rebuilding the list wholesale would work, but every section would be a
  /// new object and every rail would repaint — losing scroll position inside
  /// horizontal lists, and any in-flight image fade.
  void patchSection(HomeSection section) {
    final sections = [...state.feed.sections];
    final index = sections.indexWhere((s) => s.id == section.id);

    if (index == -1) {
      // A newly added section: place it by slot so it lands where the admin
      // dropped it rather than at the end.
      sections.add(section);
      sections.sort((a, b) => a.slot.compareTo(b.slot));
    } else {
      sections[index] = section;
    }

    state = state.copyWith(
      feed: HomeFeed(schemaVersion: state.feed.schemaVersion, sections: sections),
    );
  }

  void setContext(PreviewContext context) => state = state.copyWith(context: context);

  void setDevice(DeviceSpec device) => state = state.copyWith(device: device);

  void setNetwork(NetworkProfile network) => state = state.copyWith(network: network);

  void setDebug(DebugFlags debug) => state = state.copyWith(debug: debug);

  void setClock(DateTime? instant) => state = instant == null
      ? state.copyWith(clearClock: true)
      : state.copyWith(clockOverride: instant);

  void select(String? sectionId) => sectionId == null
      ? state = state.copyWith(clearSelection: true)
      : state = state.copyWith(selectedSectionId: sectionId);

  void refresh() => state = state.copyWith(refreshToken: state.refreshToken + 1);
}

final previewControllerProvider =
    StateNotifierProvider<PreviewController, PreviewSession>(
  (ref) => PreviewController(),
);

// ----------------------------------------------------------------------
// Narrow selectors. Each exists so a widget can watch the one thing it draws.

/// Section ids in render order. Changes only when sections are added, removed
/// or reordered — not when one is edited.
final previewSectionIdsProvider = Provider<List<String>>((ref) {
  final feed = ref.watch(previewControllerProvider.select((s) => s.feed));
  return feed.sections.map((s) => s.id).toList(growable: false);
});

/// One section by id. This is what makes a single-widget repaint possible.
final previewSectionProvider = Provider.family<HomeSection?, String>((ref, id) {
  final feed = ref.watch(previewControllerProvider.select((s) => s.feed));
  for (final section in feed.sections) {
    if (section.id == id) return section;
  }
  return null;
});

final previewDeviceProvider = Provider<DeviceSpec>(
  (ref) => ref.watch(previewControllerProvider.select((s) => s.device)),
);

final previewDebugProvider = Provider<DebugFlags>(
  (ref) => ref.watch(previewControllerProvider.select((s) => s.debug)),
);

final previewSelectionProvider = Provider<String?>(
  (ref) => ref.watch(previewControllerProvider.select((s) => s.selectedSectionId)),
);

final previewNetworkProvider = Provider<NetworkProfile>(
  (ref) => ref.watch(previewControllerProvider.select((s) => s.network)),
);
