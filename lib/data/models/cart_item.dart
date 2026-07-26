// lib/data/models/cart_item.dart
//
// Moved verbatim from lib/presentation/providers/cart_provider.dart, where it
// was declared inline at line 18.
//
// Living in the presentation layer forced five data-layer files to import a UI
// provider just to reach this type: order_model.dart, cart_storage_service.dart,
// cart_validator.dart, order_service.dart and
// order_payment_processing_service.dart. A model has no business depending on
// a StateNotifier.
//
// It sits in `data/models/` rather than `domain/entities/` because it wraps a
// ProductModel DTO. Phase 5 (Cart) promotes it to a true domain entity holding
// a Product entity, with value equality and a const constructor.

import '../../domain/entities/cart.dart';
import 'product_model.dart';

/// A product plus the quantity of it the user has added to their cart.
class CartItem {
  final ProductModel product;
  final int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Line total at the selling price.
  double get totalPrice => product.ourPrice * quantity;

  /// Line total at MRP, used to show the crossed-out price.
  double get totalMrp => product.productMrp * quantity;

  /// Amount saved on this line versus MRP.
  double get savings => totalMrp - totalPrice;

  /// Converts to the domain line.
  ///
  /// Bridge for the migration: cart_provider, checkout and orders still hold
  /// `List<CartItem>`. Once they hold a Cart, this and [fromLine] go away
  /// along with this class.
  CartLine toLine() => CartLine(product: product.toEntity(), quantity: quantity);

  factory CartItem.fromLine(CartLine line) => CartItem(
        product: ProductModel.fromEntity(line.product),
        quantity: line.quantity,
      );
}

/// Builds a domain [Cart] from the legacy item list.
extension CartItemListToCart on List<CartItem> {
  Cart toCart(String storeCode) => Cart(
        storeCode: storeCode,
        lines: List.unmodifiable(map((i) => i.toLine())),
      );
}
