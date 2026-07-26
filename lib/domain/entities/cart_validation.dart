// lib/domain/entities/cart_validation.dart
//
// The single definition of "is this cart fit to check out".
//
// Three implementations previously existed:
//   * data/services/cart_validator.dart          (454 lines, HTTP + rules)
//   * providers/cart_validator_provider.dart     (579 lines, EnhancedCartValidator)
//   * providers/enhanced_cart_validator_provider.dart (338 lines, dead — deleted)
//
// All three mixed business rules with network calls, so none could be tested
// without a backend. The rules live here as pure functions over a Cart; the
// server round-trip that refreshes prices and stock stays in the data layer.

import 'package:meta/meta.dart';

import 'cart.dart';
import 'outlet.dart';

/// Why a cart cannot proceed to checkout.
@immutable
sealed class CartProblem {
  const CartProblem();

  /// Message shown to the user.
  String get message;

  /// Whether the app can fix this itself (by trimming the cart), or whether the
  /// customer has to act.
  bool get isAutoFixable;
}

/// The cart has nothing in it.
final class CartIsEmpty extends CartProblem {
  const CartIsEmpty();

  @override
  String get message => 'Your cart is empty.';

  @override
  bool get isAutoFixable => false;
}

/// The order value is under the outlet's minimum.
final class BelowMinimumOrder extends CartProblem {
  final double required;
  final double current;

  const BelowMinimumOrder({required this.required, required this.current});

  /// How much more the customer must add.
  double get shortfall => required - current;

  @override
  String get message =>
      'Add ₹${shortfall.toStringAsFixed(0)} more to reach the ₹${required.toStringAsFixed(0)} minimum order.';

  @override
  bool get isAutoFixable => false;
}

/// A product went out of stock while it sat in the cart.
final class LineOutOfStock extends CartProblem {
  final String productCode;
  final String productName;

  const LineOutOfStock({required this.productCode, required this.productName});

  @override
  String get message => '$productName is out of stock.';

  @override
  bool get isAutoFixable => true;
}

/// The requested quantity now exceeds what is available or permitted.
final class QuantityUnavailable extends CartProblem {
  final String productCode;
  final String productName;
  final int requested;
  final int available;

  const QuantityUnavailable({
    required this.productCode,
    required this.productName,
    required this.requested,
    required this.available,
  });

  @override
  String get message => available == 0
      ? '$productName is no longer available.'
      : 'Only $available of $productName left — you asked for $requested.';

  @override
  bool get isAutoFixable => true;
}

/// The outlet stopped trading, or stopped offering any fulfilment method.
final class OutletUnavailable extends CartProblem {
  final String outletMessage;

  const OutletUnavailable(this.outletMessage);

  @override
  String get message => outletMessage;

  @override
  bool get isAutoFixable => false;
}

/// The verdict on a cart.
@immutable
final class CartValidation {
  final List<CartProblem> problems;

  const CartValidation(this.problems);

  const CartValidation.valid() : problems = const [];

  bool get isValid => problems.isEmpty;

  /// Whether every problem can be resolved by trimming the cart automatically.
  bool get isAutoFixable =>
      problems.isNotEmpty && problems.every((p) => p.isAutoFixable);

  /// The first problem, for a single-line message.
  CartProblem? get primary => problems.isEmpty ? null : problems.first;

  /// Problems that block checkout and need the customer to act.
  List<CartProblem> get blocking =>
      List.unmodifiable(problems.where((p) => !p.isAutoFixable));
}

/// Applies the checkout rules to a cart.
///
/// Pure and synchronous — no HTTP, no storage, no clock. Every rule below is
/// therefore unit-testable, which none of the three previous implementations
/// were.
final class CartValidationPolicy {
  const CartValidationPolicy();

  /// Checks [cart] against [outlet].
  ///
  /// Rules, in the order the user should hear about them:
  ///   1. the cart must not be empty
  ///   2. the outlet must be able to take the order
  ///   3. every line must still be fulfillable
  ///   4. the total must clear the outlet's minimum
  CartValidation validate({required Cart cart, required Outlet outlet}) {
    if (cart.isEmpty) {
      return const CartValidation([CartIsEmpty()]);
    }

    if (!outlet.canAcceptOrders) {
      return CartValidation([OutletUnavailable(outlet.statusMessage)]);
    }

    final problems = <CartProblem>[];

    for (final line in cart.lines) {
      if (line.product.isOutOfStock) {
        problems.add(LineOutOfStock(
          productCode: line.product.code,
          productName: line.product.name,
        ));
      } else if (!line.isSatisfiable) {
        problems.add(QuantityUnavailable(
          productCode: line.product.code,
          productName: line.product.name,
          requested: line.quantity,
          available: line.maxAllowed,
        ));
      }
    }

    // The minimum is checked against what can actually be bought, not what is
    // sitting in the cart — otherwise an out-of-stock line could carry a cart
    // over the threshold and the order would fail at the server instead.
    final payable = cart.withoutUnsatisfiableLines().subtotal;
    if (!outlet.meetsMinimumOrder(payable)) {
      problems.add(BelowMinimumOrder(
        required: outlet.minOrderAmount.toDouble(),
        current: payable,
      ));
    }

    return CartValidation(List.unmodifiable(problems));
  }
}
