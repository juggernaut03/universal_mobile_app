// lib/domain/usecases/product/get_products.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/product.dart';
import '../../repositories/i_product_repository.dart';

/// Arguments for [GetProducts].
///
/// Extends [UseCaseParams] to inherit value equality — Riverpod `family`
/// providers key their cache by argument equality, so without it every rebuild
/// would allocate a fresh provider and refetch.
final class GetProductsParams extends UseCaseParams {
  final String storeCode;
  final String departmentId;
  final String categoryId;
  final String subCategoryId;

  const GetProductsParams({
    required this.storeCode,
    required this.departmentId,
    required this.categoryId,
    required this.subCategoryId,
  });

  @override
  List<Object?> get props =>
      [storeCode, departmentId, categoryId, subCategoryId];
}

/// Lists the sellable products in a sub-category at a store.
final class GetProducts extends UseCase<List<Product>, GetProductsParams> {
  final IProductRepository _repository;

  const GetProducts(this._repository);

  @override
  Future<Result<List<Product>>> call(GetProductsParams params) {
    return _repository.getProducts(
      storeCode: params.storeCode,
      departmentId: params.departmentId,
      categoryId: params.categoryId,
      subCategoryId: params.subCategoryId,
    );
  }
}
