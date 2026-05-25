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
  final double? deliveryAmount;
  final DateTime? orderDateTime; // This is the primary field for order date/time
  final int? actualOrderId; // This is the display order ID
  final double? refundAmount; // Refund amount returned to the customer
  // Map of product pcode -> server-revised quantity (e.g. when stock changed
  // after order placement). When an entry exists, the UI strikes out the
  // originally ordered quantity and shows this value beside it.
  final Map<String, int> updatedQuantities;

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
    this.orderDateTime,
    this.actualOrderId,
    this.refundAmount,
    this.updatedQuantities = const {},
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
      'orderDateTime': orderDateTime?.toIso8601String(),
      'actualOrderId': actualOrderId,
      'refundAmount': refundAmount,
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

  // Helper method to parse UTC datetime and convert to local time
  static DateTime? _parseOrderDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return null;
    }
    
    try {
      // Parse the UTC datetime
      DateTime utcDateTime = DateTime.parse(dateTimeString);
      
      // Convert UTC to local timezone
      DateTime localDateTime = utcDateTime.toLocal();
      
      print('Original UTC: $dateTimeString');
      print('Parsed UTC: $utcDateTime');
      print('Local time: $localDateTime');
      
      return localDateTime;
    } catch (e) {
      print('Error parsing order_date_time: $e');
      return null;
    }
  }

  // Create order from JSON with proper timezone handling
  factory Order.fromJson(Map<String, dynamic> json) {
    // Convert cart_items to CartItems
    final List<CartItem> items = [];
    final Map<String, int> updatedQuantities = {};
    if (json['cart_items'] != null) {
      for (final item in json['cart_items']) {
        try {
          final pcode = item['pcode']?.toString() ?? '';
          final productModel = ProductModel(
            id: '',
            pCode: pcode,
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
            product: productModel,
            quantity: item['quantity'] ?? 1,
          ));

          // Server may revise quantity post-order (e.g. insufficient stock).
          // Capture it so the UI can strike out the original.
          final rawNewQty = item['new_updated_qty'];
          if (rawNewQty != null && rawNewQty.toString().trim().isNotEmpty && pcode.isNotEmpty) {
            final parsed = int.tryParse(rawNewQty.toString());
            if (parsed != null) {
              updatedQuantities[pcode] = parsed;
            }
          }
        } catch (e) {
          print('Error parsing cart item: $e');
        }
      }
    }
    
    // Extract and properly handle order_date_time with timezone conversion
    DateTime? orderDateTime = _parseOrderDateTime(json['order_date_time']);
    
    // Use order_date_time as primary, fallback to delivery_date, then current time
    DateTime orderDate;
    try {
      if (orderDateTime != null) {
        orderDate = orderDateTime;
      } else if (json['delivery_date'] != null) {
        // Handle delivery_date as well
        DateTime deliveryDateTime = DateTime.parse(json['delivery_date']);
        orderDate = deliveryDateTime.toLocal();
      } else {
        orderDate = DateTime.now();
      }
    } catch (e) {
      print('Error parsing dates: $e');
      orderDate = DateTime.now();
    }
    
    // Extract actual_order_id for display
    final actualOrderId = json['actual_order_id'] as int?;
    
    // Extract total MRP and our price from API
    final totalMrp = double.tryParse(json['total_amount_mrp']?.toString() ?? '0') ?? 0.0;
    final totalOurPrice = double.tryParse(json['total_amount_our_price']?.toString() ?? '0') ?? 0.0;
    final deliveryCharges = double.tryParse(json['delivery_charges']?.toString() ?? '0') ?? 0.0;
    
    // Calculate proper savings
    final correctSavings = max(0.0, totalMrp - totalOurPrice);

    // Extract refund amount (only present when a refund has been issued)
    double? refundAmount;
    final rawRefund = json['refund_amount'];
    if (rawRefund != null && rawRefund.toString().trim().isNotEmpty) {
      refundAmount = double.tryParse(rawRefund.toString());
    }
    
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
      orderDate: orderDate, // This will be properly converted to local time
      deliveryMethod: json['delivery_mode'] ?? 'Home Delivery',
      deliverySlot: json['delivery_slot'] ?? '09:00 AM - 12:00 PM',
      totalAmount: totalOurPrice + deliveryCharges, // Include delivery charges in total
      totalMrp: totalMrp,
      savings: correctSavings,
      paymentMethod: json['payment_mode'] ?? 'COD',
      status: json['order_status'] ?? 'Order Confirmed',
      deliveryAddress: formattedAddress,
      deliveryAmount: deliveryCharges,
      items: items,
      orderDateTime: orderDateTime, // Store the converted local time
      actualOrderId: actualOrderId, // Store actual_order_id for display
      refundAmount: refundAmount, // Refund issued to the customer, if any
      updatedQuantities: updatedQuantities,
    );
  }

  // Helper method to get display order ID - prioritize actual_order_id
  String get displayOrderId {
    if (actualOrderId != null) {
      return actualOrderId.toString();
    }
    // Fallback to temp_order_id or _id
    return orderId;
  }

  // Helper method to get formatted order date using local time
  String get formattedOrderDate {
    final displayDate = orderDateTime ?? orderDate;
    return '${displayDate.day.toString().padLeft(2, '0')}/${displayDate.month.toString().padLeft(2, '0')}/${displayDate.year}';
  }

  // Helper method to get formatted order time using local time
  String get formattedOrderTime {
    final displayDate = orderDateTime ?? orderDate;
    final hour = displayDate.hour > 12 
        ? displayDate.hour - 12 
        : displayDate.hour == 0 
            ? 12 
            : displayDate.hour;
    final amPm = displayDate.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${displayDate.minute.toString().padLeft(2, '0')} $amPm';
  }

  // Helper method to get full formatted date and time
  String get formattedOrderDateTime {
    return '${formattedOrderDate} at ${formattedOrderTime}';
  }

  // Helper method to check if order is recent (within last 24 hours)
  bool get isRecent {
    final displayDate = orderDateTime ?? orderDate;
    final now = DateTime.now();
    final difference = now.difference(displayDate);
    return difference.inHours < 24;
  }

  // Helper method to get order status color
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'order confirmed':
        return '#4CAF50'; // Green
      case 'processing':
        return '#FF9800'; // Orange
      case 'shipped':
        return '#2196F3'; // Blue
      case 'delivered':
        return '#4CAF50'; // Green
      case 'cancelled':
        return '#F44336'; // Red
      default:
        return '#757575'; // Grey
    }
  }

  // Method for sorting - use order_date_time as primary sort field
  DateTime get sortableDateTime {
    return orderDateTime ?? orderDate;
  }

  // Debug method to see timezone information
  String get debugTimeInfo {
    final displayDate = orderDateTime ?? orderDate;
    return 'Local: $displayDate, Timezone: ${displayDate.timeZoneName}, Offset: ${displayDate.timeZoneOffset}';
  }
}