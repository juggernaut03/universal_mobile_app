// lib/preview/preview_protocol.dart
//
// The message contract between the admin panel (React, parent frame) and the
// preview (Flutter Web, iframe).
//
// Mirrored in Universal_admin_panel/src/components/flutter-preview/
// preview-protocol.ts. The two files must be changed together — this is a
// wire format between separately deployed builds, so an unknown message must
// be ignored rather than treated as an error, exactly like an unknown section
// type in the feed.

/// Admin → preview.
class PreviewInbound {
  /// Which screen the preview is showing. One preview surface serves every
  /// screen page in the panel, so this is what a page selects on mount.
  static const String setScreen = 'set_screen';

  /// Draft project config — branding, splash settings, colours. Applied to
  /// AppBranding, which is where the real screens read it from, so a colour
  /// typed in the panel reaches the preview the same way it reaches the phone.
  static const String setConfig = 'set_config';

  /// Draft onboarding slides.
  static const String setSlides = 'set_slides';

  /// Full feed replacement. Sent on load and whenever the draft changes.
  static const String setFeed = 'set_feed';

  /// One section changed. Cheaper than [setFeed] and the reason a keystroke
  /// can repaint one widget instead of the page.
  static const String patchSection = 'patch_section';

  /// Store, city, language, user tier, mock profile.
  static const String setContext = 'set_context';

  /// Device frame, safe areas, orientation.
  static const String setDevice = 'set_device';

  /// Clock position, for scheduled sections.
  static const String setClock = 'set_clock';

  /// Offline flag and latency profile.
  static const String setNetwork = 'set_network';

  /// Debug overlay flags.
  static const String setDebug = 'set_debug';

  /// Scroll to a section and flash it.
  static const String selectSection = 'select_section';

  /// Re-run the app's own pull-to-refresh.
  static const String refresh = 'refresh';
}

/// Preview → admin.
class PreviewOutbound {
  /// The Flutter app has booted and is ready for messages. The admin queues
  /// everything until this arrives, because postMessage to a frame that has
  /// not run its main() is silently dropped.
  static const String ready = 'preview_ready';

  /// A section was tapped; the admin highlights the matching row.
  static const String sectionTapped = 'section_tapped';

  /// The shopper-facing app tried to navigate. The preview does not follow it,
  /// so the admin can show where a tap would have led.
  static const String navigation = 'navigation';

  /// Per-section render timings and cache status, for the debug panel.
  static const String metrics = 'metrics';

  /// A section could not be drawn, with the reason.
  static const String sectionError = 'section_error';
}

/// Envelope key every message carries. Namespaced because an iframe receives
/// messages from anything on the page — extensions and dev tooling included —
/// and acting on a stray one would be a security problem, not just a bug.
const String kPreviewChannel = 'bdui-preview';
const int kPreviewProtocolVersion = 1;

/// Re-types an inbound payload as if it had come from `jsonDecode`.
///
/// `dart:html` hands a JS object to Dart as `Map<dynamic, dynamic>`, nested
/// maps included, while every model's `fromJson` is written against the
/// `Map<String, dynamic>` that `jsonDecode` produces. The mismatch does not
/// fail loudly: `HomeFeed.fromJson` filters its sections with
/// `whereType<Map<String, dynamic>>()`, which matches nothing and yields an
/// empty feed — the preview then renders "No sections yet" while the admin is
/// sending a full layout.
///
/// Done once at the transport boundary rather than in each parser, so every
/// message type gets the same shape and the models stay written against JSON.
Object? normalisePayloadValue(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): normalisePayloadValue(entry.value),
    };
  }
  if (value is List) {
    return value.map(normalisePayloadValue).toList();
  }
  return value;
}

/// [normalisePayloadValue] for a message payload, which is always an object.
Map<String, dynamic> normalisePayload(Object? value) {
  final converted = normalisePayloadValue(value);
  return converted is Map<String, dynamic> ? converted : <String, dynamic>{};
}
