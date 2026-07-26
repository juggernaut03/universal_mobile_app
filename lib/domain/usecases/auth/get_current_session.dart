// lib/domain/usecases/auth/get_current_session.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/auth_session.dart';
import '../../repositories/i_auth_repository.dart';

/// Reads the stored session.
final class GetCurrentSession extends UseCase<AuthSession, NoParams> {
  final IAuthRepository _repository;

  const GetCurrentSession(this._repository);

  @override
  Future<Result<AuthSession>> call(NoParams params) =>
      _repository.currentSession();
}
