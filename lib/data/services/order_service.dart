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

  // Updated confirmOrder method with proper address handling including pincode
  Future<OrderConfirmationResponse> confirmOrder({
    required String deviceId,
    required String cartKey,
    required String tempOrderId,
    required String storeCode,
    required List<CartItem> cartItems,
    required Address deliveryAddress, // Changed to Address model for better structure
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
      _logger.log('Preparing order confirmation request');
      
      // Generate UNIQUE identifiers for this specific order
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
      
      // Create unique cart key for this order
      final uniqueOrderCartKey = 'ORDER_${timestamp}_$randomSuffix';
      final uniqueTempOrderId = 'ORDER_TEMP_${timestamp}_$randomSuffix';
      
      _logger.log('Generated unique identifiers:');
      _logger.log('Cart Key: $uniqueOrderCartKey');
      _logger.log('Temp Order ID: $uniqueTempOrderId');
      
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
      
      // Format delivery address with all required fields including pincode
      final Map<String, dynamic> formattedDeliveryAddress = {
  // Standard address fields
  "full_name": deliveryAddress.fullName,
  "mobile_number": deliveryAddress.mobileNumber,
  "email_id": deliveryAddress.emailId,
  "delivery_addr_line_1": deliveryAddress.deliveryAddrLine1,
  "delivery_addr_line_2": deliveryAddress.deliveryAddrLine2,
  "delivery_addr_city": deliveryAddress.deliveryAddrCity,  
  "delivery_addr_pincode": deliveryAddress.deliveryAddrPincode,
 
 
  
  // Other required fields
  "state": deliveryAddress.state,
  "landmark": deliveryAddress.landmark,
  "area_id": deliveryAddress.areaId,
  "is_default": deliveryAddress.isDefault,
};

// Add coordinates if available
if (deliveryAddress.latitude != null && deliveryAddress.latitude!.isNotEmpty) {
  formattedDeliveryAddress["latitude"] = deliveryAddress.latitude;
}
if (deliveryAddress.longitude != null && deliveryAddress.longitude!.isNotEmpty) {
  formattedDeliveryAddress["longitude"] = deliveryAddress.longitude;
}

_logger.log('Formatted delivery address with pincode: ${deliveryAddress.deliveryAddrPincode}');
_logger.log('Address object: ${jsonEncode(formattedDeliveryAddress)}');

// Create request body with UNIQUE identifiers and properly formatted address
   final Map<String, dynamic> requestBody = {
  "temp_order_id": uniqueTempOrderId,
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
  
  // Delivery address array with properly formatted address
  "delivery_address": [formattedDeliveryAddress],
  
  // Cart items
  "cart_items": formattedCartItems,
  
 
};
      // Add access key if provided
      if (accessKey != null && accessKey.isNotEmpty) {
        requestBody["access_key"] = accessKey;
        _logger.log('Including access key in order confirmation request');
      }
      
      _logger.log('Sending order confirmation with address pincode: ${deliveryAddress.deliveryAddrPincode}');
      _logger.log('Request body delivery_address: ${jsonEncode(formattedDeliveryAddress)}');
      
      // Make the API call
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/confirm_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Order confirmation response status: ${response.statusCode}');
      
      // Process the response
      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          _logger.error('Error decoding response JSON: $e');
          responseData = {'message': 'Success but unable to parse response details'};
        }
        
        _logger.log('Order confirmation successful with pincode: ${deliveryAddress.deliveryAddrPincode}');
        
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
        _logger.error('Order confirmation failed with status: ${response.statusCode}');
        _logger.error('Response body: ${response.body}');
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