// lib/data/models/order_model.dart

import 'dart:math';
import 'package:patelmart/data/models/product_model.dart';
import 'cart_item.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/order_summary.dart';
import 'package:flutter/foundation.dart';

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
  // Pcodes for items the server marked product_available_status == not_available.
  // The UI strikes out the whole row and shows a "Not Available" badge.
  final Set<String> unavailableItems;

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
    this.unavailableItems = const {},
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
      
      if (kDebugMode) print('Original UTC: $dateTimeString');
      if (kDebugMode) print('Parsed UTC: $utcDateTime');
      if (kDebugMode) print('Local time: $localDateTime');
      
      return localDateTime;
    } catch (e) {
      if (kDebugMode) print('Error parsing order_date_time: $e');
      return null;
    }
  }

  // Create order from the universal backend's order JSON.
  // Handles both the my-orders list shape (order_items with product_code /
  // product_image / uom, top-level delivery_slot and delivery_address) and
  // the order-detail shape (raw items with p_code / pcode_img, nested
  // delivery_info and payment_info).
  factory Order.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    final List<CartItem> items = [];
    final Map<String, int> updatedQuantities = {};
    final Set<String> unavailableItems = {};

    if (json['order_items'] is List) {
      for (final item in json['order_items'] as List) {
        if (item is! Map) continue;
        try {
          final pcode =
              (item['product_code'] ?? item['p_code'] ?? '').toString();
          final productModel = ProductModel(
            id: '',
            pCode: pcode,
            pcodeImg: (item['product_image'] ?? item['pcode_img'] ?? '').toString(),
            barcode: '',
            productName: (item['product_name'] ?? 'Product').toString(),
            productDescription: '',
            packageSize: toDouble(item['package_size']),
            packageUnit: (item['uom'] ?? item['package_unit'] ?? '').toString(),
            productMrp: toDouble(item['product_mrp'] ?? item['unit_price']),
            ourPrice: toDouble(item['unit_price']),
            brandName: (item['product_brand'] ?? item['brand_name'] ?? '').toString(),
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
            quantity: item['quantity'] is int
                ? item['quantity']
                : int.tryParse(item['quantity']?.toString() ?? '') ?? 1,
          ));
        } catch (e) {
          if (kDebugMode) print('Error parsing order item: $e');
        }
      }
    }

    // Order placement time
    DateTime orderDate;
    final placedAt = _parseOrderDateTime(
        (json['order_placed_at'] ?? json['order_date_time'])?.toString());
    orderDate = placedAt ?? DateTime.now();

    // Summary totals
    final summary = json['order_summary'] is Map
        ? json['order_summary'] as Map
        : {};
    final subtotal = toDouble(summary['subtotal']);
    final deliveryCharges = toDouble(summary['delivery_charges']);
    final discountAmount = toDouble(summary['discount_amount']);
    final dealSavings = toDouble(summary['deal_savings']);
    final totalAmount = toDouble(summary['total_amount']);

    final totalMrp = subtotal; // MRP not tracked server-side; show subtotal
    final correctSavings = max(0.0, discountAmount + dealSavings);

    // Delivery slot (list shape has it flattened, detail shape nests it)
    final deliveryInfo = json['delivery_info'] is Map
        ? json['delivery_info'] as Map
        : {};
    String deliverySlot = (json['delivery_slot'] ?? '').toString();
    if (deliverySlot.isEmpty && deliveryInfo.isNotEmpty) {
      deliverySlot =
          '${deliveryInfo['delivery_slot_from'] ?? ''} - ${deliveryInfo['delivery_slot_to'] ?? ''}';
    }

    // Payment mode
    final paymentInfo = json['payment_info'] is Map
        ? json['payment_info'] as Map
        : {};
    final paymentMethod = (json['payment_mode'] ??
            paymentInfo['payment_mode_name'] ??
            'COD')
        .toString();

    // Refund amount (when issued by admin)
    double? refundAmount;
    final rawRefund = json['refund_amount'] ?? summary['refund_amount'];
    if (rawRefund != null && rawRefund.toString().trim().isNotEmpty) {
      refundAmount = double.tryParse(rawRefund.toString());
    }

    // Delivery address (object on both shapes)
    String? formattedAddress;
    final rawAddress =
        json['delivery_address'] ?? deliveryInfo['delivery_address'];
    if (rawAddress is Map) {
      final parts = [
        rawAddress['full_name'],
        rawAddress['line_1'] ?? rawAddress['delivery_addr_line_1'],
        rawAddress['line_2'] ?? rawAddress['delivery_addr_line_2'],
        rawAddress['city'] ?? rawAddress['delivery_addr_city'],
        rawAddress['pincode'] ?? rawAddress['delivery_addr_pincode'],
      ].where((part) => part != null && part.toString().isNotEmpty).toList();
      formattedAddress = parts.join(', ');
    }

    const int? actualOrderId = null;

    return Order(
      orderId: (json['order_number'] ?? json['_id'] ?? 'UNKNOWN').toString(),
      orderDate: orderDate, // This will be properly converted to local time
      deliveryMethod: json['delivery_mode'] ?? 'Home Delivery',
      deliverySlot: deliverySlot.trim().isEmpty ? '09:00 AM - 12:00 PM' : deliverySlot,
      totalAmount: totalAmount > 0 ? totalAmount : subtotal + deliveryCharges,
      totalMrp: totalMrp,
      savings: correctSavings,
      paymentMethod: paymentMethod,
      status: json['order_status'] ?? 'Order Confirmed',
      deliveryAddress: formattedAddress,
      deliveryAmount: deliveryCharges,
      items: items,
      orderDateTime: placedAt, // Store the converted local time
      actualOrderId: actualOrderId,
      refundAmount: refundAmount, // Refund issued to the customer, if any
      updatedQuantities: updatedQuantities,
      unavailableItems: unavailableItems,
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
    return '$formattedOrderDate at $formattedOrderTime';
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
  /// Converts to the domain entity.
  ///
  /// Collapses the DTO's two date fields (`orderDate` plus a nullable
  /// `orderDateTime`, picked between by a `sortableDateTime` getter) and its two
  /// id fields (`orderId` plus a nullable `actualOrderId`, picked between by
  /// `displayOrderId`) into one authoritative value each.
  OrderSummary toEntity() => OrderSummary(
        id: orderId,
        displayNumber: displayOrderId,
        placedAt: orderDateTime ?? orderDate,
        status: OrderStatus.parse(status),
        lines: items.map((i) => i.toLine()).toList(growable: false),
        totalAmount: totalAmount,
        totalAtMrp: totalMrp,
        deliveryCharge: deliveryAmount ?? 0,
        refundAmount: refundAmount,
        deliveryMethod: deliveryMethod,
        deliverySlot: deliverySlot,
        paymentMethod: paymentMethod,
        deliveryAddress: deliveryAddress,
      );

}