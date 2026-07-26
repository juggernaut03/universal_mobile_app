// test/domain/cart_test.dart
//
// Cart mechanics and the checkout rules.
//
// Three validator implementations previously shared this responsibility, all
// mixing rules with HTTP, so none of it was testable. These run in milliseconds
// against pure values.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/domain/entities/cart.dart';
import 'package:patelmart/domain/entities/cart_validation.dart';
import 'package:patelmart/domain/entities/outlet.dart';
import 'package:patelmart/domain/entities/product.dart';

Product product({
  String code = 'P1',
  double price = 100,
  double mrp = 120,
  int stock = 10,
  int maxQuantity = 5,
}) =>
    Product(
      id: 'id-$code',
      code: code,
      storeCode: 'KLK',
      name: 'Product $code',
      description: '',
      brandName: '',
      imageUrl: '',
      barcode: '',
      packageSize: 1,
      packageUnit: 'kg',
      mrp: mrp,
      sellingPrice: price,
      departmentId: 'D',
      categoryId: 'C',
      subCategoryId: 'S',
      stockQuantity: stock,
      maxQuantityAllowed: maxQuantity,
    );

Outlet outlet({int minOrder = 0, bool isEnabled = true}) => Outlet(
      id: 'o',
      storeCode: 'KLK',
      name: 'Store',
      address: '',
      minOrderAmount: minOrder,
      isEnabled: isEnabled,
    );

Cart cartWith(List<CartLine> lines) => Cart(lines: lines, storeCode: 'KLK');

void main() {
  group('Cart.add', () {
    test('adds a new line', () {
      final cart = const Cart.empty('KLK').add(product());

      expect(cart.lineCount, 1);
      expect(cart.quantityOf('P1'), 1);
    });

    test('merges into an existing line', () {
      final cart =
          const Cart.empty('KLK').add(product()).add(product(), quantity: 2);

      expect(cart.lineCount, 1);
      expect(cart.quantityOf('P1'), 3);
    });

    test('clamps to the per-order cap', () {
      final cart = const Cart.empty('KLK')
          .add(product(maxQuantity: 3, stock: 99), quantity: 10);

      expect(cart.quantityOf('P1'), 3);
    });

    test('clamps to available stock when stock is the tighter limit', () {
      final cart = const Cart.empty('KLK')
          .add(product(stock: 2, maxQuantity: 5), quantity: 10);

      expect(cart.quantityOf('P1'), 2);
    });

    test('refuses an out-of-stock product', () {
      final cart = const Cart.empty('KLK').add(product(stock: 0));

      expect(cart.isEmpty, isTrue);
    });

    test('ignores a non-positive quantity', () {
      expect(const Cart.empty('KLK').add(product(), quantity: 0).isEmpty, isTrue);
      expect(const Cart.empty('KLK').add(product(), quantity: -1).isEmpty, isTrue);
    });

    test('is immutable — the original is unchanged', () {
      const original = Cart.empty('KLK');
      original.add(product());

      expect(original.isEmpty, isTrue);
    });
  });

  group('regressions the notifier used to have', () {
    test('a zero per-order cap does not throw, and means "no cap"', () {
      // CartNotifier called `quantity.clamp(1, maxQuantityAllowed)`. Dart's
      // clamp asserts upper >= lower, so a product with a cap of 0 threw an
      // ArgumentError on add.
      //
      // The entity reads a cap of 0 as "no per-order limit" — consistent with
      // minOrderAmount 0 meaning no minimum — so the quantity is bounded by
      // stock instead.
      final cart = const Cart.empty('KLK')
          .setQuantity(product(maxQuantity: 0, stock: 5), 3);

      expect(cart.quantityOf('P1'), 3);
    });

    test('a zero cap is still bounded by stock', () {
      final cart = const Cart.empty('KLK')
          .setQuantity(product(maxQuantity: 0, stock: 2), 9);

      expect(cart.quantityOf('P1'), 2);
    });

    test('quantity is capped by stock, not only by the per-order limit', () {
      // The notifier compared quantity against maxQuantityAllowed alone, so a
      // cart could hold more than the store could supply.
      final cart = const Cart.empty('KLK')
          .setQuantity(product(stock: 2, maxQuantity: 50), 10);

      expect(cart.quantityOf('P1'), 2);
    });

    test('decrementing to zero removes the line rather than leaving a 0-qty row',
        () {
      final cart = const Cart.empty('KLK').add(product());

      expect(cart.decrement('P1').lines, isEmpty);
    });
  });

  group('Cart.setQuantity / decrement / remove', () {
    test('setQuantity to zero removes the line', () {
      final cart = const Cart.empty('KLK').add(product());

      expect(cart.setQuantity(product(), 0).isEmpty, isTrue);
    });

    test('setQuantity clamps to what is purchasable', () {
      final cart =
          const Cart.empty('KLK').setQuantity(product(maxQuantity: 4), 99);

      expect(cart.quantityOf('P1'), 4);
    });

    test('decrement drops the line at one', () {
      final cart = const Cart.empty('KLK').add(product());

      expect(cart.decrement('P1').isEmpty, isTrue);
    });

    test('decrement reduces above one', () {
      final cart = const Cart.empty('KLK').add(product(), quantity: 3);

      expect(cart.decrement('P1').quantityOf('P1'), 2);
    });

    test('decrementing an absent product is a no-op', () {
      const cart = Cart.empty('KLK');

      expect(cart.decrement('NOPE'), cart);
    });

    test('remove drops only the named line', () {
      final cart = const Cart.empty('KLK')
          .add(product(code: 'A'))
          .add(product(code: 'B'));

      expect(cart.remove('A').lines.single.product.code, 'B');
    });
  });

  group('totals', () {
    test('sums quantities and money across lines', () {
      final cart = const Cart.empty('KLK')
          .add(product(code: 'A', price: 100, mrp: 120), quantity: 2)
          .add(product(code: 'B', price: 50, mrp: 50), quantity: 1);

      expect(cart.lineCount, 2);
      expect(cart.itemCount, 3);
      expect(cart.subtotal, 250);
      expect(cart.subtotalAtMrp, 290);
      expect(cart.savings, 40);
    });

    test('an empty cart totals zero', () {
      const cart = Cart.empty('KLK');

      expect(cart.subtotal, 0);
      expect(cart.itemCount, 0);
    });
  });

  group('satisfiability', () {
    test('flags a line whose stock ran out after it was added', () {
      // The realistic case: added when in stock, stock gone by checkout.
      final cart = cartWith([
        CartLine(product: product(code: 'A', stock: 0), quantity: 2),
      ]);

      expect(cart.unsatisfiableLines, hasLength(1));
      expect(cart.withoutUnsatisfiableLines().isEmpty, isTrue);
    });

    test('flags a line whose quantity now exceeds stock', () {
      final cart = cartWith([
        CartLine(product: product(stock: 1, maxQuantity: 5), quantity: 3),
      ]);

      expect(cart.unsatisfiableLines, hasLength(1));
    });

    test('leaves satisfiable lines alone', () {
      final cart = cartWith([
        CartLine(product: product(stock: 10, maxQuantity: 5), quantity: 2),
      ]);

      expect(cart.unsatisfiableLines, isEmpty);
    });
  });

  group('CartValidationPolicy', () {
    const policy = CartValidationPolicy();

    test('an empty cart is the only reported problem', () {
      final result =
          policy.validate(cart: const Cart.empty('KLK'), outlet: outlet());

      expect(result.problems.single, isA<CartIsEmpty>());
      expect(result.isValid, isFalse);
    });

    test('a closed outlet blocks before any line check', () {
      final result = policy.validate(
        cart: const Cart.empty('KLK').add(product()),
        outlet: outlet(isEnabled: false),
      );

      expect(result.problems.single, isA<OutletUnavailable>());
    });

    test('a good cart passes', () {
      final result = policy.validate(
        cart: const Cart.empty('KLK').add(product(price: 300)),
        outlet: outlet(minOrder: 200),
      );

      expect(result.isValid, isTrue);
    });

    test('reports out-of-stock lines', () {
      final result = policy.validate(
        cart: cartWith(
            [CartLine(product: product(stock: 0), quantity: 1)]),
        outlet: outlet(),
      );

      expect(result.problems.whereType<LineOutOfStock>(), hasLength(1));
    });

    test('reports quantity shortfalls with the available count', () {
      final result = policy.validate(
        cart: cartWith([
          CartLine(product: product(stock: 2, maxQuantity: 9), quantity: 5),
        ]),
        outlet: outlet(),
      );

      final problem =
          result.problems.whereType<QuantityUnavailable>().single;
      expect(problem.requested, 5);
      expect(problem.available, 2);
    });

    test('reports the minimum-order shortfall', () {
      final result = policy.validate(
        cart: const Cart.empty('KLK').add(product(price: 150)),
        outlet: outlet(minOrder: 200),
      );

      final problem = result.problems.whereType<BelowMinimumOrder>().single;
      expect(problem.shortfall, 50);
      expect(problem.message, contains('50'));
    });

    test('the minimum is measured on purchasable lines only', () {
      // An out-of-stock line must not carry the cart over the threshold — the
      // order would then fail at the server instead of here.
      final result = policy.validate(
        cart: cartWith([
          CartLine(product: product(code: 'OK', price: 100), quantity: 1),
          CartLine(
              product: product(code: 'GONE', price: 500, stock: 0), quantity: 1),
        ]),
        outlet: outlet(minOrder: 200),
      );

      expect(result.problems.whereType<BelowMinimumOrder>(), hasLength(1));
    });

    test('stock problems are auto-fixable, business rules are not', () {
      final stockOnly = policy.validate(
        cart: cartWith([CartLine(product: product(stock: 0), quantity: 1)]),
        outlet: outlet(),
      );
      expect(stockOnly.isAutoFixable, isTrue);

      final minimum = policy.validate(
        cart: const Cart.empty('KLK').add(product(price: 10)),
        outlet: outlet(minOrder: 500),
      );
      expect(minimum.isAutoFixable, isFalse);
      expect(minimum.blocking, hasLength(1));
    });
  });
}
