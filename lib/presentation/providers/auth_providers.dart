// lib/presentation/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/auth_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/auth_models.dart';
import '../../di/infrastructure_providers.dart';
import '../../di/service_providers.dart';


// authServiceProvider now declared in lib/di/service_providers.dart

// TODO(phase-3a): superseded by `authRepositoryProvider` in lib/di/auth_providers.dart,
// which is typed to the domain interface IAuthRepository and returns Result<T>.
// 35 call sites across 20 files still read this one — including 9 auth guards in
// app_router.dart. Renamed rather than deleted so the remaining debt is visible
// and the compiler points at every site that still needs moving.
final legacyAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final authManager = ref.watch(centralizedAuthManagerProvider);
  final logger = ref.watch(loggerProvider);
  
  return AuthRepository(
    authService: authService,
    authManager: authManager,
    logger: logger,
  );
});

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

// OTP request provider
final otpRequestProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(legacyAuthRepositoryProvider);
  final mobileNumber = ref.watch(mobileNumberProvider);
  
  // Validate mobile number
  if (mobileNumber.isEmpty || mobileNumber.length != 10) {
    throw Exception('Please enter a valid 10-digit mobile number');
  }
  
  return await repository.requestOtp(mobileNumber);
});

// OTP validation provider
final otpValidationProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(legacyAuthRepositoryProvider);
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
      final repository = _ref.read(legacyAuthRepositoryProvider);
      final response = await repository.validateOtp(mobileNumber, otp);
      
      if (response.authentication == 1) {
        // Save to centralized auth manager as well
        final authManager = _ref.read(centralizedAuthManagerProvider);
        final userProfile = UserProfile(
          mobile: mobileNumber,
          accessKey: response.accessKey,
          loginTime: DateTime.now(),
        );
        await authManager.saveUserProfile(userProfile);
        
        // Set login state to success
        _ref.read(loginStateProvider.notifier).state = LoginState.success;
        
        // Invalidate providers to force refresh - do this immediately after auth manager update
        _ref.invalidate(isLoggedInProvider);
        _ref.invalidate(userProfileProvider);
        
        // Wait a bit more to ensure all reactive providers are updated
        await Future.delayed(const Duration(milliseconds: 200));
        
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
  

}

// OTP validation notifier provider
final otpValidationNotifierProvider = StateNotifierProvider<OtpValidationNotifier, AsyncValue<OtpValidationResponse?>>((ref) {
  return OtpValidationNotifier(ref);
});

// Enhanced logout provider that clears favorites
final logoutProvider = Provider((ref) {
  return () async {
    final repository = ref.read(legacyAuthRepositoryProvider);
    await repository.logout();
    
    // Clear centralized auth manager as well
    final authManager = ref.read(centralizedAuthManagerProvider);
    await authManager.logout();
    
    // Clear login state
    ref.read(loginStateProvider.notifier).state = LoginState.initial;
    
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