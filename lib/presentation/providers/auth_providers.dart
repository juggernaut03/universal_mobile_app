// lib/presentation/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);
  
  return AuthService(
    apiClient: apiClient,
    secureStorage: secureStorage,
    logger: logger,
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

// OTP validation notifier
// lib/presentation/providers/auth_providers.dart
// Find the OtpValidationNotifier class and update the _initializeFavoritesAfterLogin method

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
    // We'll import this in the actual file
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

// Login state enum
enum LoginState {
  initial,
  otpRequested,
  otpValidating,
  success,
  failure,
}