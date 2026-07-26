// lib/domain/usecases/cart/refresh_cart.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/cart.dart';
import '../../repositories/i_cart_repository.dart';

final class RefreshCartParams {
  final Cart cart;

  const RefreshCartParams({required this.cart});
}

/// Re-reads prices and stock from the server so validation runs on current data.
///
/// An empty cart short-circuits: there is nothing to reconcile and no reason to
/// spend a request.
final class RefreshCart extends UseCase<Cart, RefreshCartParams> {
  final ICartRepository _repository;

  const RefreshCart(this._repository);

  @override
  Future<Result<Cart>> call(RefreshCartParams params) async {
    if (params.cart.isEmpty) return Ok(params.cart);
    return _repository.refreshFromServer(params.cart);
  }
}
