// test/domain/auth_session_test.dart
//
// Session expiry rules. Previously these lived inside CentralizedAuthManager
// against a live clock and secure storage, so none of them could be exercised
// without waiting ten real days.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/domain/entities/auth_session.dart';

void main() {
  _expiryAuthorityTests();
  final issued = DateTime(2026, 7, 1, 12);

  AuthSession session({String token = 'jwt-abc'}) => AuthSession(
        mobile: '9876543210',
        accessToken: token,
        issuedAt: issued,
      );

  group('expiry', () {
    test('expires ten days after issue by default', () {
      expect(session().expiresAt, DateTime(2026, 7, 11, 12));
    });

    test('is valid within the window', () {
      expect(session().isValidAt(issued.add(const Duration(days: 9))), isTrue);
      expect(session().isExpiredAt(issued.add(const Duration(days: 9))), isFalse);
    });

    test('is expired past the window', () {
      expect(session().isExpiredAt(issued.add(const Duration(days: 11))), isTrue);
      expect(session().isValidAt(issued.add(const Duration(days: 11))), isFalse);
    });

    test('is expired exactly at the boundary', () {
      // A credential the server would already reject must not read as valid.
      expect(session().isExpiredAt(DateTime(2026, 7, 11, 12)), isTrue);
    });

    test('an empty token is never valid, even inside the window', () {
      expect(session(token: '').isValidAt(issued), isFalse);
    });

    test('honours a custom lifetime', () {
      final short = AuthSession(
        mobile: '9876543210',
        accessToken: 'jwt',
        issuedAt: issued,
        lifetime: const Duration(hours: 1),
      );

      expect(short.isExpiredAt(issued.add(const Duration(minutes: 59))), isFalse);
      expect(short.isExpiredAt(issued.add(const Duration(hours: 2))), isTrue);
    });
  });

  group('daysRemainingAt', () {
    test('counts whole days left', () {
      expect(session().daysRemainingAt(issued.add(const Duration(days: 3))), 7);
    });

    test('floors at zero once expired rather than going negative', () {
      expect(session().daysRemainingAt(issued.add(const Duration(days: 30))), 0);
    });
  });

  group('isNearExpiryAt', () {
    test('is near expiry inside the threshold', () {
      expect(
        session().isNearExpiryAt(issued.add(const Duration(days: 9))),
        isTrue,
      );
    });

    test('is not near expiry well before it', () {
      expect(
        session().isNearExpiryAt(issued.add(const Duration(days: 2))),
        isFalse,
      );
    });

    test('an already-expired session is not "near" expiry', () {
      // Distinct states: near-expiry warns, expired signs out.
      expect(
        session().isNearExpiryAt(issued.add(const Duration(days: 20))),
        isFalse,
      );
    });
  });

  group('safety', () {
    test('toString never leaks the access token', () {
      // This string reaches logs and crash reports.
      expect(session(token: 'super-secret-jwt').toString(),
          isNot(contains('super-secret-jwt')));
    });
  });

  group('equality', () {
    test('same mobile, token and issue time are equal', () {
      expect(session(), session());
      expect(session().hashCode, session().hashCode);
    });

    test('a re-issued token is a different session', () {
      expect(session(token: 'old'), isNot(session(token: 'new')));
    });
  });
}

// ---------------------------------------------------------------------------
// Expiry authority.
//
// There used to be two answers to "is this session valid": CentralizedAuthManager
// had one rule, AuthSession.isValidAt had another built on a client-invented
// `lifetime`. isSignedIn() consulted the first and currentSession() the second,
// so they could disagree about the same session — and checkout, which asks
// currentSession(), silently lost the shopper's identity at the till.
// ---------------------------------------------------------------------------
void _expiryAuthorityTests() {
  group('expiry comes from the token, not a guessed lifetime', () {
    final issued = DateTime.utc(2026, 1, 1);

    test('tokenExpiresAt wins over issuedAt + lifetime', () {
      final session = AuthSession(
        mobile: '7666475554',
        accessToken: 'jwt',
        issuedAt: issued,
        lifetime: const Duration(days: 10), // the old guess
        tokenExpiresAt: issued.add(const Duration(days: 7)), // the truth
      );

      expect(session.expiresAt, issued.add(const Duration(days: 7)));
      expect(session.isValidAt(issued.add(const Duration(days: 8))), isFalse);
    });

    test('falls back to the lifetime guess only when the token says nothing', () {
      final session = AuthSession(
        mobile: '7666475554',
        accessToken: 'opaque',
        issuedAt: issued,
        lifetime: const Duration(days: 10),
      );

      expect(session.expiresAt, issued.add(const Duration(days: 10)));
    });

    test('a renewable session stays valid past its access token', () {
      // The refresh token exists precisely to outlive the access token.
      // Reporting this as expired is what signed people out mid-checkout while
      // a perfectly good session sat on the device.
      final session = AuthSession(
        mobile: '7666475554',
        accessToken: 'jwt',
        issuedAt: issued,
        tokenExpiresAt: issued.add(const Duration(days: 7)),
        refreshToken: 'refresh',
      );

      expect(session.isRenewable, isTrue);
      expect(session.isValidAt(issued.add(const Duration(days: 30))), isTrue);
    });

    test('an empty access token is never valid, renewable or not', () {
      final session = AuthSession(
        mobile: '7666475554',
        accessToken: '',
        issuedAt: issued,
        refreshToken: 'refresh',
      );

      expect(session.isValidAt(issued), isFalse);
    });
  });
}
