// lib/data/services/app_icon_service.dart
//
// Switches the launcher icon between variants already baked into this build
// (see android/app/src/main/AndroidManifest.xml's activity-alias entries and
// ios/Runner/Info.plist's CFBundleAlternateIcons) — the same mechanism apps
// like Zomato use to swap icons for a festival/campaign without a Play
// Store or App Store update. The backend only ever names *which* already-
// shipped variant should be showing (Project.config.active_app_icon); it
// never ships new artwork.

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIconService {
  static const MethodChannel _channel = MethodChannel('app_icon_switcher');
  static const String _prefsKey = 'active_app_icon_variant';

  /// Auto-injected by the Flutter tool for every `--flavor` build — not one
  /// of our own dart_defines/*.json entries. Empty for a build with no
  /// flavor at all (there is none of those in this app, but empty is still
  /// treated as "no suffix", same as the pagariya flavor itself).
  static const String _flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');

  /// Known variants. Anything else from the backend is treated as 'default'
  /// rather than failing — an unrecognised value must never leave the app
  /// with no icon at all.
  static const Set<String> knownVariants = {'default', 'festival', 'premium'};

  /// The iOS alternate-icon name Xcode registered for this variant on this
  /// flavor's build (see ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES per
  /// flavor in the Xcode project, and the generated
  /// `AppIcon-<flavor>-<Variant>` asset catalogs). Null for 'default' — iOS
  /// has no separate catalog entry for the primary icon; reverting to it
  /// means passing nil, not a name.
  static String? _iosIconName(String variant) {
    if (variant == 'default') return null;
    final suffix = _flavor.isEmpty || _flavor == 'pagariya' ? '' : '-$_flavor';
    final capitalized = variant[0].toUpperCase() + variant.substring(1);
    return 'AppIcon$suffix-$capitalized';
  }

  /// Applies [variant] only if it differs from the last one this app
  /// instance actually switched to — flipping the enabled activity-alias on
  /// Android (or the alternate icon on iOS) is not free, so this avoids
  /// doing it on every project-config refresh when nothing changed.
  Future<void> applyIfChanged(String? variant) async {
    final normalized = knownVariants.contains(variant) ? variant! : 'default';

    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getString(_prefsKey);
      if (current == normalized) return;

      await _channel.invokeMethod('setIcon', {
        // Android reads this; a flavor with no matching alias (see
        // AndroidManifest.xml) simply has nothing to switch to.
        'variant': normalized,
        // iOS reads this instead; null/empty means "back to the primary
        // icon". A flavor with no matching alternate-icon catalog (only
        // pagariya, myneedmart and shreemegamart have one so far) fails
        // this call, which the catch below swallows.
        'iosIconName': _iosIconName(normalized),
      });
      await prefs.setString(_prefsKey, normalized);

      if (kDebugMode) {
        log('AppIconService: switched icon to "$normalized"');
      }
    } catch (e) {
      // Never let an icon-switch failure affect app startup — this is
      // cosmetic, not functional.
      if (kDebugMode) {
        log('AppIconService: failed to switch icon to "$variant": $e');
      }
    }
  }
}
