// lib/data/services/order_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';
import '../models/outlet_model.dart';
import '../models/product_model.dart';
import '../models/address_model.dart';
import '../../presentation/providers/cart_provider.dart';

class OrderConfirmationResponse {
  final bool success;
  final String message;
  final String? orderId;
  final Map<String, dynamic>? data;
  final Object? error;

  OrderConfirmationResponse({
    required this.success,
    required this.message,
    this.orderId,
    this.data,
    this.error,
  });
}

class OrderService {
  final http.Client _client;
  final Logger _logger;

  OrderService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  // Updated confirmOrder method with order_date_time field
  Future<OrderConfirmationResponse> confirmOrder({
    required String deviceId,
    required String cartKey,
    required String tempOrderId,
    required String storeCode,
    required List<CartItem> cartItems,
    required Address deliveryAddress,
    required String deliverySlot,
    required String deliveryDate,
    required String deliveryMode,
    required String paymentMode,
    required double totalMrp,
    required double totalOurPrice,
    required double discount,
    required double deliveryCharges,
    required double discountedAmount,
    required double finalPayableAmount,
    required String paidAmount,
    String? accessKey,
    String? transactionId,
    String? specialNotes,
    String offerDetails = "No Offer",
    String mobPlatform = "Android",
  }) async {
    try {
      _logger.log('Preparing order confirmation request with order_date_time');
      
      // Generate UNIQUE identifiers
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
      final uniqueTempOrderId = 'ORDER_TEMP_${timestamp}_$randomSuffix';
      
      // Create order_date_time in the required format (ISO 8601)
      final orderDateTime = DateTime.now().toUtc().toIso8601String();
      
      // Format cart items exactly as in Postman
      final List<Map<String, dynamic>> formattedCartItems = cartItems.map((item) {
        return {
          "pcode": item.product.pCode,
          "product_name": item.product.productName,
          "product_mrp": item.product.productMrp,
          "selling_price": item.product.ourPrice,
          "package_size": item.product.packageSize,
          "package_unit": item.product.packageUnit,
          "stock_message": "Yes",
          "price_alert_message": "Yes",
          "quantity": item.quantity,
          "product_image_link": item.product.pcodeImg,
        };
      }).toList();
      
      // Calculate savings correctly
      final youSave = totalMrp - totalOurPrice;
      
      // Create request body matching API requirements with order_date_time
      final Map<String, dynamic> requestBody = {
        "temp_order_id": uniqueTempOrderId,
        "store_code": storeCode,
        "access_key": accessKey ?? "",
        "device_id": deviceId,
        
        // Cart items array
        "cart_items": formattedCartItems,
        
        // Delivery address as array (matching API format)
        "delivery_address": [
          {
            "full_name": deliveryAddress.fullName,
            "mobile_number": deliveryAddress.mobileNumber,
            "email_id": deliveryAddress.emailId,
            "delivery_addr_line_1": deliveryAddress.deliveryAddrLine1,
            "delivery_addr_line_2": deliveryAddress.deliveryAddrLine2,
            "delivery_addr_city": deliveryAddress.deliveryAddrCity,
            "delivery_addr_pincode": deliveryAddress.deliveryAddrPincode,
            "state": deliveryAddress.state,
            "landmark": deliveryAddress.landmark,
            "area_id": deliveryAddress.areaId,
            "is_default": deliveryAddress.isDefault,
            "latitude": deliveryAddress.latitude ?? "",
            "longitude": deliveryAddress.longitude ?? "",
          }
        ],
        
        // Delivery details
        "delivery_slot": deliverySlot,
        "delivery_slot_id": _getDeliverySlotId(deliverySlot),
        "order_status": "Order Confirmed",
        "special_note": specialNotes ?? "",
        
        // Financial details (matching API format)
        "total_amount_mrp": totalMrp.toString(),
        "total_amount_our_price": totalOurPrice.toString(),
        "discount": discount.toString(),
        "you_save": youSave.toString(),
        "delivery_charges": deliveryCharges.toString(),
        "discounted_amt": discountedAmount.toString(),
        "final_payable_amt": finalPayableAmount.toString(),
        
        "delivery_date": deliveryDate,
        "offer_applicable_details": offerDetails,
        "delivery_mode": deliveryMode,
        
        // Payment details
        "payment_mode": paymentMode,
        "payment_mode_id": _getPaymentModeId(paymentMode),
        "payment_status": paymentMode == "online payment" 
            ? "Payment Confirmed" 
            : "Pending",
        "payment_status_id": paymentMode == "online payment" ? 2 : 1,
        "paid_amount": paidAmount,
        "transaction_id": transactionId ?? "",
        
        "mob_platform": mobPlatform,
        "mobile_no": deliveryAddress.mobileNumber,
        
        // NEW FIELD: Add order_date_time in UTC ISO format
        "order_date_time": orderDateTime,
      };
      
      _logger.log('Sending order confirmation with order_date_time: $orderDateTime');
      _logger.log('Request body keys: ${requestBody.keys.toList()}');
      
      // Make the API call
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/confirm_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Order confirmation response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          responseData = {'message': 'Success but unable to parse response details'};
        }
        
        // Extract order ID from response
        String? orderId;
        if (responseData['insertedItems'] != null && 
            responseData['insertedItems'] is List &&
            (responseData['insertedItems'] as List).isNotEmpty) {
          orderId = responseData['insertedItems'][0]['_id'];
        } else {
          orderId = uniqueTempOrderId;
        }
        
        return OrderConfirmationResponse(
          success: true,
          message: responseData['message'] ?? 'Order placed successfully',
          orderId: orderId,
          data: responseData,
        );
      } else {
        _logger.error('Order confirmation failed: ${response.statusCode} - ${response.body}');
        return OrderConfirmationResponse(
          success: false,
          message: 'Failed to place order. Please try again.',
          error: Exception('API Error: ${response.statusCode}'),
        );
      }
    } catch (e) {
      _logger.error('Error during order confirmation: $e');
      return OrderConfirmationResponse(
        success: false,
        message: 'An error occurred while placing your order: ${e.toString()}',
        error: e,
      );
    }
  }

  int _getDeliverySlotId(String deliverySlot) {
    // Map delivery slot text to ID
    switch (deliverySlot) {
      case "9:00 AM - 10:00 PM":
        return 1;
      case "11:00 AM - 12:00 PM":
        return 1;
      case "12:00 PM - 01:00 PM":
        return 2;
      case "01:00 PM - 02:00 PM":
        return 3;
      // Add more mappings based on your delivery slots
      default:
        return 1;
    }
  }

  int _getPaymentModeId(String paymentMode) {
    // Map payment mode to ID
    switch (paymentMode.toLowerCase()) {
      case "pod":
        return 1;
      case "online payment":
        return 2;
      default:
        return 1;
    }
  }

  // Helper method for backward compatibility - converts Map to Address
  Future<OrderConfirmationResponse> confirmOrderWithMapAddress({
    required String deviceId,
    required String cartKey,
    required String tempOrderId,
    required String storeCode,
    required List<CartItem> cartItems,
    required Map<String, dynamic> deliveryAddressMap, // For backward compatibility
    required String deliverySlot,
    required String deliveryDate,
    required String deliveryMode,
    required String paymentMode,
    required double totalMrp,
    required double totalOurPrice,
    required double discount,
    required double deliveryCharges,
    required double discountedAmount,
    required double finalPayableAmount,
    required String paidAmount,
    String? accessKey,
    String? transactionId,
    String? specialNotes,
    String offerDetails = "No Offer",
    String mobPlatform = "Android",
  }) async {
    // Convert Map to Address model
    final address = Address.fromJson(deliveryAddressMap);
    
    // Call the main method with Address model
    return await confirmOrder(
      deviceId: deviceId,
      cartKey: cartKey,
      tempOrderId: tempOrderId,
      storeCode: storeCode,
      cartItems: cartItems,
      deliveryAddress: address,
      deliverySlot: deliverySlot,
      deliveryDate: deliveryDate,
      deliveryMode: deliveryMode,
      paymentMode: paymentMode,
      totalMrp: totalMrp,
      totalOurPrice: totalOurPrice,
      discount: discount,
      deliveryCharges: deliveryCharges,
      discountedAmount: discountedAmount,
      finalPayableAmount: finalPayableAmount,
      paidAmount: paidAmount,
      accessKey: accessKey,
      transactionId: transactionId,
      specialNotes: specialNotes,
      offerDetails: offerDetails,
      mobPlatform: mobPlatform,
    );
  }
}