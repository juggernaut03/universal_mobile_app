// lib/core/utils/app_snackbar.dart

import 'package:flutter/material.dart';

import '../../main.dart' show scaffoldMessengerKey;
import 'logger.dart';

/// Shows [snackBar] on the app-level messenger, and never throws.
///
/// A toast is cosmetic. It must not be able to abort the operation that asked
/// for it — and it could: `ScaffoldMessengerState.showSnackBar` walks the
/// Scaffolds registered with the messenger (`_updateScaffolds` -> `_isRoot` ->
/// `findAncestorStateOfType`), so a single Scaffold that is deactivated but not
/// yet unregistered makes the call throw "Looking up a deactivated widget's
/// ancestor is unsafe". Nothing the caller does can prevent that: the bad state
/// belongs to another route's Scaffold, not to the caller, and it is unaffected
/// by `mounted` checks or by which messenger reference is used.
///
/// When that happened inside `_proceedToCheckout`, the exception propagated out
/// of the method and checkout simply stopped — the shopper tapped the button
/// and nothing happened, with no message and no way forward. Swallowing the
/// failure costs a missed toast; not swallowing it cost the sale.
void showAppSnackBar(SnackBar snackBar, {Logger? logger}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  try {
    messenger.showSnackBar(snackBar);
  } catch (e) {
    // Deliberately swallowed — see above. Logged so it stays visible.
    (logger ?? Logger()).warning('SnackBar suppressed: $e');
  }
}

/// Hides the current SnackBar, with the same guarantee as [showAppSnackBar].
void hideAppSnackBar({Logger? logger}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  try {
    messenger.hideCurrentSnackBar();
  } catch (e) {
    (logger ?? Logger()).warning('SnackBar hide suppressed: $e');
  }
}
