// lib/data/services/order_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';
import '../models/outlet_model.dart';
import '../models/product_model.dart';
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

  Future<OrderConfirmationResponse> confirmOrder({
    required String deviceId,
    required String cartKey,
    required String storeCode,
    required List<CartItem> cartItems,
    required Map<String, dynamic> deliveryAddress,
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
    String? transactionId,
    String? specialNotes,
    String offerDetails = "No Offer",
    String mobPlatform = "Android",
  }) async {
    try {
      _logger.log('Preparing order confirmation request');
      
      // Format cart items for API
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
      
      // Construct the request body
      final Map<String, dynamic> requestBody = {
        "temp_order_id": "AND_$deviceId", // Using device ID as part of order ID
        "project_code": ApiConstants.projectCode,
        "customer_cart_key": cartKey,
        "store_code": storeCode,
        "device_id": deviceId,
        "delivery_slot": deliverySlot,
        "special_note": specialNotes ?? "",
        "total_amount_mrp": totalMrp,
        "total_amount_our_price": totalOurPrice,
        "discount": discount,
        "delivery_charges": deliveryCharges,
        "discounted_amt": discountedAmount,
        "final_payable_amt": finalPayableAmount,
        "delivery_date": deliveryDate,
        "delivery_mode": deliveryMode,
        "offer_applicable_details": offerDetails,
        "order_status": "Order Confirmed",
        "paid_amount": paidAmount,
        "payment_mode": paymentMode,
        "payment_status": paymentMode == "ONLINE" 
            ? "Payment Confirmed" 
            : "Payment Confirmation Pending",
        "mob_platform": mobPlatform,
        "transaction_id": transactionId ?? "",
        "delivery_address": [deliveryAddress],
        "cart_items": formattedCartItems,
      };
      
      _logger.log('Sending order confirmation request: ${jsonEncode(requestBody)}');
      
      // Make the API call with timeout
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/confirm_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      // Process the response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        _logger.log('Order confirmation successful: ${response.body}');
        
        // Extract order ID from the response if available
        String? orderId;
        if (responseData['insertedItems'] != null && 
            responseData['insertedItems'].isNotEmpty) {
          orderId = responseData['insertedItems'][0]['_id'];
        }
        
        return OrderConfirmationResponse(
          success: true,
          message: responseData['message'] ?? 'Order placed successfully',
          orderId: orderId,
          data: responseData,
        );
      } else {
        _logger.error('Order confirmation failed with status: ${response.statusCode}');
        return OrderConfirmationResponse(
          success: false,
          message: 'Failed to place order. Please try again.',
          error: Exception('API Error: ${response.statusCode}'),
        );
      }
    } on TimeoutException {
      _logger.error('Order confirmation request timed out');
      return OrderConfirmationResponse(
        success: false,
        message: 'Request timed out. Please check your internet connection and try again.',
        error: Exception('Request timed out'),
      );
    } catch (e) {
      _logger.error('Error during order confirmation: $e');
      return OrderConfirmationResponse(
        success: false,
        message: 'An error occurred while placing your order: ${e.toString()}',
        error: e,
      );
    }
  }

  // Helper method to generate a mock order ID
  // In a real implementation, this might come from the backend
  String generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ORD_$timestamp';
  }
}