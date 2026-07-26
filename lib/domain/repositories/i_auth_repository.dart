// lib/domain/repositories/i_auth_repository.dart

import '../../core/result/result.dart';
import '../entities/auth_session.dart';

/// Authentication and session lifecycle.
///
/// Split from [ITokenStore] on purpose (interface segregation): the many
/// collaborators that only need to read a token — the HTTP client, repositories
/// attaching a bearer header — depend on the two-method [ITokenStore] rather
/// than on this six-method contract.
abstract interface class IAuthRepository {
  /// Asks the backend to send an OTP to [mobile].
  ///
  /// Yields `Err(ValidationFailure)` for a malformed number, so the UI no
  /// longer has to pre-validate by throwing raw `Exception`s.
  Future<Result<OtpChallenge>> requestOtp(String mobile);

  /// Exchanges [otp] for a session.
  ///
  /// Yields `Err(AuthFailure)` when the code is wrong or expired.
  Future<Result<AuthSession>> verifyOtp({
    required String mobile,
    required String otp,
  });

  /// The stored session, or `Err(AuthFailure)` when signed out or expired.
  Future<Result<AuthSession>> currentSession();

  /// Whether a valid session exists. Never fails — absence is `false`, not an
  /// error, because every screen asks this on build.
  Future<bool> isSignedIn();

  /// Clears the session and all derived local state.
  Future<Result<void>> signOut();

  /// Emits whenever sign-in state changes, so widgets react without polling.
  Stream<bool> get signedInChanges;
}

/// Read/write access to the stored credential.
///
/// Deliberately narrow. `ApiClient` needs exactly one of these methods; giving
/// it the full [IAuthRepository] would let a networking class trigger sign-out
/// flows it has no business initiating.
abstract interface class ITokenStore {
  /// The current access token, or null when absent or expired.
  Future<String?> readValidToken();

  /// Persists a session.
  Future<void> write(AuthSession session);

  /// Removes the stored session.
  Future<void> clear();
}
