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

import '../data/auth/centralized_auth_manager.dart';
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
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
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
  final manager = CentralizedAuthManager(
    secureStorage: ref.watch(secureStorageProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

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
  );
});
