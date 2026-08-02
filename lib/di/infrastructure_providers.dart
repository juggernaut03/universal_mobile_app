// lib/di/infrastructure_providers.dart
//
// Composition root — infrastructure.
//
// Framework-level collaborators with no feature knowledge: logging, storage,
// HTTP, messaging. Everything in `repository_providers.dart` and
// `service_providers.dart` wires through these.
//
// Why `lib/di/` and not `lib/core/di/`: a composition root must import every
// layer in order to construct it. `core/` is defined as having zero feature
// knowledge, so the wiring cannot live there without breaking its own rule.
// The composition root is the one place permitted to see all layers.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth/auth_local_data_source.dart';
import '../data/auth/centralized_auth_manager.dart';
import '../data/auth/session_expiry_policy.dart';
import '../data/auth/token_refresher.dart';
import '../core/network/api_client.dart';
import '../core/utils/logger.dart';

/// Structured logger. Replaces direct `print()` calls.
final loggerProvider = Provider<Logger>((ref) => Logger());

/// SharedPreferences instance.
///
/// Deliberately unimplemented: it is resolved asynchronously during startup and
/// injected via a `ProviderScope` override in `main.dart`. Reading it before
/// that override is in place is a wiring bug, and this throw surfaces it
/// immediately rather than handing back a broken instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be initialized and overridden at the root widget',
  );
});

/// Encrypted key-value storage for tokens and credentials.
///
/// `first_unlock` lets iOS read the token after the first unlock following a
/// boot rather than only while the device is actively unlocked. The default
/// (`unlocked`) makes the keychain unreadable to background work — the FCM
/// background message handler runs in exactly that state, and could not
/// authenticate. This is safe to change on an existing install: the iOS plugin
/// passes accessibility only when *writing*, and `read()` queries on the
/// account name alone (see `FlutterSecureStorage.swift`, `baseQuery`), so
/// entries written under the old attribute stay readable.
///
/// Android is deliberately left on the plugin default.
///
/// `AndroidOptions(encryptedSharedPreferences: true)` was set here and had to
/// be reverted: it is NOT a compatible change. Both modes share one
/// preferences file, but EncryptedSharedPreferences encrypts key *names* as
/// well as values, so a lookup in that mode never matches an entry written in
/// the default mode. `read()` then returns null — no error, no exception —
/// and the app reads "no stored session" and asks the user to sign in again.
/// Every install that upgraded across that flag silently lost its session.
///
/// Switching modes needs a migration that reads through a legacy-configured
/// client and rewrites through the new one. Until that exists, the default
/// stands: it already encrypts values with an AES key wrapped by the Android
/// Keystore, which is the property that matters here.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  ),
);

/// Raw HTTP client.
///
/// Prefer [apiClientProvider]. This exists for the few collaborators that need
/// an unwrapped client; it applies no project code, no auth and no timeout.
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

/// Firebase Cloud Messaging instance.
final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

/// Shared file cache used for product and category imagery.
final cacheManagerProvider = Provider<DefaultCacheManager>(
  (ref) => DefaultCacheManager(),
);

/// Single source of truth for session state and token storage.
///
/// Was declared inside core/auth/centralized_auth_manager.dart, which forced
/// that core file to import presentation providers for logger/prefs/storage.
final centralizedAuthManagerProvider = Provider<CentralizedAuthManager>((ref) {
  final logger = ref.watch(loggerProvider);

  // An auth-less ApiClient on purpose, and NOT apiClientProvider: that one is
  // built from this manager, so resolving it here would be a cycle. Refresh
  // also must not carry a bearer token — see TokenRefresher.
  final refresher = TokenRefresher(
    apiClient: ApiClient(logger: logger),
    logger: logger,
  );

  final manager = CentralizedAuthManager(
    storage: ref.watch(authLocalDataSourceProvider),
    logger: logger,
    expiryPolicy: ref.watch(sessionExpiryPolicyProvider),
    refreshTokens: refresher.refresh,
    revokeSession: refresher.revoke,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// Where the signed-in session is persisted.
///
/// Behind an interface so the manager can be tested against an in-memory fake
/// — session restore, the periodic validation timer and the corrupt-payload
/// path previously had no test that could run without a device.
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return SecureAuthLocalDataSource(
    secureStorage: ref.watch(secureStorageProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    logger: ref.watch(loggerProvider),
  );
});

/// The one rule for session validity, renewal timing and expiry warnings.
final sessionExpiryPolicyProvider = Provider<SessionExpiryPolicy>(
  (ref) => const SessionExpiryPolicy(),
);

/// The application's HTTP client — the single choke point for backend traffic.
///
/// Applies the `X-Project-Code` header, attaches the `Authorization: Bearer`
/// JWT on the `*WithAuth` variants, and forces logout when an authenticated
/// call returns 401.
///
/// The [CentralizedAuthManager] is REQUIRED. Constructing `ApiClient` without
/// it yields a client whose `_getToken()` returns null, so `postWithAuth` and
/// friends silently send no `Authorization` header and 401s are ignored. Two
/// such auth-less declarations previously existed and every consumer resolved
/// one of them — see docs/ARCHITECTURE_MIGRATION_PLAN.md, Phase 1.
final apiClientProvider = Provider<ApiClient>((ref) {
  final authManager = ref.watch(centralizedAuthManagerProvider);
  return ApiClient(
    logger: ref.watch(loggerProvider),
    readToken: authManager.getValidAccessKey,
    onUnauthorized: authManager.logout,
    // Given a 401, try to renew before giving up. Without this the app signs
    // the shopper out the moment an access token lapses, which is what made a
    // restart feel like the session had expired.
    refreshToken: authManager.refreshAccessToken,
  );
});
