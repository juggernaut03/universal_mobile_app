// lib/presentation/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/presentation/providers/favorites_provider.dart';
import '../../core/network/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/auth_models.dart';
import 'launch_flow_provider.dart';

// Provider for FlutterSecureStorage
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Provider for HTTP Client (new - for FCM token API calls)
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

// Provider for Firebase Messaging (new - for FCM token functionality)
final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

// Enhanced AuthService provider with FCM integration
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);
  final httpClient = ref.watch(httpClientProvider);
  final firebaseMessaging = ref.watch(firebaseMessagingProvider);
  
  return AuthService(
    apiClient: apiClient,
    secureStorage: secureStorage,
    logger: logger,
    httpClient: httpClient,
    firebaseMessaging: firebaseMessaging,
  );
});

// Provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  final logger = ref.watch(loggerProvider);
  return ApiClient(logger: logger);
});

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final logger = ref.watch(loggerProvider);
  
  return AuthRepository(
    authService: authService,
    logger: logger,
  );
});

// Provider to check if user is logged in
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  return await repository.isLoggedIn();
});

// Provider for user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  return await repository.getUserProfile();
});

// State providers for login process
final mobileNumberProvider = StateProvider<String>((ref) => '');
final otpProvider = StateProvider<String>((ref) => '');
final loginStateProvider = StateProvider<LoginState>((ref) => LoginState.initial);

// OTP request provider
final otpRequestProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  final mobileNumber = ref.watch(mobileNumberProvider);
  
  // Validate mobile number
  if (mobileNumber.isEmpty || mobileNumber.length != 10) {
    throw Exception('Please enter a valid 10-digit mobile number');
  }
  
  return await repository.requestOtp(mobileNumber);
});

// OTP validation provider
final otpValidationProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  final mobileNumber = ref.watch(mobileNumberProvider);
  final otp = ref.watch(otpProvider);
  
  // Validate OTP
  if (otp.isEmpty || otp.length < 4) {
    throw Exception('Please enter a valid OTP');
  }
  
  return await repository.validateOtp(mobileNumber, otp);
});

// Enhanced OTP validation notifier with FCM token integration
class OtpValidationNotifier extends StateNotifier<AsyncValue<OtpValidationResponse?>> {
  final Ref _ref;
  
  OtpValidationNotifier(this._ref) : super(const AsyncValue.data(null));
  
  Future<void> validateOtp(String mobileNumber, String otp) async {
    state = const AsyncValue.loading();
    
    try {
      final repository = _ref.read(authRepositoryProvider);
      final response = await repository.validateOtp(mobileNumber, otp);
      
      if (response.authentication == 1) {
        // Set login state to success
        _ref.read(loginStateProvider.notifier).state = LoginState.success;
        
        // Initialize favorites after successful login
        _initializeFavoritesAfterLogin();
        
        // FCM token will be automatically saved by the AuthService
        // No additional code needed here as it's handled in _saveUserCredentials
        
      } else {
        // Set login state to failure
        _ref.read(loginStateProvider.notifier).state = LoginState.failure;
      }
      
      state = AsyncValue.data(response);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      _ref.read(loginStateProvider.notifier).state = LoginState.failure;
    }
  }
  
  void _initializeFavoritesAfterLogin() {
    // Delay initialization to ensure user profile is saved
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        final favoritesNotifier = _ref.read(favoritesProvider.notifier);
        favoritesNotifier.initializeFavorites();
        
        final logger = _ref.read(loggerProvider);
        logger.log('Initializing favorites after login');
      } catch (e) {
        // Handle error silently as this is not critical
        final logger = _ref.read(loggerProvider);
        logger.error('Error initializing favorites after login: $e');
      }
    });
  }
}

// OTP validation notifier provider
final otpValidationNotifierProvider = StateNotifierProvider<OtpValidationNotifier, AsyncValue<OtpValidationResponse?>>((ref) {
  return OtpValidationNotifier(ref);
});

// Enhanced logout provider that clears favorites
final logoutProvider = Provider((ref) {
  return () async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    
    // Clear login state
    ref.read(loginStateProvider.notifier).state = LoginState.initial;
    
    // Clear favorites when logging out
    try {
      // Clear favorites state
      // ref.read(favoritesProvider.notifier).clearFavorites();
    } catch (e) {
      // Handle error silently
    }
    
    // Invalidate user profile and login status
    ref.invalidate(userProfileProvider);
    ref.invalidate(isLoggedInProvider);
  };
});

// ========== NEW FCM TOKEN PROVIDERS ==========

// Provider to get FCM token status (for debugging)
final fcmTokenStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getFcmTokenStatus();
});

// Provider to manually refresh FCM token
final refreshFcmTokenProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final authService = ref.read(authServiceProvider);
    final logger = ref.read(loggerProvider);
    
    logger.log('Manually triggering FCM token refresh...');
    final success = await authService.refreshFcmToken();
    
    if (success) {
      logger.log('Manual FCM token refresh successful');
    } else {
      logger.error('Manual FCM token refresh failed');
    }
    
    return success;
  };
});

// Provider to check if FCM token needs update
final fcmTokenNeedsUpdateProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.shouldUpdateFcmToken();
});

// Provider to get current FCM token (for debugging)
final currentFcmTokenProvider = FutureProvider.autoDispose<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentFcmToken();
});

// Provider for FCM token operations (direct access to auth service FCM methods)
final fcmTokenOperationsProvider = Provider<AuthService>((ref) {
  return ref.watch(authServiceProvider);
});

// Auto FCM token save watcher (automatically saves FCM token when user logs in)
final fcmTokenAutoSaveWatcherProvider = Provider<void>((ref) {
  // Watch user profile changes
  final userProfileAsync = ref.watch(userProfileProvider);
  final logger = ref.read(loggerProvider);
  
  userProfileAsync.whenData((userProfile) {
    if (userProfile != null) {
      // User is logged in, check if FCM token needs to be saved
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          final authService = ref.read(authServiceProvider);
          final needsUpdate = await authService.shouldUpdateFcmToken();
          
          if (needsUpdate) {
            logger.log('FCM token needs update, triggering save...');
            final success = await authService.refreshFcmToken();
            
            if (success) {
              logger.log('Auto FCM token save successful');
            } else {
              logger.warning('Auto FCM token save failed');
            }
          } else {
            logger.log('FCM token is up to date');
          }
        } catch (e) {
          logger.error('Error in auto FCM token save: $e');
        }
      });
    }
  });
  
  return;
});

// Background FCM token manager (sets up token refresh listener)
final fcmTokenBackgroundManagerProvider = Provider<void>((ref) {
  final userProfileAsync = ref.watch(userProfileProvider);
  final logger = ref.read(loggerProvider);
  
  userProfileAsync.whenData((userProfile) {
    if (userProfile != null) {
      logger.log('Setting up FCM token background management for: ${userProfile.mobile}');
      
      // The AuthService already sets up the token refresh listener
      // in _saveUserCredentials, so we don't need to do anything here.
      // This provider exists mainly for monitoring and can be used
      // for additional FCM token management logic if needed.
    }
  });
  
  return;
});

// Login state enum
enum LoginState {
  initial,
  otpRequested,
  otpValidating,
  success,
  failure,
}