// lib/domain/entities/product.dart
//
// Pure Dart. No Flutter, no JSON, no http. Unit-testable with no mocks.
//
// The wire format (Mongoose `$numberDecimal`, `is_ipo_product: "Yes"`, snake_case
// keys) is a data-layer concern and stops at ProductModel. Nothing in this file
// knows the backend exists.

import 'package:meta/meta.dart';

/// A sellable product at a specific store.
@immutable
final class Product {
  /// Backend document id.
  final String id;

  /// Business product code — the identifier used across cart, orders and
  /// favourites. Stable across stores; [id] is not.
  final String code;

  /// Store this pricing and stock applies to. The same [code] carries different
  /// price and availability per store.
  final String storeCode;

  final String name;
  final String description;
  final String brandName;
  final String imageUrl;
  final String barcode;

  /// Pack size and its unit, e.g. 500 + "g".
  final double packageSize;
  final String packageUnit;

  /// Printed maximum retail price, shown struck through.
  final double mrp;

  /// Price actually charged.
  final double sellingPrice;

  final String departmentId;
  final String categoryId;
  final String subCategoryId;

  /// Units on hand at [storeCode].
  final int stockQuantity;

  /// Per-order cap for this line.
  final int maxQuantityAllowed;

  /// Status string from the catalogue.
  final String status;

  /// Whether this is an IPO (in-store promotional offer) product.
  final bool isIpoProduct;

  /// Alternate image used for IPO products.
  final String ipoImageUrl;

  const Product({
    required this.id,
    required this.code,
    required this.storeCode,
    required this.name,
    required this.description,
    required this.brandName,
    required this.imageUrl,
    required this.barcode,
    required this.packageSize,
    required this.packageUnit,
    required this.mrp,
    required this.sellingPrice,
    required this.departmentId,
    required this.categoryId,
    required this.subCategoryId,
    required this.stockQuantity,
    required this.maxQuantityAllowed,
    this.status = '',
    this.isIpoProduct = false,
    this.ipoImageUrl = '',
  });

  // ---- Business rules ----
  //
  // These live here, not in a widget and not in a repository, so they are
  // stated once and testable without a backend.

  /// Whether the product may be shown and sold: in stock with a real price.
  ///
  /// Matches the filter the old `ProductRepository` applied inline while
  /// parsing the response.
  bool get isAvailable => stockQuantity > 0 && sellingPrice > 0;

  /// Whether stock has run out.
  bool get isOutOfStock => stockQuantity <= 0;

  /// Absolute amount saved against [mrp]. Zero when the product is not
  /// discounted — never negative, even if the feed prices it above MRP.
  double get discountAmount {
    final saving = mrp - sellingPrice;
    return saving > 0 ? saving : 0;
  }

  /// Whether the product is discounted against its MRP.
  bool get hasDiscount => discountAmount > 0;

  /// Discount as a percentage of [mrp], 0 when there is no discount or no MRP.
  double get discountPercentage {
    if (mrp <= 0 || !hasDiscount) return 0;
    return (discountAmount / mrp) * 100;
  }

  /// Largest quantity a user may add, respecting both the per-order cap and
  /// what is actually on the shelf.
  ///
  /// Returns 0 when the product cannot be sold at all.
  int get purchasableQuantity {
    if (!isAvailable) return 0;
    if (maxQuantityAllowed <= 0) return stockQuantity;
    return maxQuantityAllowed < stockQuantity
        ? maxQuantityAllowed
        : stockQuantity;
  }

  /// Whether [quantity] can be added to a cart.
  bool canPurchaseQuantity(int quantity) =>
      quantity > 0 && quantity <= purchasableQuantity;

  /// Human-readable pack label, e.g. "500 g". Empty when unspecified.
  String get packLabel {
    if (packageSize <= 0 && packageUnit.isEmpty) return '';
    final size = packageSize == packageSize.roundToDouble()
        ? packageSize.toStringAsFixed(0)
        : packageSize.toString();
    return packageUnit.isEmpty ? size : '$size $packageUnit';
  }

  /// Image to render, preferring the IPO artwork when this is an IPO product.
  String get displayImageUrl =>
      isIpoProduct && ipoImageUrl.isNotEmpty ? ipoImageUrl : imageUrl;

  Product copyWith({
    String? id,
    String? code,
    String? storeCode,
    String? name,
    String? description,
    String? brandName,
    String? imageUrl,
    String? barcode,
    double? packageSize,
    String? packageUnit,
    double? mrp,
    double? sellingPrice,
    String? departmentId,
    String? categoryId,
    String? subCategoryId,
    int? stockQuantity,
    int? maxQuantityAllowed,
    String? status,
    bool? isIpoProduct,
    String? ipoImageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      storeCode: storeCode ?? this.storeCode,
      name: name ?? this.name,
      description: description ?? this.description,
      brandName: brandName ?? this.brandName,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      packageSize: packageSize ?? this.packageSize,
      packageUnit: packageUnit ?? this.packageUnit,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      departmentId: departmentId ?? this.departmentId,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      maxQuantityAllowed: maxQuantityAllowed ?? this.maxQuantityAllowed,
      status: status ?? this.status,
      isIpoProduct: isIpoProduct ?? this.isIpoProduct,
      ipoImageUrl: ipoImageUrl ?? this.ipoImageUrl,
    );
  }

  /// Identity is [code] + [storeCode]: the same product at a different store is
  /// a different sellable thing, with its own price and stock.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && other.code == code && other.storeCode == storeCode;

  @override
  int get hashCode => Object.hash(code, storeCode);

  @override
  String toString() =>
      'Product($code @ $storeCode, $name, $sellingPrice/$mrp, stock $stockQuantity)';
}
