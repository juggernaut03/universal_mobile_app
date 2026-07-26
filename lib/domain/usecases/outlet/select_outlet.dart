// lib/domain/usecases/outlet/select_outlet.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/outlet.dart';
import '../../repositories/i_outlet_repository.dart';

final class SelectOutletParams extends UseCaseParams {
  final Outlet outlet;

  const SelectOutletParams({required this.outlet});

  @override
  List<Object?> get props => [outlet];
}

/// Sets the outlet the customer will shop from.
///
/// Refuses outlets that cannot take orders, so a closed store can never become
/// the active one — previously nothing stopped that, and the failure surfaced
/// later at checkout.
final class SelectOutlet extends UseCase<void, SelectOutletParams> {
  final IOutletRepository _repository;

  const SelectOutlet(this._repository);

  @override
  Future<Result<void>> call(SelectOutletParams params) async {
    if (!params.outlet.canAcceptOrders) {
      return Err(ValidationFailure(params.outlet.statusMessage));
    }
    return _repository.selectOutlet(params.outlet);
  }
}
