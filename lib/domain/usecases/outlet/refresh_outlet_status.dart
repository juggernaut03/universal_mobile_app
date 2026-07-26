// lib/domain/usecases/outlet/refresh_outlet_status.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/outlet.dart';
import '../../repositories/i_outlet_repository.dart';

final class RefreshOutletStatusParams extends UseCaseParams {
  final String storeCode;

  const RefreshOutletStatusParams({required this.storeCode});

  @override
  List<Object?> get props => [storeCode];
}

/// Re-reads an outlet's trading state, to catch a store closing mid-session.
final class RefreshOutletStatus
    extends UseCase<Outlet, RefreshOutletStatusParams> {
  final IOutletRepository _repository;

  const RefreshOutletStatus(this._repository);

  @override
  Future<Result<Outlet>> call(RefreshOutletStatusParams params) =>
      _repository.refreshStatus(params.storeCode);
}
