// lib/domain/usecases/auth/verify_otp.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/auth_session.dart';
import '../../repositories/i_auth_repository.dart';

final class VerifyOtpParams extends UseCaseParams {
  final String mobile;
  final String otp;

  const VerifyOtpParams({required this.mobile, required this.otp});

  @override
  List<Object?> get props => [mobile, otp];
}

/// Exchanges a one-time code for a session.
final class VerifyOtp extends UseCase<AuthSession, VerifyOtpParams> {
  final IAuthRepository _repository;

  const VerifyOtp(this._repository);

  static const int _minOtpLength = 4;

  @override
  Future<Result<AuthSession>> call(VerifyOtpParams params) async {
    final otp = params.otp.trim();

    if (otp.length < _minOtpLength || !RegExp(r'^\d+$').hasMatch(otp)) {
      return const Err(ValidationFailure('Please enter a valid OTP.'));
    }

    return _repository.verifyOtp(mobile: params.mobile.trim(), otp: otp);
  }
}
