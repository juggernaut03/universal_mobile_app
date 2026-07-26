// lib/domain/usecases/catalogue/get_subcategories.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/catalogue.dart';
import '../../repositories/i_catalogue_repository.dart';

final class GetSubcategoriesParams extends UseCaseParams {
  final String categoryCode;

  const GetSubcategoriesParams({required this.categoryCode});

  @override
  List<Object?> get props => [categoryCode];
}

/// Lists the subcategories in a category, display-ready.
final class GetSubcategories
    extends UseCase<List<Subcategory>, GetSubcategoriesParams> {
  final ICatalogueRepository _repository;

  const GetSubcategories(this._repository);

  @override
  Future<Result<List<Subcategory>>> call(GetSubcategoriesParams params) async {
    if (params.categoryCode.isEmpty) {
      return const Err(ValidationFailure('Missing category.'));
    }
    final result = await _repository.subcategories(params.categoryCode);
    return result.map((list) => list.displayable);
  }
}
