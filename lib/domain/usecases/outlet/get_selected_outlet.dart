// lib/domain/usecases/outlet/get_selected_outlet.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/outlet.dart';
import '../../repositories/i_outlet_repository.dart';

/// Reads the currently selected outlet.
final class GetSelectedOutlet extends UseCase<Outlet, NoParams> {
  final IOutletRepository _repository;

  const GetSelectedOutlet(this._repository);

  @override
  Future<Result<Outlet>> call(NoParams params) => _repository.selectedOutlet();
}
