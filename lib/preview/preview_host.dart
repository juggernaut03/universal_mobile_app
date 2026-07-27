// lib/preview/preview_host.dart
//
// The preview surface.
//
// This file deliberately contains no section rendering of its own. Every
// widget on screen comes from HomeSectionRegistry — the same registry the
// shipping app uses — so the preview cannot drift from production by
// construction. If a rail looks wrong here, it is wrong on the phone.
//
// What this file does own is everything *around* the app: the device frame,
// the safe-area insets, selection highlighting, and the debug overlay.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../data/models/home_feed_models.dart';
import '../presentation/features/home/sections/home_section_registry.dart';
import 'preview_bridge.dart';
import 'preview_controller.dart';
import 'preview_state.dart';

// ----------------------------------------------------------------------

class PreviewHost extends ConsumerStatefulWidget {
  const PreviewHost({super.key});

  @override
  ConsumerState<PreviewHost> createState() => _PreviewHostState();
}

class _PreviewHostState extends ConsumerState<PreviewHost> {
  final ScrollController _scroll = ScrollController();

  /// One key per section, so the admin's "select this row" can scroll to it.
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    ref.read(previewBridgeProvider).start();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _sectionKeys.putIfAbsent(id, () => GlobalKey());

  /// Brings a section into view when the admin selects its row.
  ///
  /// Deferred to after the frame because the selection may arrive in the same
  /// message batch that created the section, and a key with no context yet
  /// cannot be scrolled to.
  void _revealSelected(String? id) {
    if (id == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _sectionKeys[id]?.currentContext;
      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(previewDeviceProvider);

    ref.listen<String?>(previewSelectionProvider, (_, next) => _revealSelected(next));

    // The frame is drawn at the device's logical size and then scaled to fit
    // whatever the admin's iframe is, rather than laid out at the iframe's
    // size. That distinction is the whole point: the app must believe it is
    // 393 points wide, or every breakpoint and text-wrap decision differs
    // from the phone.
    return Material(
      color: Colors.transparent,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: _DeviceFrame(
            device: device,
            child: _PreviewViewport(
              device: device,
              scroll: _scroll,
              keyFor: _keyFor,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------

/// The phone shell: rounded corners, and the status/home indicators that sit
/// over the app rather than in it.
class _DeviceFrame extends StatelessWidget {
  final DeviceSpec device;
  final Widget child;

  const _DeviceFrame({required this.device, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: device.size.width,
      height: device.size.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(device.cornerRadius),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (device.padding.top >= 40) _DynamicIsland(device: device),
          if (device.padding.bottom >= 20) _HomeIndicator(device: device),
        ],
      ),
    );
  }
}

class _DynamicIsland extends StatelessWidget {
  final DeviceSpec device;

  const _DynamicIsland({required this.device});

  @override
  Widget build(BuildContext context) {
    // Only iPhone draws a pill; the Android devices get a small camera dot.
    final isPill = device.id.startsWith('iphone');

    return Positioned(
      top: isPill ? 11 : 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: isPill ? 125 : 12,
          height: isPill ? 36 : 12,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(isPill ? 18 : 6),
          ),
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  final DeviceSpec device;

  const _HomeIndicator({required this.device});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 134,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------

/// The app's own viewport: correct MediaQuery, correct insets, real sections.
class _PreviewViewport extends ConsumerWidget {
  final DeviceSpec device;
  final ScrollController scroll;
  final GlobalKey Function(String) keyFor;

  const _PreviewViewport({
    required this.device,
    required this.scroll,
    required this.keyFor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(previewSectionIdsProvider);

    // Supplying MediaQuery rather than inheriting the browser's is what makes
    // SafeArea, text scaling and every size-dependent branch behave as they do
    // on the device.
    return MediaQuery(
      data: MediaQueryData(
        size: device.size,
        devicePixelRatio: device.devicePixelRatio,
        padding: device.padding,
        viewPadding: device.padding,
        textScaler: TextScaler.noScaling,
        platformBrightness: Theme.of(context).brightness,
      ),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ids.isEmpty
            ? const _EmptyLayout()
            : ListView.builder(
                controller: scroll,
                padding: EdgeInsets.only(
                  top: device.padding.top,
                  bottom: device.padding.bottom + 24,
                ),
                // Built lazily, exactly as the app builds its home list, so
                // what the preview reports about scroll performance is true
                // of the phone as well.
                itemCount: ids.length,
                itemBuilder: (context, index) => _PreviewSection(
                  key: keyFor(ids[index]),
                  sectionId: ids[index],
                ),
              ),
      ),
    );
  }
}

class _EmptyLayout extends StatelessWidget {
  const _EmptyLayout();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'No sections yet.\nAdd one to see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black45),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------

/// One section, watched by id.
///
/// This is the unit of repaint: editing a title rebuilds the matching
/// [_PreviewSection] and leaves every sibling untouched, including the scroll
/// offset of any horizontal rail inside them.
class _PreviewSection extends ConsumerWidget {
  final String sectionId;

  const _PreviewSection({super.key, required this.sectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(previewSectionProvider(sectionId));
    if (section == null) return const SizedBox.shrink();

    final debug = ref.watch(previewDebugProvider);
    final selected = ref.watch(previewSelectionProvider) == sectionId;

    final stopwatch = Stopwatch()..start();
    final rendered = HomeSectionRegistry.build(context, ref, section);
    stopwatch.stop();

    if (debug.enabled && debug.showTimings) {
      // Reported after the frame: sending during build would post a message
      // from inside a paint, and the admin's handler could re-enter.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(previewBridgeProvider).reportMetrics(
              sectionId: sectionId,
              buildMicros: stopwatch.elapsedMicroseconds,
            );
      });
    }

    return _SelectableSection(
      section: section,
      selected: selected,
      debug: debug,
      child: rendered,
    );
  }
}

/// Wraps a section with tap reporting, the selection highlight and the debug
/// chrome — none of which the section itself should have to know about.
class _SelectableSection extends ConsumerWidget {
  final HomeSection section;
  final bool selected;
  final DebugFlags debug;
  final Widget child;

  const _SelectableSection({
    required this.section,
    required this.selected,
    required this.debug,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // deferToChild so the section's own taps still work exactly as they do
        // in the app: this observes the gesture, it does not consume it.
        Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerUp: (_) => ref.read(previewBridgeProvider).reportTap(
                sectionId: section.id,
                sectionType: section.type,
              ),
          child: child,
        ),

        if (selected)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: AppColors.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),

        if (debug.enabled && debug.showIds)
          Positioned(
            top: 2,
            left: 2,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                color: Colors.black.withValues(alpha: 0.65),
                child: Text(
                  '${section.type} · ${section.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
