// lib/core/time/clock.dart
//
// "Now", as a value the app reads rather than a global it calls.
//
// Scheduling is the one part of the home screen that cannot be verified by
// looking at it: a section that goes live next Tuesday looks identical to one
// that never goes live at all. Reading the time through this makes "show me
// next Tuesday" a supported operation instead of a code change.
//
// Production uses [SystemClock] and behaves exactly as `DateTime.now()` did.
// The admin preview swaps in a [FixedClock] to travel in time.

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class Clock {
  const Clock();

  DateTime now();
}

class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock stopped at [instant]. Used by the preview to render a chosen
/// date/time, so scheduled and expiring sections can be checked before they
/// reach real shoppers.
class FixedClock extends Clock {
  final DateTime instant;

  const FixedClock(this.instant);

  @override
  DateTime now() => instant;
}

/// The app's clock. Overridden in the preview host; never elsewhere.
final clockProvider = Provider<Clock>((ref) => const SystemClock());
