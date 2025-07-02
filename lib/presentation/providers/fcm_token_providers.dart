// lib/presentation/providers/fcm_token_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/data/models/auth_models.dart';
import '../../data/services/fcm_token_service.dart';
import '../../data/repositories/fcm_token_repository.dart';
import 'auth_providers.dart';
import 'launch_flow_provider.dart';

// Provider for FcmTokenService
final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  final logger = ref.watch(loggerProvider);
  return FcmTokenService(
    client: http.Client(),
    logger: logger,
    firebaseMessaging: FirebaseMessaging.instance,
  );
});

// Provider for FcmTokenRepository
final fcmTokenRepositoryProvider = Provider<FcmTokenRepository>((ref) {
  final fcmTokenService = ref.watch(fcmTokenServiceProvider);
  final logger = ref.watch(loggerProvider);
  
  return FcmTokenRepository(
    fcmTokenService: fcmTokenService,
    logger: logger,
  );
});

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