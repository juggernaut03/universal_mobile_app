// lib/presentation/providers/fcm_token_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/infrastructure_providers.dart';
import '../../di/repository_providers.dart';
import 'auth_providers.dart';

// These providers read the session with `ref.watch(userProfileProvider.future)`
// — the provider's future, not the AsyncValue's.
//
// They previously called `.future` on the AsyncValue returned by
// `ref.watch(userProfileProvider)`. AsyncValue has no such member, and rather
// than fix the call the error was silenced with:
//
//     extension on AsyncValue<UserProfile?> { get future => null; }
//
// which made every `await userProfileAsync.future` evaluate to null. Both
// providers below therefore took the "user not logged in" branch on every run,
// for every signed-in user, and FCM tokens were never saved to the server.

/// Saves the current device's FCM token for the signed-in user, if it changed.
final saveFcmTokenProvider = FutureProvider.autoDispose<bool>((ref) async {
  final logger = ref.read(loggerProvider);
  final userProfile = await ref.watch(userProfileProvider.future);

  if (userProfile == null) {
    logger.log('No user profile available for FCM token save');
    return false;
  }

  final fcmRepository = ref.watch(fcmTokenRepositoryProvider);

  if (!await fcmRepository.shouldUpdateToken()) {
    logger.log('FCM token does not need update');
    return true;
  }

  return fcmRepository.saveTokenForCurrentUser(userProfile);
});

/// Keeps the server's copy of the FCM token current for as long as the user
/// stays signed in.
///
/// The subscription is cancelled when this provider is disposed. The equivalent
/// listener in AuthService was never cancelled and captured the access token
/// live at login, so after the first refresh rotated that token it authenticated
/// with a dead credential forever.
final fcmTokenRefreshListenerProvider = Provider.autoDispose<void>((ref) {
  final fcmRepository = ref.watch(fcmTokenRepositoryProvider);

  ref.listen<AsyncValue<dynamic>>(userProfileProvider, (previous, next) {
    final profile = next.valueOrNull;
    if (profile != null) {
      fcmRepository.setupTokenRefreshListener();
    }
  }, fireImmediately: true);

  ref.onDispose(fcmRepository.cancelTokenRefreshListener);
});

/// Saves the FCM token on demand, regardless of whether it looks stale.
final manualSaveFcmTokenProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final userProfile = await ref.read(userProfileProvider.future);
    if (userProfile == null) {
      ref.read(loggerProvider).error('Cannot save FCM token: user not logged in');
      return false;
    }

    return ref.read(fcmTokenRepositoryProvider).saveTokenForCurrentUser(userProfile);
  };
});
