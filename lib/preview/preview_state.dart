// lib/preview/preview_state.dart
//
// Everything the admin can vary about a preview, as plain values.
//
// Kept separate from the widgets so the whole preview surface can be driven
// from a message and tested without a browser.

import 'package:flutter/material.dart';

// ----------------------------------------------------------------------

/// A device the preview can imitate.
///
/// `padding` is what makes a notch or a dynamic island real: the app already
/// respects `MediaQuery.padding` through `SafeArea`, so supplying it here
/// reproduces the inset without any preview-specific layout code.
class DeviceSpec {
  final String id;
  final String label;
  final Size size;
  final double devicePixelRatio;
  final EdgeInsets padding;
  final double cornerRadius;

  const DeviceSpec({
    required this.id,
    required this.label,
    required this.size,
    this.devicePixelRatio = 3,
    this.padding = EdgeInsets.zero,
    this.cornerRadius = 44,
  });

  static const iphone15Pro = DeviceSpec(
    id: 'iphone_15_pro',
    label: 'iPhone 15 Pro',
    size: Size(393, 852),
    devicePixelRatio: 3,
    // Dynamic island, then the home indicator.
    padding: EdgeInsets.only(top: 59, bottom: 34),
    cornerRadius: 55,
  );

  static const pixel8 = DeviceSpec(
    id: 'pixel_8',
    label: 'Pixel 8',
    size: Size(412, 915),
    devicePixelRatio: 2.625,
    padding: EdgeInsets.only(top: 48, bottom: 24),
    cornerRadius: 28,
  );

  static const galaxyS23 = DeviceSpec(
    id: 'galaxy_s23',
    label: 'Galaxy S23',
    size: Size(360, 780),
    devicePixelRatio: 3,
    padding: EdgeInsets.only(top: 40, bottom: 20),
    cornerRadius: 24,
  );

  static const ipadMini = DeviceSpec(
    id: 'ipad_mini',
    label: 'iPad mini',
    size: Size(744, 1133),
    devicePixelRatio: 2,
    padding: EdgeInsets.only(top: 24, bottom: 20),
    cornerRadius: 22,
  );

  static const all = [iphone15Pro, pixel8, galaxyS23, ipadMini];

  static DeviceSpec byId(String? id) =>
      all.firstWhere((d) => d.id == id, orElse: () => iphone15Pro);

  factory DeviceSpec.fromJson(Map<String, dynamic> json) {
    final base = byId((json['id'] ?? '').toString());
    // The admin may override any dimension — a custom size, or landscape.
    return DeviceSpec(
      id: base.id,
      label: base.label,
      size: Size(
        (json['width'] as num?)?.toDouble() ?? base.size.width,
        (json['height'] as num?)?.toDouble() ?? base.size.height,
      ),
      devicePixelRatio:
          (json['device_pixel_ratio'] as num?)?.toDouble() ?? base.devicePixelRatio,
      padding: base.padding,
      cornerRadius: base.cornerRadius,
    );
  }
}

// ----------------------------------------------------------------------

/// Who is looking, and from where.
///
/// These drive the same providers the real app uses, so an audience-targeted
/// or store-scoped section resolves through production logic rather than a
/// preview approximation of it.
class PreviewContext {
  final String storeCode;
  final String city;
  final String languageCode;

  /// `guest`, `logged_in` or `premium`. Matched against the feed's audience
  /// rules exactly as the device does.
  final String userTier;

  /// Mock customer id, for personalised sections that read history.
  final String? profileId;

  const PreviewContext({
    this.storeCode = '',
    this.city = '',
    this.languageCode = 'en',
    this.userTier = 'guest',
    this.profileId,
  });

  factory PreviewContext.fromJson(Map<String, dynamic> json) => PreviewContext(
        storeCode: (json['store_code'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        languageCode: (json['language_code'] ?? 'en').toString(),
        userTier: (json['user_tier'] ?? 'guest').toString(),
        profileId: json['profile_id']?.toString(),
      );

  PreviewContext copyWith({
    String? storeCode,
    String? city,
    String? languageCode,
    String? userTier,
    String? profileId,
  }) =>
      PreviewContext(
        storeCode: storeCode ?? this.storeCode,
        city: city ?? this.city,
        languageCode: languageCode ?? this.languageCode,
        userTier: userTier ?? this.userTier,
        profileId: profileId ?? this.profileId,
      );
}

// ----------------------------------------------------------------------

/// Simulated network conditions.
///
/// Latency is injected in the API layer rather than faked in the widgets, so
/// what appears during the delay is the app's real loading state — which is
/// the only way a preview can answer "does this look acceptable on 3G".
class NetworkProfile {
  final String id;
  final String label;
  final Duration latency;
  final bool offline;

  const NetworkProfile({
    required this.id,
    required this.label,
    this.latency = Duration.zero,
    this.offline = false,
  });

  static const unthrottled = NetworkProfile(id: 'wifi', label: 'WiFi');
  static const fourG =
      NetworkProfile(id: '4g', label: '4G', latency: Duration(milliseconds: 150));
  static const threeG =
      NetworkProfile(id: '3g', label: '3G', latency: Duration(milliseconds: 700));
  static const offlineProfile =
      NetworkProfile(id: 'offline', label: 'Offline', offline: true);

  static const all = [unthrottled, fourG, threeG, offlineProfile];

  static NetworkProfile byId(String? id) =>
      all.firstWhere((n) => n.id == id, orElse: () => unthrottled);
}

// ----------------------------------------------------------------------

/// What the debug overlay shows. Off by default: the point of the preview is
/// to look like the app, and an overlay that is always on defeats that.
class DebugFlags {
  final bool enabled;
  final bool showIds;
  final bool showTimings;
  final bool showBounds;

  const DebugFlags({
    this.enabled = false,
    this.showIds = true,
    this.showTimings = true,
    this.showBounds = false,
  });

  factory DebugFlags.fromJson(Map<String, dynamic> json) => DebugFlags(
        enabled: json['enabled'] == true,
        showIds: json['show_ids'] != false,
        showTimings: json['show_timings'] != false,
        showBounds: json['show_bounds'] == true,
      );
}
