// lib/data/models/order_model.dart

import 'dart:math';
import 'package:patelmart/data/models/product_model.dart';
import '../../presentation/providers/cart_provider.dart';

class Order {
  final String orderId;
  final DateTime orderDate;
  final String deliveryMethod;
  final String deliverySlot;
  final double totalAmount;
  final double totalMrp; 
  final double savings;
  final String paymentMethod;
  final List<CartItem> items;
  final String status;
  final String? deliveryAddress;
  final double? deliveryAmount; // Added for delivery fees

  Order({
    required this.orderId,
    required this.orderDate,
    required this.deliveryMethod,
    required this.deliverySlot,
    required this.totalAmount,
    required this.totalMrp,
    required this.savings,
    required this.paymentMethod,
    required this.items,
    required this.status,
    this.deliveryAddress,
    this.deliveryAmount,
  });

  // Convert order to JSON
  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderDate': orderDate.toIso8601String(),
      'deliveryMethod': deliveryMethod,
      'deliverySlot': deliverySlot,
      'totalAmount': totalAmount,
      'totalMrp': totalMrp,
      'savings': savings,
      'paymentMethod': paymentMethod,
      'status': status,
      'deliveryAddress': deliveryAddress,
      'deliveryAmount': deliveryAmount,
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
    if (json['cart_items'] != null) {
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
    
    // Extract delivery date
    DateTime orderDate;
    try {
      orderDate = json['delivery_date'] != null 
          ? DateTime.parse(json['delivery_date']) 
          : DateTime.now();
    } catch (e) {
      orderDate = DateTime.now();
    }
    
    // Extract total MRP and our price from API
    final totalMrp = double.tryParse(json['total_amount_mrp']?.toString() ?? '0') ?? 0.0;
    final totalOurPrice = double.tryParse(json['total_amount_our_price']?.toString() ?? '0') ?? 0.0;
    final deliveryCharges = double.tryParse(json['delivery_charges']?.toString() ?? '0') ?? 0.0;
    
    // Calculate proper savings
    final correctSavings = max(0.0, totalMrp - totalOurPrice);
    
    // Format delivery address if available
    String? formattedAddress;
    if (json['delivery_address'] != null && 
        json['delivery_address'] is List && 
        (json['delivery_address'] as List).isNotEmpty) {
      final address = json['delivery_address'][0];
      if (address != null) {
        final parts = [
          address['full_name'],
          address['delivery_addr_line_1'] ?? address['address_1'],
          address['delivery_addr_line_2'] ?? address['address_2'],
          address['delivery_addr_city'] ?? address['city'],
          address['delivery_addr_pincode'] ?? address['pincode'],
        ].where((part) => part != null && part.toString().isNotEmpty).toList();
        formattedAddress = parts.join(', ');
      }
    }
    
    return Order(
      orderId: json['_id'] ?? json['temp_order_id'] ?? 'UNKNOWN',
      orderDate: orderDate,
      deliveryMethod: json['delivery_mode'] ?? 'Home Delivery',
      deliverySlot: json['delivery_slot'] ?? '09:00 AM - 12:00 PM',
      totalAmount: totalOurPrice,
      totalMrp: totalMrp, // Store the MRP total
      savings: correctSavings, // Use correct savings calculation
      paymentMethod: json['payment_mode'] ?? 'COD',
      status: json['order_status'] ?? 'Order Confirmed',
      deliveryAddress: formattedAddress,
      deliveryAmount: deliveryCharges, // Add delivery charges
      items: items,
    );
  }
}