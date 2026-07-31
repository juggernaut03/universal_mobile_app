// test/data/cart_validator_test.dart
//
// The checkout validation dialog used to reopen forever on a perfectly ordinary
// cart. The server capped a line to the stock it had (`insufficient_stock`),
// CartValidator parsed that into `quantityChangedItems` — and nothing else in
// the app read that list. The dialog rendered none of it, the "UPDATE CART"
// handler applied none of it, so the cart went back to the server unchanged and
// came back with the same complaint, indefinitely.
//
// These tests pin the parse, so the bucket that carries the fix stays populated
// and correctly shaped.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/data/models/cart_item.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/data/services/cart_validator.dart';

ProductModel _product({
  required String pCode,
  required String name,
  double ourPrice = 100,
}) =>
    ProductModel(
      id: 'id_$pCode',
      pCode: pCode,
      pcodeImg: '',
      barcode: '',
      productName: name,
      productDescription: '',
      packageSize: 1,
      packageUnit: 'PC',
      productMrp: ourPrice * 2,
      ourPrice: ourPrice,
      brandName: 'BRAND',
      storeCode: 'PAG001',
      pcodestatus: 'Y',
      deptId: '1',
      categoryId: '1',
      subCategoryId: '1',
      storeQuantity: 10,
      maxQuantityAllowed: 10,
    );

/// Builds a CartValidator whose save always succeeds and whose validate returns
/// [validation], shaped exactly like POST /api/cart/validate-cart.
CartValidator _validatorReturning(Map<String, dynamic> validation) {
  final client = MockClient((request) async {
    final body = jsonEncode(
      request.url.path.endsWith('/cart/save-cart')
          ? {'success': true, 'message': 'Cart saved successfully'}
          : {'success': true, 'message': 'Cart validation completed', 'validation': validation},
    );
    return http.Response(body, 200, headers: {'content-type': 'application/json'});
  });

  return CartValidator(
    apiClient: ApiClient(client: client, readToken: () async => 'test-token'),
  );
}

/// Builds a CartValidator whose save-cart fails with [status] and [body].
CartValidator _validatorFailingSave(int status, Map<String, dynamic> body) {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/cart/save-cart')) {
      return http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
    }
    return http.Response(
      jsonEncode({'success': true, 'validation': {'valid': true}}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  return CartValidator(
    apiClient: ApiClient(client: client, readToken: () async => 'test-token'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final camphor = _product(pCode: '16788', name: 'LABH GANGA CAMPHOR', ourPrice: 150);
  final coffee = _product(pCode: '476', name: 'NESCAFE SUNRISE 200GM', ourPrice: 619.5);

  group('insufficient_stock', () {
    test('is parsed as a quantity change capped at the stock on hand', () async {
      final validator = _validatorReturning({
        'valid': false,
        'invalidItems': [
          {
            'p_code': '476',
            'actionType': 'insufficient_stock',
            'message': 'Only 2 item(s) available. You requested 5.',
            'available_quantity': 2,
            'price': {'old': 619.5, 'new': 619.5, 'changed': false},
          }
        ],
        'updatedItems': [],
      });

      final result = await validator.validateCart(
        [CartItem(product: coffee, quantity: 5)],
        'PAG001',
      );

      expect(result, isNotNull);
      expect(result!.isValid, isFalse);

      // The cap is the whole fix — without it the retry re-sends quantity 5.
      expect(result.quantityChangedItems, hasLength(1));
      final capped = result.quantityChangedItems.single;
      expect(capped.product.pCode, '476');
      expect(capped.oldQuantity, 5);
      expect(capped.newQuantity, 2);
      expect(capped.reason, contains('Only 2'));

      // A capped line is not a removal and not a price change.
      expect(result.removedItems, isEmpty);
      expect(result.priceChangedItems, isEmpty);
      expect(result.itemsWithIssues, isEmpty);
    });

    test('collapses to a removal when nothing is left on the shelf', () async {
      final validator = _validatorReturning({
        'valid': false,
        'invalidItems': [
          {
            'p_code': '476',
            'actionType': 'insufficient_stock',
            'message': 'Out of stock',
            'available_quantity': 0,
          }
        ],
        'updatedItems': [],
      });

      final result = await validator.validateCart(
        [CartItem(product: coffee, quantity: 3)],
        'PAG001',
      );

      expect(result!.quantityChangedItems, isEmpty);
      expect(result.removedItems, hasLength(1));
      expect(result.removedItems.single.product.pCode, '476');
    });
  });

  test('max_quantity_exceeded caps at the per-order limit', () async {
    final validator = _validatorReturning({
      'valid': false,
      'invalidItems': [
        {
          'p_code': '16788',
          'actionType': 'max_quantity_exceeded',
          'message': 'Maximum 10 item(s) allowed per order. You requested 12.',
          'available_quantity': 10,
        }
      ],
      'updatedItems': [],
    });

    final result = await validator.validateCart(
      [CartItem(product: camphor, quantity: 12)],
      'PAG001',
    );

    expect(result!.quantityChangedItems, hasLength(1));
    expect(result.quantityChangedItems.single.newQuantity, 10);
    expect(result.quantityChangedItems.single.oldQuantity, 12);
  });

  test('out_of_stock is parsed as a removal', () async {
    final validator = _validatorReturning({
      'valid': false,
      'invalidItems': [
        {
          'p_code': '16788',
          'actionType': 'out_of_stock',
          'message': 'Product is out of stock',
          'available_quantity': 0,
        }
      ],
      'updatedItems': [],
    });

    final result = await validator.validateCart(
      [CartItem(product: camphor, quantity: 1)],
      'PAG001',
    );

    expect(result!.removedItems, hasLength(1));
    expect(result.removedItems.single.reason, 'Product is out of stock');
    expect(result.quantityChangedItems, isEmpty);
  });

  test('a price change alone leaves the cart valid but flags the new price', () async {
    // The server returns valid:true with status "price_updated" here — verified
    // against the live API. The dialog still opens (hasChanges), so its second
    // button has to be able to carry the shopper through to checkout.
    final validator = _validatorReturning({
      'valid': true,
      'invalidItems': [],
      'updatedItems': [
        {
          'p_code': '476',
          'actionType': 'price_changed',
          'price': {'old': 624.5, 'new': 619.5, 'changed': true},
        }
      ],
    });

    final result = await validator.validateCart(
      [CartItem(product: _product(pCode: '476', name: 'NESCAFE', ourPrice: 624.5), quantity: 1)],
      'PAG001',
    );

    expect(result!.isValid, isTrue);
    expect(result.hasChanges, isTrue, reason: 'the dialog is shown on hasChanges');
    expect(result.priceChangedItems.single.oldPrice, 624.5);
    expect(result.priceChangedItems.single.newPrice, 619.5);
  });

  test('a clean cart reports no changes at all, so checkout is not interrupted',
      () async {
    final validator = _validatorReturning({
      'valid': true,
      'invalidItems': [],
      'updatedItems': [],
    });

    final result = await validator.validateCart(
      [CartItem(product: camphor, quantity: 1)],
      'PAG001',
    );

    expect(result!.isValid, isTrue);
    expect(result.hasChanges, isFalse);
  });
}
