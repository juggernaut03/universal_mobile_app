// lib/domain/usecases/auth/sign_out.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../repositories/i_auth_repository.dart';

/// Ends the session and clears derived local state.
final class SignOut extends UseCase<void, NoParams> {
  final IAuthRepository _repository;

  const SignOut(this._repository);

  @override
  Future<Result<void>> call(NoParams params) => _repository.signOut();
}
