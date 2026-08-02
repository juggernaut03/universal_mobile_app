// lib/presentation/providers/auth_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/auth_models.dart';
import '../../di/infrastructure_providers.dart';
import '../../di/service_providers.dart';
import '../../core/usecase/usecase.dart';
import '../../di/auth_providers.dart';


// authServiceProvider now declared in lib/di/service_providers.dart


// Provider to check if user is logged in using centralized auth
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final authManager = ref.watch(centralizedAuthManagerProvider);
  return await authManager.isLoggedIn();
});

// Provider for user profile using centralized auth
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authManager = ref.watch(centralizedAuthManagerProvider);
  return await authManager.getCurrentUserProfile();
});

// Reactive stream providers for immediate UI updates
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final authManager = ref.watch(centralizedAuthManagerProvider);
  return authManager.profileStream;
});

final loginStatusStreamProvider = StreamProvider<bool>((ref) {
  final authManager = ref.watch(centralizedAuthManagerProvider);
  return authManager.loginStatusStream;
});

// Provider that reactively checks login status from streams
final isLoggedInReactiveProvider = Provider<bool>((ref) {
  final loginStatusAsync = ref.watch(loginStatusStreamProvider);
  return loginStatusAsync.valueOrNull ?? false;
});

// State providers for login process
final mobileNumberProvider = StateProvider<String>((ref) => '');
final otpProvider = StateProvider<String>((ref) => '');
final loginStateProvider = StateProvider<LoginState>((ref) => LoginState.initial);





// Enhanced logout provider that clears favorites
final logoutProvider = Provider((ref) {
  return () async {
    // SignOut clears both the session store and the legacy AuthService copy;
    // doing only one left the user half-signed-out.
    await ref.read(signOutUseCaseProvider)(const NoParams());
    
    // Clear login state
    ref.read(loginStateProvider.notifier).state = LoginState.initial;
    
    // Invalidate user profile and login status
    ref.invalidate(userProfileProvider);
    ref.invalidate(isLoggedInProvider);
  };
});

// ========== FCM TOKEN PROVIDERS ==========
//
// These read FcmTokenService, not AuthService. AuthService's FCM methods were
// built around a profile it could not actually load — `getUserProfile()` was
// hardcoded to return null — so `refreshFcmToken()` failed for every signed-in
// user. FcmTokenService has the auth manager injected and authenticates through
// ApiClient, so it reads a fresh bearer token on every call.
//
// See also `fcm_token_providers.dart` for the save/listen providers.

/// FCM token diagnostics for the debug screen.
final fcmTokenStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(fcmTokenServiceProvider).getFcmTokenStatus();
});

/// Manually push the current FCM token to the server.
final refreshFcmTokenProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final logger = ref.read(loggerProvider);

    logger.log('Manually triggering FCM token refresh...');
    final success = await ref.read(fcmTokenServiceProvider).refreshFcmToken();

    if (success) {
      logger.log('Manual FCM token refresh successful');
    } else {
      logger.error('Manual FCM token refresh failed');
    }

    return success;
  };
});

/// Whether the server's copy of the FCM token is stale.
final fcmTokenNeedsUpdateProvider = FutureProvider.autoDispose<bool>((ref) async {
  return ref.watch(fcmTokenServiceProvider).shouldUpdateFcmToken();
});

/// The device's current FCM token, for debugging.
final currentFcmTokenProvider = FutureProvider.autoDispose<String?>((ref) async {
  return ref.watch(fcmTokenServiceProvider).getCurrentFcmToken();
});

/// Keeps the server's FCM token current while a user is signed in.
///
/// Replaces `fcmTokenAutoSaveWatcherProvider` and
/// `fcmTokenBackgroundManagerProvider`. The first fired a bare `Future.delayed`
/// from inside a provider body — untracked work that outlived the provider and
/// called the always-failing AuthService path. The second did nothing at all
/// beyond logging, on the since-removed assumption that AuthService had already
/// set up the listener.
final fcmTokenSyncProvider = Provider<void>((ref) {
  final logger = ref.read(loggerProvider);

  ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (previous, next) {
    final profile = next.valueOrNull;
    if (profile == null) return;

    final service = ref.read(fcmTokenServiceProvider);
    unawaited(() async {
      try {
        if (await service.shouldUpdateFcmToken()) {
          logger.log('FCM token needs update, triggering save...');
          final success = await service.saveFcmToken();
          success
              ? logger.log('Auto FCM token save successful')
              : logger.warning('Auto FCM token save failed');
        } else {
          logger.log('FCM token is up to date');
        }
        await service.setupFcmTokenRefreshListener();
      } catch (e) {
        logger.error('Error in FCM token sync: $e');
      }
    }());
  }, fireImmediately: true);

  ref.onDispose(() {
    unawaited(ref.read(fcmTokenServiceProvider).cancelTokenRefreshListener());
  });
});

// Login state enum
enum LoginState {
  initial,
  otpRequested,
  otpValidating,
  success,
  failure,
}