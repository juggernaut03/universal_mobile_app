// lib/domain/usecases/catalogue/get_departments.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/catalogue.dart';
import '../../repositories/i_catalogue_repository.dart';

final class GetDepartmentsParams extends UseCaseParams {
  final String storeCode;

  const GetDepartmentsParams({required this.storeCode});

  @override
  List<Object?> get props => [storeCode];
}

/// Lists the departments a store carries, display-ready.
///
/// Filtering out unnamed rows and sorting by sequence used to be repeated in
/// each screen — or skipped, which is how placeholder entries reached the UI.
final class GetDepartments
    extends UseCase<List<Department>, GetDepartmentsParams> {
  final ICatalogueRepository _repository;

  const GetDepartments(this._repository);

  @override
  Future<Result<List<Department>>> call(GetDepartmentsParams params) async {
    if (params.storeCode.isEmpty) {
      return const Err(ValidationFailure('Please select a store first.'));
    }
    final result = await _repository.departments(params.storeCode);
    return result.map((list) => list.displayable);
  }
}
