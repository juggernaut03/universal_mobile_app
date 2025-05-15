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

  // Updated confirmOrder method to include access_key
  Future<OrderConfirmationResponse> confirmOrder({
    required String deviceId,
    required String cartKey,  // This will be used only for reference, we'll generate a new one
    required String tempOrderId,
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
    String? accessKey,  // Add access key parameter
    String? transactionId,
    String? specialNotes,
    String offerDetails = "No Offer",
    String mobPlatform = "Android",
  }) async {
    try {
      _logger.log('Preparing order confirmation request');
      
      // Generate a unique cart key for this specific order
      // This ensures we create a new entry rather than updating existing ones
      final uniqueOrderCartKey = 'CART_KEY_ORDER_${DateTime.now().millisecondsSinceEpoch}';
      
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
      
      // Create request body for a NEW cart document
      final Map<String, dynamic> requestBody = {
        "temp_order_id": tempOrderId,
        "project_code": ApiConstants.projectCode,
        "customer_cart_key": uniqueOrderCartKey,
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
      
      // Add access key to the request body if provided
      if (accessKey != null && accessKey.isNotEmpty) {
        requestBody["access_key"] = accessKey;
        _logger.log('Including access key in order confirmation request');
      } else {
        _logger.warning('No access key provided for order confirmation');
      }
      
      _logger.log('Sending NEW order confirmation request with unique cart key: $uniqueOrderCartKey, '
          'temp_order_id: $tempOrderId');
      _logger.log('Order details: Items: ${cartItems.length}, Total: $finalPayableAmount, Mode: $paymentMode');
      
      // Make the API call with timeout
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/confirm_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      // Log the response for debugging
      _logger.log('Order confirmation response status: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        final logLength = response.body.length > 100 ? 100 : response.body.length;
        _logger.log('Order confirmation response body: ${response.body.substring(0, logLength)}...');
      }
      
      // Process the response
      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          _logger.error('Error decoding response JSON: $e');
          responseData = {'message': 'Success but unable to parse response details'};
        }
        
        _logger.log('Order confirmation successful: ${responseData['message'] ?? "No message"}');
        
        // Extract order ID from the response if available
        String? orderId;
        if (responseData['insertedItems'] != null && 
            responseData['insertedItems'] is List &&
            (responseData['insertedItems'] as List).isNotEmpty) {
          orderId = responseData['insertedItems'][0]['_id'];
          _logger.log('Extracted order ID: $orderId');
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