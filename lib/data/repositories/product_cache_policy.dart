// lib/data/repositories/product_cache_policy.dart
//
// Extracted from ProductRepository, where cache freshness and the 2 AM daily
// reset were computed inline against DateTime.now() — making both rules
// untestable without waiting for real time to pass.
//
// Pure decisions: no I/O, no clock of its own. The caller supplies `now`, so
// every rule can be tested by passing a fixed timestamp.

/// Decides when cached product data is stale and when the daily reset is due.
final class ProductCachePolicy {
  /// How long a cached listing stays fresh.
  final Duration freshFor;

  /// Hour of day (0-23) at which the full daily reset fires.
  final int dailyResetHour;

  const ProductCachePolicy({
    this.freshFor = const Duration(hours: 2),
    this.dailyResetHour = 2,
  });

  /// Whether an entry written at [cachedAt] is still usable at [now].
  bool isFresh({required DateTime cachedAt, required DateTime now}) =>
      now.difference(cachedAt) < freshFor;

  /// Whether the daily reset is due at [now], given the previous reset time.
  ///
  /// Due when [now] is past today's reset hour and the last reset happened
  /// before it. A null [lastClearedAt] means the reset has never run, so it is
  /// due as soon as the hour has passed.
  bool isDailyResetDue({required DateTime? lastClearedAt, required DateTime now}) {
    final resetPointToday =
        DateTime(now.year, now.month, now.day, dailyResetHour);

    if (now.isBefore(resetPointToday)) return false;
    if (lastClearedAt == null) return true;
    return lastClearedAt.isBefore(resetPointToday);
  }
}
