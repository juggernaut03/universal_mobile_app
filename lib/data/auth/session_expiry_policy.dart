// lib/data/auth/session_expiry_policy.dart

import '../models/auth_models.dart';

/// The one rule for "is this stored session still usable, and when does it die?".
///
/// Extracted because the answer was previously computed in three places that
/// disagreed:
///
///   * `CentralizedAuthManager._isProfileValid` — JWT `exp`, falling back to
///     days-since-login
///   * `CentralizedAuthManager.isAccessKeyNearExpiry` — "days since login >= 8"
///   * `CentralizedAuthManager.getDaysUntilExpiry` — "10 - days since login"
///
/// The last two ignored the token's real `exp` entirely, so a session could be
/// reported as "5 days left" by the banner while the access token had already
/// lapsed, and vice versa. Every question about expiry now resolves here.
///
/// The clock is injected so expiry is testable without waiting for real time.
class SessionExpiryPolicy {
  /// How far ahead of the real expiry a token is considered due for renewal.
  ///
  /// Refreshing slightly early means the common case never produces a failed
  /// request; it also absorbs clock skew between device and server.
  final Duration refreshLeeway;

  /// How close to expiry a non-renewable session is before the UI may warn.
  final Duration nearExpiryThreshold;

  /// Assumed lifetime for profiles stored before `accessKeyExpiresAt` existed.
  ///
  /// A client-side guess, used only when the token carries no readable `exp`.
  final Duration legacyLifetime;

  final DateTime Function() _now;

  const SessionExpiryPolicy({
    this.refreshLeeway = const Duration(minutes: 2),
    this.nearExpiryThreshold = const Duration(days: 2),
    this.legacyLifetime = const Duration(days: 10),
    DateTime Function() clock = DateTime.now,
  }) : _now = clock;

  /// When [profile]'s access token stops being accepted.
  ///
  /// The token's own `exp` when readable, otherwise the legacy guess. Null is
  /// impossible by construction — callers get an answer they can compare.
  DateTime expiryOf(UserProfile profile) =>
      profile.accessKeyExpiresAt ?? profile.loginTime.add(legacyLifetime);

  /// Whether the session can be kept alive at all.
  ///
  /// A session holding a refresh token is valid regardless of the access
  /// token's state — renewing it is exactly what the refresh token is for.
  /// Discarding such a profile is what made an app restart look like a logout.
  bool isValid(UserProfile profile) {
    if (profile.accessKey.isEmpty) return false;
    if (profile.hasRefreshToken) return true;
    return _now().isBefore(expiryOf(profile));
  }

  /// Whether the access token should be renewed before the next use.
  ///
  /// False when there is nothing to renew with: without a refresh token a
  /// renewal cannot succeed, and reporting "needs refresh" would send callers
  /// down a path that always fails.
  bool needsRefresh(UserProfile profile) {
    if (!profile.hasRefreshToken) return false;
    if (profile.accessKeyExpiresAt == null) return false;
    return _now().add(refreshLeeway).isAfter(expiryOf(profile));
  }

  /// Whether a *non-renewable* session is close enough to expiry to warn about.
  ///
  /// A renewable session is never "near expiry" in any sense the shopper cares
  /// about: it renews silently. Warning about it would be a lie.
  bool isNearExpiry(UserProfile profile) {
    if (profile.hasRefreshToken) return false;
    final remaining = timeUntilExpiry(profile);
    return remaining > Duration.zero && remaining <= nearExpiryThreshold;
  }

  /// Time left before [profile] expires, floored at zero.
  Duration timeUntilExpiry(UserProfile profile) {
    final remaining = expiryOf(profile).difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whole days left before expiry, floored at zero.
  int daysUntilExpiry(UserProfile profile) => timeUntilExpiry(profile).inDays;
}
