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
    // Every screen shares this one ScaffoldMessenger, and showSnackBar()
    // queues rather than replaces: a fast sequence of actions (removing
    // several cart lines, tapping +/- near a limit, a validation toast
    // firing right after) each enqueue their own SnackBar, so a new one
    // starts the moment the last one's duration elapses. The net effect
    // reads as "a toast that never goes away", even though each instance
    // individually still honors its own duration.
    //
    // clearSnackBars() does not fix this: per ScaffoldMessengerState's own
    // source, it runs the current bar's normal *exit animation*
    // (reverse(), ~250ms) rather than removing it immediately, and
    // showSnackBar() only starts the new bar's entrance once that finishes
    // — the auto-dismiss timer is armed only after the entrance animation
    // reaches AnimationStatus.completed. A second call arriving before that
    // resolves (another quick removal, a second toast) interrupts the
    // in-flight reverse and restarts the cycle, so under any moderately
    // active cart-editing session the timer that's supposed to end the
    // message may never get armed, and it reads as "stuck".
    // removeCurrentSnackBar() instead removes the old bar synchronously
    // with no animation, so by the time showSnackBar() runs the queue is
    // empty and the new bar's entrance — and therefore its dismiss timer —
    // starts cleanly every single time.
    messenger.removeCurrentSnackBar();
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
