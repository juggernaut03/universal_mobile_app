// lib/presentation/providers/fcm_token_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/models/auth_models.dart';
import 'auth_providers.dart';
import '../../di/repository_providers.dart';
import '../../di/infrastructure_providers.dart';

// Import the service provider from the service file
// (The fcmTokenServiceProvider is now defined in fcm_token_service.dart)

// Provider for FcmTokenRepository

// Provider to save FCM token for the current user
final saveFcmTokenProvider = FutureProvider.autoDispose<bool>((ref) async {
  final fcmRepository = ref.watch(fcmTokenRepositoryProvider);
  final userProfileAsync = ref.watch(userProfileProvider);
  
  // Wait for user profile to be available
  final userProfile = await userProfileAsync.future;
  
  if (userProfile == null) {
    ref.read(loggerProvider).log('No user profile available for FCM token save');
    return false;
  }
  
  // Check if token needs to be updated
  final shouldUpdate = await fcmRepository.shouldUpdateToken();
  if (!shouldUpdate) {
    ref.read(loggerProvider).log('FCM token does not need update');
    return true; // Already up to date
  }
  
  // Save the token
  return await fcmRepository.saveTokenForCurrentUser(userProfile);
});

extension on AsyncValue<UserProfile?> {
  get future => null;
}

// Provider to set up FCM token refresh listener
final fcmTokenRefreshListenerProvider = Provider.autoDispose<void>((ref) {
  final fcmRepository = ref.watch(fcmTokenRepositoryProvider);
  final userProfileAsync = ref.watch(userProfileProvider);
  
  userProfileAsync.whenData((userProfile) {
    if (userProfile != null) {
      fcmRepository.setupTokenRefreshListener(userProfile);
    }
  });
  
  return;
});

// Manual provider to save FCM token
final manualSaveFcmTokenProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final fcmRepository = ref.read(fcmTokenRepositoryProvider);
    final userProfileAsync = ref.read(userProfileProvider);
    
    final userProfile = await userProfileAsync.future;
    if (userProfile == null) {
      ref.read(loggerProvider).error('Cannot save FCM token: user not logged in');
      return false;
    }
    
    return await fcmRepository.saveTokenForCurrentUser(userProfile);
  };
});