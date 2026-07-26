// test/domain/product_test.dart
//
// Business rules on the Product entity. Pure Dart — no mocks, no HTTP, no
// Flutter binding. This is the payoff of a domain layer: the rules that decide
// what a user may buy are testable in microseconds.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/domain/entities/product.dart';

Product buildProduct({
  String code = 'P1',
  String storeCode = 'KLK',
  double mrp = 100,
  double sellingPrice = 80,
  int stockQuantity = 10,
  int maxQuantityAllowed = 5,
  double packageSize = 500,
  String packageUnit = 'g',
  bool isIpoProduct = false,
  String ipoImageUrl = '',
  String imageUrl = 'https://cdn/p1.png',
}) {
  return Product(
    id: 'id-$code',
    code: code,
    storeCode: storeCode,
    name: 'Product $code',
    description: '',
    brandName: 'Brand',
    imageUrl: imageUrl,
    barcode: '',
    packageSize: packageSize,
    packageUnit: packageUnit,
    mrp: mrp,
    sellingPrice: sellingPrice,
    departmentId: 'D1',
    categoryId: 'C1',
    subCategoryId: 'S1',
    stockQuantity: stockQuantity,
    maxQuantityAllowed: maxQuantityAllowed,
    isIpoProduct: isIpoProduct,
    ipoImageUrl: ipoImageUrl,
  );
}

void main() {
  group('availability', () {
    test('is available with stock and a price', () {
      expect(buildProduct().isAvailable, isTrue);
    });

    test('is unavailable with no stock', () {
      expect(buildProduct(stockQuantity: 0).isAvailable, isFalse);
      expect(buildProduct(stockQuantity: 0).isOutOfStock, isTrue);
    });

    test('is unavailable with a zero price', () {
      // Matches the filter the old repository applied inline while parsing.
      expect(buildProduct(sellingPrice: 0).isAvailable, isFalse);
    });
  });

  group('discount', () {
    test('computes amount and percentage', () {
      final p = buildProduct(mrp: 100, sellingPrice: 75);

      expect(p.hasDiscount, isTrue);
      expect(p.discountAmount, 25);
      expect(p.discountPercentage, 25);
    });

    test('reports no discount when priced at MRP', () {
      final p = buildProduct(mrp: 100, sellingPrice: 100);

      expect(p.hasDiscount, isFalse);
      expect(p.discountAmount, 0);
      expect(p.discountPercentage, 0);
    });

    test('never reports a negative discount when priced above MRP', () {
      // Bad feed data must not render as "-20% off".
      final p = buildProduct(mrp: 100, sellingPrice: 120);

      expect(p.discountAmount, 0);
      expect(p.discountPercentage, 0);
      expect(p.hasDiscount, isFalse);
    });

    test('handles a zero MRP without dividing by zero', () {
      expect(buildProduct(mrp: 0, sellingPrice: 50).discountPercentage, 0);
    });
  });

  group('purchasableQuantity', () {
    test('is capped by maxQuantityAllowed when stock is plentiful', () {
      expect(
        buildProduct(stockQuantity: 100, maxQuantityAllowed: 5)
            .purchasableQuantity,
        5,
      );
    });

    test('is capped by stock when stock is the tighter limit', () {
      expect(
        buildProduct(stockQuantity: 3, maxQuantityAllowed: 5)
            .purchasableQuantity,
        3,
      );
    });

    test('falls back to stock when no per-order cap is set', () {
      expect(
        buildProduct(stockQuantity: 7, maxQuantityAllowed: 0)
            .purchasableQuantity,
        7,
      );
    });

    test('is zero for an unavailable product', () {
      expect(buildProduct(stockQuantity: 0).purchasableQuantity, 0);
    });

    test('canPurchaseQuantity respects the cap and rejects non-positive', () {
      final p = buildProduct(stockQuantity: 10, maxQuantityAllowed: 4);

      expect(p.canPurchaseQuantity(4), isTrue);
      expect(p.canPurchaseQuantity(5), isFalse);
      expect(p.canPurchaseQuantity(0), isFalse);
      expect(p.canPurchaseQuantity(-1), isFalse);
    });
  });

  group('presentation helpers', () {
    test('packLabel drops a trailing .0 on whole sizes', () {
      expect(buildProduct(packageSize: 500, packageUnit: 'g').packLabel, '500 g');
    });

    test('packLabel keeps fractional sizes', () {
      expect(buildProduct(packageSize: 1.5, packageUnit: 'L').packLabel, '1.5 L');
    });

    test('packLabel is empty when unspecified', () {
      expect(buildProduct(packageSize: 0, packageUnit: '').packLabel, '');
    });

    test('displayImageUrl prefers IPO art for IPO products', () {
      final p = buildProduct(
        isIpoProduct: true,
        ipoImageUrl: 'https://cdn/ipo.png',
      );

      expect(p.displayImageUrl, 'https://cdn/ipo.png');
    });

    test('displayImageUrl falls back when IPO art is missing', () {
      final p = buildProduct(isIpoProduct: true, ipoImageUrl: '');

      expect(p.displayImageUrl, 'https://cdn/p1.png');
    });
  });

  group('identity', () {
    test('same code at the same store is the same product', () {
      expect(buildProduct(code: 'P1'), buildProduct(code: 'P1'));
      expect(
        buildProduct(code: 'P1').hashCode,
        buildProduct(code: 'P1').hashCode,
      );
    });

    test('price and stock do not affect identity', () {
      expect(
        buildProduct(code: 'P1', sellingPrice: 80, stockQuantity: 1),
        buildProduct(code: 'P1', sellingPrice: 20, stockQuantity: 99),
      );
    });

    test('same code at a different store is a different product', () {
      // Price and availability are per-store, so these are not interchangeable.
      expect(
        buildProduct(code: 'P1', storeCode: 'KLK'),
        isNot(buildProduct(code: 'P1', storeCode: 'AND')),
      );
    });
  });
}
