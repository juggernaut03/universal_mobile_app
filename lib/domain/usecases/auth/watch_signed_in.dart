// lib/domain/usecases/auth/watch_signed_in.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../repositories/i_auth_repository.dart';

/// Emits sign-in state changes so the UI reacts without polling.
final class WatchSignedIn extends StreamUseCase<bool, NoParams> {
  final IAuthRepository _repository;

  const WatchSignedIn(this._repository);

  @override
  Stream<Result<bool>> call(NoParams params) =>
      _repository.signedInChanges.map<Result<bool>>(Ok.new);
}
