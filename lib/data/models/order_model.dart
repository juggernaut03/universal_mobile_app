// lib/data/models/order_model.dart

import 'package:patelmart/data/models/product_model.dart';
import '../../presentation/providers/cart_provider.dart';

class Order {
  final String orderId;
  final DateTime orderDate;
  final String deliveryMethod;
  final String deliverySlot;
  final double totalAmount;
  final double savings;
  final String paymentMethod;
  final List<CartItem> items;
  final String status;
  final String? deliveryAddress;

  Order({
    required this.orderId,
    required this.orderDate,
    required this.deliveryMethod,
    required this.deliverySlot,
    required this.totalAmount,
    required this.savings,
    required this.paymentMethod,
    required this.items,
    required this.status,
    this.deliveryAddress,
  });

  // Convert order to JSON
  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderDate': orderDate.toIso8601String(),
      'deliveryMethod': deliveryMethod,
      'deliverySlot': deliverySlot,
      'totalAmount': totalAmount,
      'savings': savings,
      'paymentMethod': paymentMethod,
      'status': status,
      'deliveryAddress': deliveryAddress,
      'items': items.map((item) => {
        'productId': item.product.pCode,
        'productName': item.product.productName,
        'productImage': item.product.pcodeImg,
        'quantity': item.quantity,
        'ourPrice': item.product.ourPrice,
        'mrp': item.product.productMrp,
        'packageSize': item.product.packageSize,
        'packageUnit': item.product.packageUnit,
      }).toList(),
    };
  }

  // Create order from JSON with stored product data
  factory Order.fromJson(Map<String, dynamic> json) {
    // Convert stored item data back to CartItems
    final List<CartItem> items = [];
    if (json['items'] != null) {
      for (final item in json['items']) {
        // Recreate the product model from stored data
        final product = ProductModel(
          id: '', // Non-critical fields can be left empty
          pCode: item['productId'],
          pcodeImg: item['productImage'] ?? '',
          barcode: '',
          productName: item['productName'] ?? 'Product',
          productDescription: '',
          packageSize: item['packageSize'] ?? 0.0,
          packageUnit: item['packageUnit'] ?? '',
          productMrp: item['mrp'] ?? 0.0,
          ourPrice: item['ourPrice'] ?? 0.0,
          brandName: '',
          storeCode: '',
          pcodestatus: '',
          deptId: '',
          categoryId: '',
          subCategoryId: '',
          storeQuantity: 10,
          maxQuantityAllowed: 10,
        );
        
        items.add(CartItem(
          product: product,
          quantity: item['quantity'] ?? 1,
        ));
      }
    }
    
    return Order(
      orderId: json['orderId'] ?? 'UNKNOWN',
      orderDate: json['orderDate'] != null 
          ? DateTime.parse(json['orderDate']) 
          : DateTime.now(),
      deliveryMethod: json['deliveryMethod'] ?? 'Home Delivery',
      deliverySlot: json['deliverySlot'] ?? '09:00 AM - 12:00 PM',
      totalAmount: json['totalAmount'] ?? 0.0,
      savings: json['savings'] ?? 0.0,
      paymentMethod: json['paymentMethod'] ?? 'COD',
      status: json['status'] ?? 'Order Confirmed',
      deliveryAddress: json['deliveryAddress'],
      items: items,
    );
  }
}