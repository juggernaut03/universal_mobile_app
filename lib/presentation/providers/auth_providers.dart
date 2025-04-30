// lib/presentation/providers/auth_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

// Logout provider
final logoutProvider = Provider((ref) {
  return () async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    ref.read(loginStateProvider.notifier).state = LoginState.initial;
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