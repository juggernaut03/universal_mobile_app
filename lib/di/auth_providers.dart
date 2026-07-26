// lib/di/auth_providers.dart
//
// Composition root — the auth slice (Phase 3a).
//
// Named `di/auth_providers.dart` while the legacy
// `presentation/providers/auth_providers.dart` still exists. The legacy file
// holds UI state (mobileNumberProvider, otpProvider, loginStateProvider) and
// is emptied of wiring as consumers move onto these use cases.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/i_auth_repository.dart';
import '../domain/usecases/auth/get_current_session.dart';
import '../domain/usecases/auth/request_otp.dart';
import '../domain/usecases/auth/sign_out.dart';
import '../domain/usecases/auth/verify_otp.dart';
import '../domain/usecases/auth/watch_signed_in.dart';
import 'infrastructure_providers.dart';
import 'service_providers.dart';

/// Single instance backing both auth interfaces.
///
/// Private: nothing outside this file may depend on the concrete class. The two
/// public providers below expose it only through its interfaces, so a consumer
/// needing a token cannot reach sign-out.
final _authRepositoryImplProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(
    authService: ref.watch(authServiceProvider),
    authManager: ref.watch(centralizedAuthManagerProvider),
    logger: ref.watch(loggerProvider),
  );
});

/// Full authentication contract, for login and session flows.
final authRepositoryProvider = Provider<IAuthRepository>(
  (ref) => ref.watch(_authRepositoryImplProvider),
);

/// Narrow credential access, for collaborators that only attach a bearer token.
///
/// Interface segregation in practice: `ApiClient` needs `readValidToken()` and
/// nothing else, so it must not be handed the repository that can sign the user
/// out.
final tokenStoreProvider = Provider<ITokenStore>(
  (ref) => ref.watch(_authRepositoryImplProvider),
);

// ---- use cases ----

final requestOtpUseCaseProvider =
    Provider<RequestOtp>((ref) => RequestOtp(ref.watch(authRepositoryProvider)));

final verifyOtpUseCaseProvider =
    Provider<VerifyOtp>((ref) => VerifyOtp(ref.watch(authRepositoryProvider)));

final signOutUseCaseProvider =
    Provider<SignOut>((ref) => SignOut(ref.watch(authRepositoryProvider)));

final getCurrentSessionUseCaseProvider = Provider<GetCurrentSession>(
  (ref) => GetCurrentSession(ref.watch(authRepositoryProvider)),
);

final watchSignedInUseCaseProvider = Provider<WatchSignedIn>(
  (ref) => WatchSignedIn(ref.watch(authRepositoryProvider)),
);
