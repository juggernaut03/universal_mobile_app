// lib/data/models/product_model.dart
class ProductModel {
  final String id;
  final String pCode;
  final String pcodeImg;
  final String barcode;
  final String productName;
  final String productDescription;
  final double packageSize;
  final String packageUnit;
  final double productMrp;
  final double ourPrice;
  final String brandName;
  final String storeCode;
  final String pcodestatus;
  final String deptId;
  final String categoryId;
  final String subCategoryId;
  final int storeQuantity;
  final int maxQuantityAllowed;
  final String ipoImg;
  final bool isIpoProduct;

  ProductModel({
    required this.id,
    required this.pCode,
    required this.pcodeImg,
    required this.barcode,
    required this.productName,
    required this.productDescription,
    required this.packageSize,
    required this.packageUnit,
    required this.productMrp,
    required this.ourPrice,
    required this.brandName,
    required this.storeCode,
    required this.pcodestatus,
    required this.deptId,
    required this.categoryId,
    required this.subCategoryId,
    required this.storeQuantity,
    required this.maxQuantityAllowed,
    this.ipoImg = '',
    this.isIpoProduct = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id'] ?? '',
      pCode: json['p_code'] ?? '',
      pcodeImg: json['pcode_img'] ?? '',
      barcode: json['barcode'] ?? '',
      productName: json['product_name'] ?? '',
      productDescription: json['product_description'] ?? '',
      packageSize: parseDecimal128OrNumber(json['package_size']),
      packageUnit: json['package_unit'] ?? '',
      productMrp: parseDecimal128OrNumber(json['product_mrp']),
      ourPrice: parseDecimal128OrNumber(json['our_price']),
      brandName: json['brand_name'] ?? '',
      storeCode: json['store_code'] ?? '',
      pcodestatus: json['pcode_status'] ?? '',
      deptId: json['dept_id'] ?? '',
      categoryId: json['category_id'] ?? '',
      subCategoryId: json['sub_category_id'] ?? '',
      storeQuantity: _parseInt(json['store_quantity']),
      maxQuantityAllowed: _parseInt(json['max_quantity_allowed']),
      ipoImg: json['ipo_img'] ?? '',
      isIpoProduct: json['is_ipo_product']?.toString().toLowerCase() == 'yes',
    );
  }

  /// Enhanced parser that handles Mongoose Decimal128 format
  /// Made static and public for use in other parts of the app
  static double parseDecimal128OrNumber(dynamic value) {
    if (value == null) return 0.0;
    
    // Handle Mongoose Decimal128 format: {"$numberDecimal": "110.00"}
    if (value is Map<String, dynamic> && value.containsKey('\$numberDecimal')) {
      final decimalString = value['\$numberDecimal'];
      if (decimalString is String) {
        try {
          return double.parse(decimalString);
        } catch (e) {
          print('Error parsing Decimal128 string: $decimalString, Error: $e');
          return 0.0;
        }
      }
    }
    
    // Handle regular numeric types
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print('Error parsing string to double: $value, Error: $e');
        return 0.0;
      }
    }
    
    print('Unsupported value type for numeric parsing: ${value.runtimeType}, Value: $value');
    return 0.0;
  }

  /// Private method for internal use (kept for backward compatibility)
  static double _parseDecimal128OrNumber(dynamic value) {
    return parseDecimal128OrNumber(value);
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        print('Error parsing string to int: $value, Error: $e');
        return 0;
      }
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'p_code': pCode,
      'pcode_img': pcodeImg,
      'barcode': barcode,
      'product_name': productName,
      'product_description': productDescription,
      'package_size': packageSize,
      'package_unit': packageUnit,
      'product_mrp': productMrp,
      'our_price': ourPrice,
      'brand_name': brandName,
      'store_code': storeCode,
      'pcode_status': pcodestatus,
      'dept_id': deptId,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'store_quantity': storeQuantity,
      'max_quantity_allowed': maxQuantityAllowed,
      'ipo_img': ipoImg,
      'is_ipo_product': isIpoProduct ? 'Yes' : 'No',
    };
  }
  
  ProductModel copyWith({
    String? id,
    String? pCode,
    String? pcodeImg,
    String? barcode,
    String? productName,
    String? productDescription,
    double? packageSize,
    String? packageUnit,
    double? productMrp,
    double? ourPrice,
    String? brandName,
    String? storeCode,
    String? pcodestatus,
    String? deptId,
    String? categoryId,
    String? subCategoryId,
    int? storeQuantity,
    int? maxQuantityAllowed,
    String? ipoImg,
    bool? isIpoProduct,
  }) {
    return ProductModel(
      id: id ?? this.id,
      pCode: pCode ?? this.pCode,
      pcodeImg: pcodeImg ?? this.pcodeImg,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      productDescription: productDescription ?? this.productDescription,
      packageSize: packageSize ?? this.packageSize,
      packageUnit: packageUnit ?? this.packageUnit,
      productMrp: productMrp ?? this.productMrp,
      ourPrice: ourPrice ?? this.ourPrice,
      brandName: brandName ?? this.brandName,
      storeCode: storeCode ?? this.storeCode,
      pcodestatus: pcodestatus ?? this.pcodestatus,
      deptId: deptId ?? this.deptId,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      storeQuantity: storeQuantity ?? this.storeQuantity,
      maxQuantityAllowed: maxQuantityAllowed ?? this.maxQuantityAllowed,
      ipoImg: ipoImg ?? this.ipoImg,
      isIpoProduct: isIpoProduct ?? this.isIpoProduct,
    );
  }

  /// True if product should be shown — in stock and has a valid price.
  bool get isAvailable => storeQuantity > 0 && ourPrice > 0;

  @override
  String toString() {
    return 'ProductModel(id: $id, pCode: $pCode, productName: $productName, productMrp: $productMrp, ourPrice: $ourPrice)';
  }
}