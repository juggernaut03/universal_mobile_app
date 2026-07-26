// test/data/product_cache_policy_test.dart
//
// The daily 2 AM reset used to be computed inline against DateTime.now(),
// which made it untestable without waiting for real time to pass. As a pure
// decision taking `now` as a parameter, every branch is now checkable.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/data/repositories/product_cache_policy.dart';

void main() {
  const policy = ProductCachePolicy();

  group('isFresh', () {
    test('is fresh inside the window', () {
      final now = DateTime(2026, 7, 26, 12, 0);

      expect(
        policy.isFresh(cachedAt: now.subtract(const Duration(minutes: 90)), now: now),
        isTrue,
      );
    });

    test('is stale outside the window', () {
      final now = DateTime(2026, 7, 26, 12, 0);

      expect(
        policy.isFresh(cachedAt: now.subtract(const Duration(hours: 3)), now: now),
        isFalse,
      );
    });

    test('is stale exactly at the boundary', () {
      final now = DateTime(2026, 7, 26, 12, 0);

      expect(
        policy.isFresh(cachedAt: now.subtract(const Duration(hours: 2)), now: now),
        isFalse,
      );
    });

    test('honours a custom freshness window', () {
      const short = ProductCachePolicy(freshFor: Duration(minutes: 5));
      final now = DateTime(2026, 7, 26, 12, 0);

      expect(
        short.isFresh(cachedAt: now.subtract(const Duration(minutes: 6)), now: now),
        isFalse,
      );
    });
  });

  group('isDailyResetDue', () {
    test('is not due before the reset hour', () {
      expect(
        policy.isDailyResetDue(
          lastClearedAt: DateTime(2026, 7, 25, 3),
          now: DateTime(2026, 7, 26, 1, 30), // 01:30, before 02:00
        ),
        isFalse,
      );
    });

    test('is due after the reset hour when last cleared yesterday', () {
      expect(
        policy.isDailyResetDue(
          lastClearedAt: DateTime(2026, 7, 25, 3),
          now: DateTime(2026, 7, 26, 9),
        ),
        isTrue,
      );
    });

    test('is not due twice in the same day', () {
      // Already cleared at 02:05 today; 09:00 must not clear again.
      expect(
        policy.isDailyResetDue(
          lastClearedAt: DateTime(2026, 7, 26, 2, 5),
          now: DateTime(2026, 7, 26, 9),
        ),
        isFalse,
      );
    });

    test('is due when it has never run and the hour has passed', () {
      expect(
        policy.isDailyResetDue(
          lastClearedAt: null,
          now: DateTime(2026, 7, 26, 9),
        ),
        isTrue,
      );
    });

    test('is not due when it has never run and the hour has not passed', () {
      expect(
        policy.isDailyResetDue(
          lastClearedAt: null,
          now: DateTime(2026, 7, 26, 0, 30),
        ),
        isFalse,
      );
    });

    test('is due exactly at the reset hour', () {
      expect(
        policy.isDailyResetDue(
          lastClearedAt: DateTime(2026, 7, 25, 12),
          now: DateTime(2026, 7, 26, 2),
        ),
        isTrue,
      );
    });
  });
}
