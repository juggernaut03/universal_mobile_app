// test/data/centralized_auth_manager_test.dart
//
// None of this could be tested before: the manager did secure-storage I/O
// inline, so session restore, the unreadable-storage path and the init race all
// required a device. Storage is now an injected interface.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/data/auth/auth_local_data_source.dart';
import 'package:patelmart/data/auth/centralized_auth_manager.dart';
import 'package:patelmart/data/models/auth_models.dart';

/// In-memory [AuthLocalDataSource] that can be told to fail like a real one.
class FakeAuthStorage implements AuthLocalDataSource {
  UserProfile? profile;

  /// When set, [read] throws it — standing in for a keystore key lost to a
  /// device restore, or a keychain still locked before first unlock.
  AuthStorageException? readError;

  int clearCount = 0;
  int purgeCount = 0;

  FakeAuthStorage({this.profile});

  @override
  Future<UserProfile?> read() async {
    if (readError != null) throw readError!;
    return profile;
  }

  @override
  Future<void> write(UserProfile p) async => profile = p;

  @override
  Future<void> clear() async {
    clearCount++;
    profile = null;
  }

  @override
  Future<void> purgeLegacy() async => purgeCount++;
}

UserProfile profileWith({
  String accessKey = 'access-token',
  String refreshToken = '',
  DateTime? expiresAt,
}) =>
    UserProfile(
      mobile: '9999999999',
      accessKey: accessKey,
      loginTime: DateTime.now().subtract(const Duration(days: 1)),
      refreshToken: refreshToken,
      accessKeyExpiresAt: expiresAt,
    );

CentralizedAuthManager managerFor(
  FakeAuthStorage storage, {
  Future<RefreshedTokens?> Function(String)? refreshTokens,
  Future<void> Function({required String accessToken, required String refreshToken})?
      revokeSession,
}) =>
    CentralizedAuthManager(
      storage: storage,
      logger: Logger(),
      refreshTokens: refreshTokens,
      revokeSession: revokeSession,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('startup', () {
    test('the first token read waits for storage instead of returning null', () async {
      // The race this pins: initialisation used to be launched from the
      // constructor and never awaited, so a getValidAccessKey() issued straight
      // after construction could return null purely because storage had not
      // loaded. The request then went out unauthenticated and the backend's
      // "no token provided" looked like a lost session.
      final storage = FakeAuthStorage(
        profile: profileWith(expiresAt: DateTime.now().add(const Duration(hours: 1))),
      );
      final manager = managerFor(storage);
      addTearDown(manager.dispose);

      // No `await manager.ready` on purpose — the accessor must do it.
      expect(await manager.getValidAccessKey(), 'access-token');
    });

    test('purges legacy credentials once on startup', () async {
      final storage = FakeAuthStorage();
      final manager = managerFor(storage);
      addTearDown(manager.dispose);

      await manager.ready;
      expect(storage.purgeCount, 1);
    });

    test('restores a valid stored session', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(expiresAt: DateTime.now().add(const Duration(days: 2))),
      );
      final manager = managerFor(storage);
      addTearDown(manager.dispose);

      expect(await manager.isLoggedIn(), isTrue);
      expect(await manager.getUserMobile(), '9999999999');
    });
  });

  group('unreadable storage', () {
    test('does not sign the user out', () async {
      // A keystore failure says nothing about whether the session is live. The
      // previous code caught the parse error and called logout(), destroying a
      // session the server still considered valid.
      final storage = FakeAuthStorage()
        ..readError = const AuthStorageException('keystore gone', 'boom');
      final manager = managerFor(storage);
      addTearDown(manager.dispose);

      await manager.ready;

      expect(storage.clearCount, 0, reason: 'must not clear on a storage fault');
    });
  });

  group('expired sessions', () {
    test('a non-renewable expired session is cleared on load', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(expiresAt: DateTime.now().subtract(const Duration(days: 1))),
      );
      final manager = managerFor(storage);
      addTearDown(manager.dispose);

      await manager.ready;

      expect(storage.clearCount, greaterThan(0));
      expect(await manager.isLoggedIn(), isFalse);
    });

    test('a renewable session survives a dead access token', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      final manager = managerFor(
        storage,
        refreshTokens: (_) async => const RefreshedTokens(
          accessToken: 'renewed',
          refreshToken: 'rotated',
        ),
      );
      addTearDown(manager.dispose);

      await manager.ready;

      expect(await manager.isLoggedIn(), isTrue);
      expect(await manager.getValidAccessKey(), 'renewed');
    });
  });

  group('refresh', () {
    test('concurrent callers share one in-flight refresh', () async {
      // Without de-duplication each caller burns a rotation of the refresh
      // token, and all but the last of the resulting tokens are invalidated by
      // the next rotation.
      var calls = 0;
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final manager = managerFor(storage, refreshTokens: (_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const RefreshedTokens(accessToken: 'renewed', refreshToken: 'rotated');
      });
      addTearDown(manager.dispose);
      await manager.ready;

      final results = await Future.wait([
        manager.refreshAccessToken(),
        manager.refreshAccessToken(),
        manager.refreshAccessToken(),
      ]);

      expect(calls, 1);
      expect(results, everyElement('renewed'));
    });

    test('a network failure keeps the session rather than ending it', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final manager = managerFor(
        storage,
        refreshTokens: (_) async => throw TimeoutException('offline'),
      );
      addTearDown(manager.dispose);
      await manager.ready;

      expect(await manager.refreshAccessToken(), isNull);
      expect(storage.clearCount, 0, reason: 'offline is not an expired session');
      expect(await manager.isLoggedIn(), isTrue);
    });

    test('a server rejection ends the session', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final manager = managerFor(storage, refreshTokens: (_) async => null);
      addTearDown(manager.dispose);
      await manager.ready;

      expect(await manager.refreshAccessToken(), isNull);
      expect(storage.clearCount, greaterThan(0));
    });

    test('stores the rotated refresh token, not the spent one', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'original',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final manager = managerFor(
        storage,
        refreshTokens: (_) async =>
            const RefreshedTokens(accessToken: 'renewed', refreshToken: 'rotated'),
      );
      addTearDown(manager.dispose);
      await manager.ready;

      await manager.refreshAccessToken();

      expect(storage.profile!.refreshToken, 'rotated');
    });
  });

  group('sign out', () {
    test('revokes server-side before clearing locally', () async {
      String? revokedWith;
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      final manager = managerFor(
        storage,
        revokeSession: ({required accessToken, required refreshToken}) async {
          revokedWith = refreshToken;
        },
      );
      addTearDown(manager.dispose);
      await manager.ready;

      await manager.logout();

      expect(revokedWith, 'refresh');
      expect(storage.profile, isNull);
    });

    test('clears locally even when the revoke call fails', () async {
      // Offline sign-out must still end the session on the device.
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      final manager = managerFor(
        storage,
        revokeSession: ({required accessToken, required refreshToken}) async =>
            throw TimeoutException('offline'),
      );
      addTearDown(manager.dispose);
      await manager.ready;

      await manager.logout();

      expect(storage.profile, isNull);
      expect(await manager.isLoggedIn(), isFalse);
    });

    test('emits false on the login status stream', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(expiresAt: DateTime.now().add(const Duration(days: 1))),
      );
      final manager = managerFor(storage);
      addTearDown(manager.dispose);
      await manager.ready;

      final emitted = expectLater(manager.loginStatusStream, emits(false));
      await manager.logout();
      await emitted;
    });
  });

  group('expiry reporting', () {
    test('reports days left from the token exp, not days since login', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(expiresAt: DateTime.now().add(const Duration(days: 7))),
      );
      final manager = managerFor(storage);
      addTearDown(manager.dispose);
      await manager.ready;

      expect(manager.getDaysUntilExpiry(), 6); // 6 whole days + change
      expect(manager.isAccessKeyNearExpiry(), isFalse);
    });

    test('a renewable session is never reported as near expiry', () async {
      final storage = FakeAuthStorage(
        profile: profileWith(
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );
      final manager = managerFor(storage);
      addTearDown(manager.dispose);
      await manager.ready;

      expect(manager.isAccessKeyNearExpiry(), isFalse);
    });
  });
}
