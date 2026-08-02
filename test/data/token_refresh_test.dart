// test/data/token_refresh_test.dart
//
// Sessions used to end for reasons that had nothing to do with the server:
// a client-invented "10 days since login" rule decided expiry, and any 401
// signed the shopper out on the spot with no attempt to renew. These tests pin
// the replacement — expiry read from the token itself, and 401 meaning "renew
// and retry" before it means "sign out".

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/data/auth/token_refresher.dart';
import 'package:patelmart/data/models/auth_models.dart';

/// Builds an unsigned JWT whose `exp` is [expiresIn] from now.
String jwtExpiringIn(Duration expiresIn, {String id = 'user-1'}) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${seg({'id': id, 'type': 'access', 'exp': exp})}.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProfile expiry', () {
    test('reads the real expiry out of the access token', () {
      final token = jwtExpiringIn(const Duration(days: 7));
      final expiry = UserProfile.expiryFromJwt(token);

      expect(expiry, isNotNull);
      expect(
        expiry!.difference(DateTime.now()).inHours,
        closeTo(const Duration(days: 7).inHours, 1),
      );
    });

    test('returns null for a non-JWT rather than claiming it expired', () {
      expect(UserProfile.expiryFromJwt('not-a-jwt'), isNull);
      expect(UserProfile.expiryFromJwt(''), isNull);
      expect(UserProfile.expiryFromJwt('a.b'), isNull);
    });

    test('a token near expiry asks to be refreshed, a fresh one does not', () {
      UserProfile withExpiry(Duration d) => UserProfile(
            mobile: '7666475554',
            accessKey: 'token',
            loginTime: DateTime.now(),
            refreshToken: 'refresh',
            accessKeyExpiresAt: DateTime.now().add(d),
          );

      expect(withExpiry(const Duration(days: 7)).accessKeyNeedsRefresh(), isFalse);
      expect(withExpiry(const Duration(seconds: 30)).accessKeyNeedsRefresh(), isTrue);
      expect(withExpiry(const Duration(days: -1)).accessKeyNeedsRefresh(), isTrue);
    });

    test('survives a storage round trip with both tokens intact', () {
      final original = UserProfile(
        mobile: '7666475554',
        accessKey: jwtExpiringIn(const Duration(days: 7)),
        loginTime: DateTime.now(),
        refreshToken: 'the-refresh-token',
        accessKeyExpiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      // Exactly what CentralizedAuthManager writes to and reads from storage.
      final restored = UserProfile.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored.mobile, original.mobile);
      expect(restored.accessKey, original.accessKey);
      expect(restored.refreshToken, 'the-refresh-token');
      expect(restored.hasRefreshToken, isTrue);
      expect(restored.accessKeyExpiresAt, isNotNull);
    });

    test('a profile stored before refresh tokens existed still loads', () {
      // No refreshToken and no accessKeyExpiresAt — an install upgrading from
      // an older build. It must keep its session, not be logged out.
      final legacy = UserProfile.fromJson({
        'mobile': '7666475554',
        'accessKey': jwtExpiringIn(const Duration(days: 3)),
        'loginTime': DateTime.now().toIso8601String(),
      });

      expect(legacy.hasRefreshToken, isFalse);
      // Expiry is recovered from the token itself.
      expect(legacy.accessKeyExpiresAt, isNotNull);
    });
  });

  group('TokenRefresher', () {
    TokenRefresher build(http.Response Function(http.Request) handler) {
      return TokenRefresher(
        apiClient: ApiClient(client: MockClient((r) async => handler(r))),
      );
    }

    test('returns the rotated pair on success', () async {
      final refresher = build((_) => http.Response(
            jsonEncode({
              'success': true,
              'data': {'token': 'new-access', 'refreshToken': 'new-refresh'}
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await refresher.refresh('old-refresh');

      expect(result, isNotNull);
      expect(result!.accessToken, 'new-access');
      expect(result.refreshToken, 'new-refresh');
    });

    test('sends no Authorization header — the access token may be dead', () async {
      String? authHeader = 'unset';
      final refresher = build((request) {
        authHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({'success': true, 'data': {'token': 'a', 'refreshToken': 'b'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await refresher.refresh('old-refresh');
      expect(authHeader, isNull);
    });

    test('a rejected refresh token returns null — the session is over', () async {
      final refresher = build((_) => http.Response(
            jsonEncode({'success': false, 'message': 'Refresh token is invalid or expired'}),
            401,
            headers: {'content-type': 'application/json'},
          ));

      expect(await refresher.refresh('revoked'), isNull);
    });

    test('a server error throws, so a live session is not discarded', () async {
      final refresher = build((_) => http.Response(
            jsonEncode({'success': false, 'message': 'Server Error'}),
            500,
            headers: {'content-type': 'application/json'},
          ));

      // Must NOT resolve to null: null means "signed out", and a 500 is not
      // the server saying this session ended.
      expect(() => refresher.refresh('still-good'), throwsA(isA<ApiException>()));
    });
  });

  group('ApiClient 401 handling', () {
    test('refreshes and retries once, and the retry carries the new token',
        () async {
      final sentTokens = <String?>[];
      var refreshCalls = 0;

      final client = ApiClient(
        client: MockClient((request) async {
          final auth = request.headers['Authorization'];
          sentTokens.add(auth);
          if (auth == 'Bearer stale-token') {
            return http.Response(
              jsonEncode({'success': false, 'message': 'Token is not valid.'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'success': true, 'data': 'ok'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        readToken: () async => 'stale-token',
        refreshToken: () async {
          refreshCalls++;
          return 'fresh-token';
        },
        onUnauthorized: () async => fail('must not log out when refresh works'),
      );

      final result = await client.postWithAuth('https://x.test/api/cart/save-cart');

      expect(result['success'], isTrue);
      expect(refreshCalls, 1);
      expect(sentTokens, ['Bearer stale-token', 'Bearer fresh-token']);
    });

    test('logs out only when the retry also 401s', () async {
      var loggedOut = false;
      var refreshCalls = 0;

      final client = ApiClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({'success': false, 'message': 'Token is not valid.'}),
              401,
              headers: {'content-type': 'application/json'},
            )),
        readToken: () async => 'stale-token',
        refreshToken: () async {
          refreshCalls++;
          return 'fresh-but-also-rejected';
        },
        onUnauthorized: () async => loggedOut = true,
      );

      await expectLater(
        client.postWithAuth('https://x.test/api/cart/save-cart'),
        throwsA(isA<ApiException>()),
      );

      expect(refreshCalls, 1, reason: 'refresh is attempted exactly once');
      expect(loggedOut, isTrue);
    });

    test('a 401 on a request that carried no token does NOT sign the user out',
        () async {
      // This test previously asserted the opposite, pinning a real bug: when
      // the client fails to attach a token, the server's 401 says only "no
      // credential was presented" — it is not a verdict on the stored session,
      // which the server never saw. Signing out on it destroyed live sessions
      // over a client-side slip, mid-checkout, with nothing on screen to say
      // why the next call was suddenly unauthenticated.
      var requests = 0;
      var loggedOut = false;

      final client = ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({'success': false, 'message': 'Access denied. No token provided.'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
        readToken: () async => null,
        onUnauthorized: () async => loggedOut = true,
      );

      await expectLater(
        client.postWithAuth('https://x.test/api/cart/save-cart'),
        throwsA(isA<ApiException>()),
      );

      expect(requests, 1, reason: 'nothing to retry without a token');
      expect(loggedOut, isFalse,
          reason: 'the session was never presented, so it was never rejected');
    });

    test('a 401 on a request that DID carry a token still signs the user out',
        () async {
      // The counterpart: here the server saw the credential and refused it, so
      // ending the session is the right call.
      var loggedOut = false;

      final client = ApiClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({'success': false, 'message': 'Token is not valid.'}),
              401,
              headers: {'content-type': 'application/json'},
            )),
        readToken: () async => 'a-real-but-rejected-token',
        onUnauthorized: () async => loggedOut = true,
      );

      await expectLater(
        client.postWithAuth('https://x.test/api/cart/save-cart'),
        throwsA(isA<ApiException>()),
      );

      expect(loggedOut, isTrue);
    });

    test('a non-401 failure is passed through untouched', () async {
      var refreshCalls = 0;

      final client = ApiClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({'success': false, 'error': 'Item 1: product_name is required'}),
              400,
              headers: {'content-type': 'application/json'},
            )),
        readToken: () async => 'good-token',
        refreshToken: () async {
          refreshCalls++;
          return 'unused';
        },
        onUnauthorized: () async => fail('a 400 is not a session problem'),
      );

      await expectLater(
        client.postWithAuth('https://x.test/api/cart/save-cart'),
        throwsA(predicate((e) =>
            e is ApiException &&
            e.statusCode == 400 &&
            e.message.contains('product_name is required'))),
      );

      expect(refreshCalls, 0);
    });
  });
}
