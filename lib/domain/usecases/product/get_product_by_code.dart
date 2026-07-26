// lib/domain/usecases/product/get_product_by_code.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/product.dart';
import '../../repositories/i_product_repository.dart';

/// Arguments for [GetProductByCode].
final class GetProductByCodeParams extends UseCaseParams {
  /// Business product code.
  final String code;

  /// Store whose price and stock apply.
  final String storeCode;

  const GetProductByCodeParams({
    required this.code,
    required this.storeCode,
  });

  @override
  List<Object?> get props => [code, storeCode];
}

/// Fetches one product by its business code.
///
/// Replaces `ProductRepository.getProductByCode`, which returned
/// `Future<ProductModel?>` and collapsed "not found", "offline", "HTTP 500" and
/// "malformed response" into a single `null`.
final class GetProductByCode
    extends UseCase<Product, GetProductByCodeParams> {
  final IProductRepository _repository;

  const GetProductByCode(this._repository);

  @override
  Future<Result<Product>> call(GetProductByCodeParams params) {
    return _repository.getProductByCode(
      code: params.code,
      storeCode: params.storeCode,
    );
  }
}
