// lib/data/repositories/auth_repository_impl.dart
//
// Implements IAuthRepository and ITokenStore.
//
// Strangler Fig step. This adapts the existing AuthService (HTTP + FCM) and
// CentralizedAuthManager (secure storage + streams) rather than rewriting them
// in one go — CentralizedAuthManager is referenced by 14 files, so replacing it
// outright would put the whole login path at risk in a single change.
//
// What is real today:
//   * the domain contract, so new code depends on IAuthRepository / ITokenStore
//   * typed failures instead of rethrown exceptions and silent nulls
//   * AuthSession as the currency, instead of `authentication == 1`
//
// TODO(phase-3a-followup): fold CentralizedAuthManager's storage and stream
// duties into AuthLocalDataSource and delete it, once consumers read this
// repository instead.

import '../../data/auth/centralized_auth_manager.dart';
import '../../core/error/exceptions.dart';
import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

final class AuthRepositoryImpl implements IAuthRepository, ITokenStore {
  final AuthService _authService;
  final CentralizedAuthManager _authManager;
  final Logger _logger;

  /// Injected so session expiry is testable without waiting for real time.
  final DateTime Function() _clock;

  AuthRepositoryImpl({
    required AuthService authService,
    required CentralizedAuthManager authManager,
    required Logger logger,
    DateTime Function()? clock,
  })  : _authService = authService,
        _authManager = authManager,
        _logger = logger,
        _clock = clock ?? DateTime.now;

  // ---- IAuthRepository ----

  @override
  Future<Result<OtpChallenge>> requestOtp(String mobile) {
    return guard(() async {
      final response = await _authService.requestOtp(mobile);

      // The backend reports failure inside a 200 body, so a non-success status
      // has to be promoted to an exception here or it would look like success.
      if (response.status != 'success') {
        throw ValidationException(
          response.reason.isNotEmpty
              ? response.reason
              : 'Could not send the OTP. Please try again.',
        );
      }

      final seconds = int.tryParse(response.expiryTime);
      return OtpChallenge(
        mobile: mobile,
        expiresIn: seconds == null ? null : Duration(seconds: seconds),
      );
    });
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String mobile,
    required String otp,
  }) {
    return guard(() async {
      final response = await _authService.validateOtp(mobile, otp);

      if (!response.isSuccessful()) {
        throw AuthException(
          response.message.isNotEmpty
              ? response.message
              : 'The OTP could not be verified.',
          requiresReauthentication: false,
        );
      }

      final session = AuthSession(
        mobile: mobile,
        accessToken: response.accessKey,
        issuedAt: _clock(),
        refreshToken: response.refreshToken,
      );

      await write(session);
      return session;
    });
  }

  @override
  Future<Result<AuthSession>> currentSession() {
    return guard(() async {
      final profile = await _authManager.getCurrentUserProfile();
      if (profile == null || profile.accessKey.isEmpty) {
        throw const AuthException('No stored session');
      }

      final session = _toSession(profile);
      if (!session.isValidAt(_clock())) {
        throw const AuthException('Session expired');
      }
      return session;
    });
  }

  @override
  Future<bool> isSignedIn() async {
    try {
      return await _authManager.isLoggedIn();
    } on Object catch (e) {
      // Asked on nearly every build; a storage hiccup must render as
      // "signed out", never as an error screen.
      _logger.warning('isSignedIn check failed, treating as signed out: $e');
      return false;
    }
  }

  @override
  Future<Result<void>> signOut() {
    return guard(() async {
      await _authManager.logout();
      // Legacy AuthService keeps its own copy; clearing only one leaves the
      // user half-signed-out.
      await _authService.logout();
      _logger.log('Signed out');
    });
  }

  @override
  Stream<bool> get signedInChanges => _authManager.loginStatusStream;

  // ---- ITokenStore ----

  @override
  Future<String?> readValidToken() async {
    try {
      return await _authManager.getValidAccessKey();
    } on Object catch (e) {
      _logger.warning('Token read failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) {
    return _authManager.saveUserProfile(
      UserProfile(
        mobile: session.mobile,
        accessKey: session.accessToken,
        loginTime: session.issuedAt,
        refreshToken: session.refreshToken,
        // The JWT's own `exp`, so expiry is the server's answer rather than a
        // duration guessed on the client.
        accessKeyExpiresAt: UserProfile.expiryFromJwt(session.accessToken),
      ),
    );
  }

  @override
  Future<void> clear() => _authManager.logout();

  // ---- internals ----

  AuthSession _toSession(UserProfile profile) => AuthSession(
        mobile: profile.mobile,
        accessToken: profile.accessKey,
        issuedAt: profile.loginTime,
        refreshToken: profile.refreshToken,
        // A renewable session outlives its access token, so `lifetime` — which
        // currentSession() checks — has to track the refresh window, not the
        // 10-day default. Without this, a restart more than 10 days after login
        // reported "Session expired" for a session the server would still renew.
        lifetime: profile.hasRefreshToken
            ? const Duration(days: 90)
            : const Duration(days: 10),
      );
}
