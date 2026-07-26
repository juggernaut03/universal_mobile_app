// lib/domain/usecases/cart/validate_cart.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/cart.dart';
import '../../entities/cart_validation.dart';
import '../../entities/outlet.dart';

final class ValidateCartParams {
  final Cart cart;
  final Outlet outlet;

  const ValidateCartParams({required this.cart, required this.outlet});
}

/// Applies the checkout rules to a cart.
///
/// Synchronous: the rules are pure. The server round-trip that refreshes prices
/// belongs to [RefreshCart] and runs before this.
final class ValidateCart
    extends SyncUseCase<CartValidation, ValidateCartParams> {
  final CartValidationPolicy _policy;

  const ValidateCart([this._policy = const CartValidationPolicy()]);

  @override
  Result<CartValidation> call(ValidateCartParams params) =>
      Ok(_policy.validate(cart: params.cart, outlet: params.outlet));
}
