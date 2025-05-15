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
  // Convert cart_items to CartItems
  final List<CartItem> items = [];
  if (json['cart_items'] != null) {  // Change 'items' to 'cart_items'
    for (final item in json['cart_items']) {
      // Create product from API response format
      final product = ProductModel(
        id: '',
        pCode: item['pcode'] ?? '',
        pcodeImg: item['product_image_link'] ?? '',
        barcode: '',
        productName: item['product_name'] ?? 'Product',
        productDescription: '',
        packageSize: double.tryParse(item['package_size']?.toString() ?? '0') ?? 0.0,
        packageUnit: item['package_unit'] ?? '',
        productMrp: double.tryParse(item['product_mrp']?.toString() ?? '0') ?? 0.0,
        ourPrice: double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0,
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
    orderId: json['_id'] ?? json['temp_order_id'] ?? 'UNKNOWN',
    orderDate: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now(),
    deliveryMethod: json['delivery_mode'] ?? 'Home Delivery',
    deliverySlot: json['delivery_slot'] ?? '09:00 AM - 12:00 PM',
    totalAmount: double.tryParse(json['final_payable_amt']?.toString() ?? '0') ?? 0.0,
    savings: double.tryParse(json['discounted_amt']?.toString() ?? '0') ?? 0.0,
    paymentMethod: json['payment_mode'] ?? 'COD',
    status: json['order_status'] ?? 'Order Confirmed',
    deliveryAddress: json['delivery_address'] != null && json['delivery_address'] is List && 
                   (json['delivery_address'] as List).isNotEmpty
        ? (json['delivery_address'][0] ?? {}).toString()
        : null,
    items: items,
  );
}
}