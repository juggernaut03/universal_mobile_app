// lib/domain/entities/cart.dart
//
// The cart, as a value.
//
// Replaces the CartItem that lived at cart_provider.dart:18 — inside a
// StateNotifier, holding a ProductModel DTO. Five data-layer files imported a
// UI provider just to reach it. It now holds a Product entity and lives here.

import 'package:meta/meta.dart';

import 'product.dart';

/// One product plus how many of it the customer wants.
@immutable
final class CartLine {
  final Product product;
  final int quantity;

  const CartLine({required this.product, required this.quantity});

  /// Line total at the selling price.
  double get total => product.sellingPrice * quantity;

  /// Line total at MRP, for the struck-through price.
  double get totalAtMrp => product.mrp * quantity;

  /// Amount saved on this line.
  double get savings => totalAtMrp - total;

  /// Whether the quantity is still purchasable given current stock and caps.
  ///
  /// Stock changes while the cart sits there, so a line valid at add-time can
  /// become invalid before checkout.
  bool get isSatisfiable => product.canPurchaseQuantity(quantity);

  /// The largest quantity currently allowed for this product.
  int get maxAllowed => product.purchasableQuantity;

  CartLine copyWith({Product? product, int? quantity}) =>
      CartLine(product: product ?? this.product, quantity: quantity ?? this.quantity);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartLine &&
          other.product == product &&
          other.quantity == quantity;

  @override
  int get hashCode => Object.hash(product, quantity);

  @override
  String toString() => 'CartLine(${product.code} x$quantity)';
}

/// The customer's cart for one store.
///
/// Immutable: every mutation returns a new Cart. The previous implementation
/// mutated a `List<CartItem>` in place inside the notifier, so no caller could
/// hold a stable snapshot to compare against.
@immutable
final class Cart {
  final List<CartLine> lines;

  /// Store these prices and stock levels belong to.
  ///
  /// A cart is only meaningful for one store — prices differ per outlet, so
  /// carrying lines across a store switch would show the wrong totals.
  final String storeCode;

  const Cart({required this.lines, required this.storeCode});

  /// An empty cart for a store.
  const Cart.empty(this.storeCode) : lines = const [];

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// Distinct products in the cart.
  int get lineCount => lines.length;

  /// Total units across all lines — the badge number.
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  /// Sum of line totals at selling price.
  double get subtotal => lines.fold(0, (sum, line) => sum + line.total);

  /// Sum of line totals at MRP.
  double get subtotalAtMrp => lines.fold(0, (sum, line) => sum + line.totalAtMrp);

  /// Total saved against MRP.
  double get savings => subtotalAtMrp - subtotal;

  /// The line for [productCode], or null.
  CartLine? lineFor(String productCode) {
    for (final line in lines) {
      if (line.product.code == productCode) return line;
    }
    return null;
  }

  /// Quantity of [productCode] currently in the cart; zero when absent.
  int quantityOf(String productCode) => lineFor(productCode)?.quantity ?? 0;

  bool contains(String productCode) => lineFor(productCode) != null;

  /// Lines whose quantity is no longer purchasable — out of stock, or now
  /// exceeding the per-order cap.
  List<CartLine> get unsatisfiableLines =>
      List.unmodifiable(lines.where((l) => !l.isSatisfiable));

  /// Adds [quantity] of [product], merging with an existing line.
  ///
  /// The result is clamped to what is actually purchasable, so the cart can
  /// never hold more than the store can supply.
  Cart add(Product product, {int quantity = 1}) {
    if (quantity <= 0) return this;

    final existing = lineFor(product.code);
    final desired = (existing?.quantity ?? 0) + quantity;
    final allowed = product.purchasableQuantity;
    if (allowed <= 0) return this;

    return _withLine(product, desired < allowed ? desired : allowed);
  }

  /// Sets an exact quantity, removing the line when it reaches zero.
  Cart setQuantity(Product product, int quantity) {
    if (quantity <= 0) return remove(product.code);
    final allowed = product.purchasableQuantity;
    if (allowed <= 0) return remove(product.code);
    return _withLine(product, quantity < allowed ? quantity : allowed);
  }

  /// Removes one unit, dropping the line if it empties.
  Cart decrement(String productCode) {
    final line = lineFor(productCode);
    if (line == null) return this;
    if (line.quantity <= 1) return remove(productCode);
    return _withLine(line.product, line.quantity - 1);
  }

  Cart remove(String productCode) => Cart(
        storeCode: storeCode,
        lines: List.unmodifiable(
          lines.where((l) => l.product.code != productCode),
        ),
      );

  Cart clear() => Cart.empty(storeCode);

  /// Drops every line that can no longer be fulfilled.
  Cart withoutUnsatisfiableLines() => Cart(
        storeCode: storeCode,
        lines: List.unmodifiable(lines.where((l) => l.isSatisfiable)),
      );

  Cart _withLine(Product product, int quantity) {
    final updated = <CartLine>[];
    var replaced = false;
    for (final line in lines) {
      if (line.product.code == product.code) {
        updated.add(CartLine(product: product, quantity: quantity));
        replaced = true;
      } else {
        updated.add(line);
      }
    }
    if (!replaced) {
      updated.add(CartLine(product: product, quantity: quantity));
    }
    return Cart(storeCode: storeCode, lines: List.unmodifiable(updated));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cart &&
          other.storeCode == storeCode &&
          _sameLines(other.lines, lines);

  static bool _sameLines(List<CartLine> a, List<CartLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(storeCode, Object.hashAll(lines));

  @override
  String toString() => 'Cart($storeCode, $lineCount lines, $itemCount items)';
}
