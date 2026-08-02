// test/data/session_expiry_policy_test.dart
//
// Expiry used to be decided by three rules that disagreed. `_isProfileValid`
// read the token's `exp`; `isAccessKeyNearExpiry` used "days since login >= 8";
// `getDaysUntilExpiry` used "10 - days since login". A session could therefore
// be reported as having days left while its access token had already lapsed.
// These tests pin the single replacement rule.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/data/auth/session_expiry_policy.dart';
import 'package:patelmart/data/models/auth_models.dart';

/// A fixed instant, so nothing here depends on how long the suite takes.
final _now = DateTime.utc(2026, 1, 15, 12);

SessionExpiryPolicy policyAt(DateTime now) =>
    SessionExpiryPolicy(clock: () => now);

UserProfile profile({
  String accessKey = 'token',
  String refreshToken = '',
  DateTime? expiresAt,
  DateTime? loginTime,
}) =>
    UserProfile(
      mobile: '9999999999',
      accessKey: accessKey,
      loginTime: loginTime ?? _now.subtract(const Duration(days: 1)),
      refreshToken: refreshToken,
      accessKeyExpiresAt: expiresAt,
    );

void main() {
  final policy = policyAt(_now);

  group('isValid', () {
    test('an empty access key is never valid', () {
      expect(policy.isValid(profile(accessKey: '')), isFalse);
    });

    test('a renewable session stays valid past its access token', () {
      // The case that made restarts look like logouts: the access token is
      // long dead, but a refresh token can mint another one.
      final p = profile(
        refreshToken: 'refresh',
        expiresAt: _now.subtract(const Duration(days: 5)),
      );
      expect(policy.isValid(p), isTrue);
    });

    test('a non-renewable session is valid until its token expires', () {
      expect(
        policy.isValid(profile(expiresAt: _now.add(const Duration(hours: 1)))),
        isTrue,
      );
      expect(
        policy.isValid(profile(expiresAt: _now.subtract(const Duration(hours: 1)))),
        isFalse,
      );
    });

    test('falls back to the legacy lifetime when the token carries no exp', () {
      // Profiles written before `accessKeyExpiresAt` existed must keep working.
      expect(
        policy.isValid(profile(loginTime: _now.subtract(const Duration(days: 3)))),
        isTrue,
      );
      expect(
        policy.isValid(profile(loginTime: _now.subtract(const Duration(days: 11)))),
        isFalse,
      );
    });
  });

  group('needsRefresh', () {
    test('true once inside the leeway, so no request has to fail first', () {
      final p = profile(
        refreshToken: 'refresh',
        expiresAt: _now.add(const Duration(seconds: 30)),
      );
      expect(policy.needsRefresh(p), isTrue);
    });

    test('false while the token still has real life left', () {
      final p = profile(
        refreshToken: 'refresh',
        expiresAt: _now.add(const Duration(hours: 2)),
      );
      expect(policy.needsRefresh(p), isFalse);
    });

    test('false without a refresh token — there is nothing to renew with', () {
      // Reporting "needs refresh" here would send callers down a path that can
      // only fail, and the old code then treated that failure as a dead session.
      final p = profile(expiresAt: _now.subtract(const Duration(hours: 1)));
      expect(policy.needsRefresh(p), isFalse);
    });
  });

  group('near expiry', () {
    test('a renewable session is never "near expiry"', () {
      // It renews silently; warning the shopper would be a lie.
      final p = profile(
        refreshToken: 'refresh',
        expiresAt: _now.add(const Duration(hours: 1)),
      );
      expect(policy.isNearExpiry(p), isFalse);
    });

    test('warns inside the threshold and not before it', () {
      expect(
        policy.isNearExpiry(profile(expiresAt: _now.add(const Duration(days: 1)))),
        isTrue,
      );
      expect(
        policy.isNearExpiry(profile(expiresAt: _now.add(const Duration(days: 5)))),
        isFalse,
      );
    });

    test('an already-expired session is not "near" expiry', () {
      expect(
        policy.isNearExpiry(profile(expiresAt: _now.subtract(const Duration(days: 1)))),
        isFalse,
      );
    });
  });

  group('daysUntilExpiry', () {
    test('counts against the token exp, not days since login', () {
      // The old rule returned 10 - daysSinceLogin, so this profile — logged in
      // 9 days ago but holding a token good for another week — reported 1.
      final p = profile(
        loginTime: _now.subtract(const Duration(days: 9)),
        expiresAt: _now.add(const Duration(days: 7)),
      );
      expect(policy.daysUntilExpiry(p), 7);
    });

    test('floors at zero rather than going negative', () {
      final p = profile(expiresAt: _now.subtract(const Duration(days: 3)));
      expect(policy.daysUntilExpiry(p), 0);
    });
  });
}
