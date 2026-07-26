// test/domain/auth_usecases_test.dart
//
// Input rules that previously lived in the UI. `otpRequestProvider` threw
// `Exception('Please enter a valid 10-digit mobile number')`, and login_screen
// re-checked the same rule independently — two definitions that could drift.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/domain/entities/auth_session.dart';
import 'package:patelmart/domain/repositories/i_auth_repository.dart';
import 'package:patelmart/domain/usecases/auth/request_otp.dart';
import 'package:patelmart/domain/usecases/auth/sign_out.dart';
import 'package:patelmart/domain/usecases/auth/verify_otp.dart';
import 'package:patelmart/core/usecase/usecase.dart';

final class _FakeAuthRepository implements IAuthRepository {
  String? lastRequestedMobile;
  String? lastVerifiedMobile;
  String? lastVerifiedOtp;
  int signOutCalls = 0;
  Result<AuthSession> verifyResult =
      Ok(AuthSession(mobile: '9876543210', accessToken: 'jwt', issuedAt: DateTime(2026)));

  @override
  Future<Result<OtpChallenge>> requestOtp(String mobile) async {
    lastRequestedMobile = mobile;
    return Ok(OtpChallenge(mobile: mobile));
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    lastVerifiedMobile = mobile;
    lastVerifiedOtp = otp;
    return verifyResult;
  }

  @override
  Future<Result<AuthSession>> currentSession() async =>
      const Err(AuthFailure('none'));

  @override
  Future<bool> isSignedIn() async => false;

  @override
  Future<Result<void>> signOut() async {
    signOutCalls++;
    return const Ok(null);
  }

  @override
  Stream<bool> get signedInChanges => const Stream.empty();
}

void main() {
  late _FakeAuthRepository repo;

  setUp(() => repo = _FakeAuthRepository());

  group('RequestOtp validation', () {
    test('rejects an empty number without calling the backend', () async {
      final result = await RequestOtp(repo)(const RequestOtpParams(mobile: ''));

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.lastRequestedMobile, isNull);
    });

    test('rejects a short number', () async {
      final result =
          await RequestOtp(repo)(const RequestOtpParams(mobile: '98765'));

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.lastRequestedMobile, isNull);
    });

    test('rejects non-numeric input of the right length', () async {
      final result =
          await RequestOtp(repo)(const RequestOtpParams(mobile: '98765abcde'));

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('accepts a valid number and trims surrounding whitespace', () async {
      final result = await RequestOtp(repo)(
        const RequestOtpParams(mobile: '  9876543210  '),
      );

      expect(result.isOk, isTrue);
      expect(repo.lastRequestedMobile, '9876543210');
    });

    test('a validation message is safe to render directly', () async {
      final result = await RequestOtp(repo)(const RequestOtpParams(mobile: '1'));

      final failure = result.failureOrNull!;
      expect(failure.userMessage, failure.message);
      expect(failure.isRetryable, isFalse);
    });
  });

  group('VerifyOtp validation', () {
    test('rejects an OTP shorter than four digits', () async {
      final result = await VerifyOtp(repo)(
        const VerifyOtpParams(mobile: '9876543210', otp: '12'),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.lastVerifiedOtp, isNull);
    });

    test('rejects a non-numeric OTP', () async {
      final result = await VerifyOtp(repo)(
        const VerifyOtpParams(mobile: '9876543210', otp: 'abcd'),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('passes a valid OTP through, trimmed', () async {
      final result = await VerifyOtp(repo)(
        const VerifyOtpParams(mobile: '9876543210', otp: ' 1234 '),
      );

      expect(result.isOk, isTrue);
      expect(repo.lastVerifiedOtp, '1234');
      expect(repo.lastVerifiedMobile, '9876543210');
    });

    test('surfaces a repository AuthFailure unchanged', () async {
      repo.verifyResult = const Err(AuthFailure('wrong code'));

      final result = await VerifyOtp(repo)(
        const VerifyOtpParams(mobile: '9876543210', otp: '1234'),
      );

      expect(result.failureOrNull, isA<AuthFailure>());
    });
  });

  group('SignOut', () {
    test('delegates to the repository', () async {
      final result = await SignOut(repo)(const NoParams());

      expect(result.isOk, isTrue);
      expect(repo.signOutCalls, 1);
    });
  });
}
