// lib/domain/usecases/catalogue/get_categories.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/catalogue.dart';
import '../../repositories/i_catalogue_repository.dart';

final class GetCategoriesParams extends UseCaseParams {
  final String departmentCode;
  final String storeCode;

  const GetCategoriesParams({
    required this.departmentCode,
    required this.storeCode,
  });

  @override
  List<Object?> get props => [departmentCode, storeCode];
}

/// Lists the categories in a department, display-ready.
final class GetCategories extends UseCase<List<Category>, GetCategoriesParams> {
  final ICatalogueRepository _repository;

  const GetCategories(this._repository);

  @override
  Future<Result<List<Category>>> call(GetCategoriesParams params) async {
    if (params.storeCode.isEmpty || params.departmentCode.isEmpty) {
      return const Err(ValidationFailure('Missing store or department.'));
    }
    final result = await _repository.categories(
      departmentCode: params.departmentCode,
      storeCode: params.storeCode,
    );
    return result.map((list) => list.displayable);
  }
}
