// lib/core/privacy/tracking_consent_service.dart
//
// Gatekeeper for anything that reads the device's advertising identifier
// (today: the Facebook Pixel integration's advertiser-ID collection).
//
// Apple's App Tracking Transparency framework requires the system
// permission prompt to appear BEFORE any such data is collected. This used
// to not exist at all: Facebook Pixel initialized with advertiser-ID
// collection hardcoded on, on every launch, with no ATT prompt anywhere in
// the app — App Review rejected the app for exactly this (Guideline 2.1).
//
// Android has no ATT framework and no IDFA to gate, so [requestConsent]
// is a no-op there and always allows tracking.
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';

import '../../presentation/widgets/data_consent_dialog.dart';

class TrackingConsentService {
  /// Resolves to whether advertiser-tracking data (IDFA) may be collected.
  ///
  /// On iOS this shows our own explainer dialog once, only when the system
  /// permission has never been decided, then triggers the native ATT
  /// prompt — the explainer never substitutes for it. If [context] is
  /// unavailable the explainer is skipped and the system prompt is shown
  /// directly, since the system decision is what actually matters.
  static Future<bool> requestConsent(BuildContext? context) async {
    if (!Platform.isIOS) return true;

    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.authorized) return true;
    if (status != TrackingStatus.notDetermined) return false;

    if (context != null && context.mounted) {
      await DataConsentDialog.show(context);
    }

    final result = await AppTrackingTransparency.requestTrackingAuthorization();
    return result == TrackingStatus.authorized;
  }
}
