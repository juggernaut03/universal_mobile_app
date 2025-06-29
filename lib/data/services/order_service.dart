// lib/data/services/order_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:patelmart/utils/payment_data_formatter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';
import '../models/outlet_model.dart';
import '../models/product_model.dart';
import '../models/address_model.dart';
import '../../presentation/providers/cart_provider.dart';
import 'payment_service.dart'; // Import PaymentService for PaymentResult

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

  // Updated confirmOrder method with enhanced payment data integration
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
    PaymentResult? paymentResult, // Enhanced payment result data
    PaymentDataFormat paymentFormat = PaymentDataFormat.both, // Allow format selection
  }) async {
    try {
      _logger.log('Preparing order confirmation request with enhanced payment data');
      
      // Generate UNIQUE identifiers
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
      final uniqueTempOrderId = 'ORDER_TEMP_${timestamp}_$randomSuffix';
      
      // Create order_date_time in the required format (ISO 8601)
      final orderDateTime = DateTime.now().toUtc().toIso8601String();
      
      // Console output for order preparation
      print('\n📋 === PREPARING ORDER CONFIRMATION === 📋');
      print('Order ID: $uniqueTempOrderId');
      print('Store Code: $storeCode');
      print('Device ID: $deviceId');
      print('Cart Items: ${cartItems.length}');
      print('Payment Mode: $paymentMode');
      print('Final Amount: ₹${finalPayableAmount.toStringAsFixed(2)}');
      print('Payment Result Available: ${paymentResult != null}');
      if (paymentResult != null) {
        print('Payment Success: ${paymentResult.success}');
        print('Payment ID: ${paymentResult.paymentId}');
        print('Full Payment Data: ${paymentResult.fullPaymentData != null}');
      }
      print('📋 === END PREPARATION === 📋\n');
      
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
        "discount": "0",
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
        "payment_status": paymentMode.toLowerCase() == "online payment" 
            ? "Payment Confirmed" 
            : "Pending",
        "payment_status_id": paymentMode.toLowerCase() == "online payment" ? 2 : 1,
        "paid_amount": paidAmount,
        "transaction_id": transactionId ?? "",
        
        "mob_platform": mobPlatform,
        "mobile_no": deliveryAddress.mobileNumber,
        
        // CRITICAL: Add order_date_time in UTC ISO format
        "order_date_time": orderDateTime,
      };
      
      // ENHANCED: Add complete payment data using the flexible formatter
      if (paymentResult != null) {
        _logger.log('Adding enhanced payment data to order request using ${paymentFormat.toString()} format');
        
        print('\n💳 === ADDING PAYMENT DATA TO ORDER === 💳');
        print('Payment Format: ${paymentFormat.toString()}');
        print('Payment Success: ${paymentResult.success}');
        print('Payment ID: ${paymentResult.paymentId}');
        
        // Use the PaymentDataFormatter to format the data
        final formattedPaymentData = PaymentDataFormatter.formatPaymentData(
          paymentResult: paymentResult,
          format: paymentFormat,
          arrayFieldName: "payment_gateway_data",
          stringFieldName: "payment_data_string", 
          razorpayArrayFieldName: "razorpay_payment_details",
          razorpayStringFieldName: "razorpay_payment_string",
        );
        
        // Add all formatted payment data to request body
        requestBody.addAll(formattedPaymentData);
        
        // Also add the exact Razorpay format for compatibility
        final exactRazorpayData = PaymentDataFormatter.getExactRazorpayFormat(paymentResult);
        requestBody.addAll(exactRazorpayData);
        
        // DEBUG: Log different formats being sent
        _logger.log('=== PAYMENT DATA BEING SENT TO API ===');
        _logger.log('Payment Format: ${paymentFormat.toString()}');
        _logger.log('Payment Success: ${paymentResult.success}');
        
        if (paymentResult.success) {
          _logger.log('Payment ID: ${paymentResult.paymentId}');
          _logger.log('Order ID: ${paymentResult.orderId}');
          _logger.log('Signature: ${paymentResult.signature}');
          _logger.log('Amount: ${paymentResult.amount}');
          _logger.log('Currency: ${paymentResult.currency}');
          _logger.log('Status: ${paymentResult.status}');
          _logger.log('Method: ${paymentResult.method}');
          _logger.log('VPA: ${paymentResult.vpa}');
          _logger.log('Contact: ${paymentResult.contact}');
          
          // Log each format being sent
          formattedPaymentData.forEach((key, value) {
            if (value is String) {
              _logger.log('$key (STRING): ${value.length} characters');
            } else if (value is List) {
              _logger.log('$key (ARRAY): ${value.length} items');
            } else {
              _logger.log('$key (OBJECT): ${value.runtimeType}');
            }
          });
          
          // Log the exact payment data structure
          if (paymentResult.fullPaymentData != null) {
            _logger.log('EXACT RAZORPAY DATA KEYS: ${paymentResult.fullPaymentData!.keys.toList()}');
            _logger.log('EXACT RAZORPAY DATA: ${jsonEncode(paymentResult.fullPaymentData)}');
          }
        } else {
          _logger.log('Payment Failed: ${paymentResult.message}');
        }
        _logger.log('=====================================');
        
        print('Payment Data Fields Added: ${formattedPaymentData.keys.toList()}');
        print('💳 === END PAYMENT DATA ADDITION === 💳\n');
        
        _logger.log('Payment data added to request body in ${paymentFormat.toString()} format');
      }
      
      _logger.log('Sending order confirmation with order_date_time: $orderDateTime');
      _logger.log('Request body keys: ${requestBody.keys.toList()}');
      
      // ENHANCED CONSOLE OUTPUT FOR POSTMAN
      print('\n🚀 === COMPLETE ORDER POST BODY FOR POSTMAN === 🚀');
      print('URL: ${ApiConstants.baseUrl}/confirm_order');
      print('Method: POST');
      print('Headers: {"Content-Type": "application/json"}');
      print('');
      print('📄 COMPLETE JSON BODY:');
      print('══════════════════════════════════════════════════');
      final prettyJsonString = JsonEncoder.withIndent('  ').convert(requestBody);
      print(prettyJsonString);
      print('══════════════════════════════════════════════════');
      print('');
      
      // Show specific payment fields if present
      if (requestBody.containsKey('payment_gateway_data')) {
        print('💳 PAYMENT GATEWAY DATA (Array):');
        print('─────────────────────────────────');
        print(JsonEncoder.withIndent('  ').convert(requestBody['payment_gateway_data']));
        print('');
      }
      
      if (requestBody.containsKey('razorpay_payment_details')) {
        print('🏦 RAZORPAY PAYMENT DETAILS (Array):');
        print('────────────────────────────────────');
        print(JsonEncoder.withIndent('  ').convert(requestBody['razorpay_payment_details']));
        print('');
      }
      
      if (requestBody.containsKey('payment_data_string')) {
        print('📝 PAYMENT DATA STRING:');
        print('─────────────────────');
        print(requestBody['payment_data_string']);
        print('');
      }
      
      if (requestBody.containsKey('razorpay_payment_string')) {
        print('📝 RAZORPAY PAYMENT STRING:');
        print('──────────────────────────');
        print(requestBody['razorpay_payment_string']);
        print('');
      }
      
      // CURL Command
      print('🖥️  CURL COMMAND:');
      print('──────────────────');
      print('curl -X POST "${ApiConstants.baseUrl}/confirm_order" \\');
      print('  -H "Content-Type: application/json" \\');
      print('  -d \'${jsonEncode(requestBody)}\'');
      print('');
      
      // Summary
      print('📊 REQUEST SUMMARY:');
      print('─────────────────');
      print('Total Fields: ${requestBody.keys.length}');
      print('Cart Items: ${cartItems.length}');
      print('Payment Data Included: ${paymentResult != null ? '✅' : '❌'}');
      print('Payment Success: ${paymentResult?.success ?? false ? '✅' : '❌'}');
      print('Order Date Time: ✅');
      print('JSON Size: ${jsonEncode(requestBody).length} characters');
      print('🚀 === END POSTMAN BODY === 🚀\n');
      
      // Legacy logging for compatibility
      _logger.log('=== COMPLETE ORDER CONFIRMATION REQUEST BODY FOR POSTMAN ===');
      _logger.log('URL: ${ApiConstants.baseUrl}/confirm_order');
      _logger.log('Method: POST');
      _logger.log('Headers: Content-Type: application/json');
      _logger.log('POST BODY: ${jsonEncode(requestBody)}');
      _logger.log('============================================================');
      
      // Make the API call
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/confirm_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Order confirmation response status: ${response.statusCode}');
      _logger.log('Order confirmation response body: ${response.body}');
      
      // ENHANCED CONSOLE OUTPUT FOR API RESPONSE
      print('\n📡 === API RESPONSE === 📡');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('');
      print('📄 Response Body:');
      print('─────────────────');
      try {
        final responseJson = jsonDecode(response.body);
        print(JsonEncoder.withIndent('  ').convert(responseJson));
      } catch (e) {
        print(response.body);
      }
      print('─────────────────');
      print('📡 === END API RESPONSE === 📡\n');
      
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
        
        print('\n✅ === ORDER SUCCESS === ✅');
        print('Order ID: $orderId');
        print('Message: ${responseData['message'] ?? 'Order placed successfully'}');
        if (paymentResult != null && paymentResult.success) {
          print('Payment ID: ${paymentResult.paymentId}');
          print('Payment Status: Confirmed');
        }
        print('✅ === END SUCCESS === ✅\n');
        
        _logger.log('Order placed successfully with ID: $orderId');
        
        return OrderConfirmationResponse(
          success: true,
          message: responseData['message'] ?? 'Order placed successfully',
          orderId: orderId,
          data: responseData,
        );
      } else {
        print('\n❌ === ORDER FAILED === ❌');
        print('Status Code: ${response.statusCode}');
        print('Error: ${response.body}');
        print('❌ === END FAILURE === ❌\n');
        
        _logger.error('Order confirmation failed: ${response.statusCode} - ${response.body}');
        return OrderConfirmationResponse(
          success: false,
          message: 'Failed to place order. Please try again.',
          error: Exception('API Error: ${response.statusCode}'),
        );
      }
    } catch (e) {
      print('\n💥 === ORDER ERROR === 💥');
      print('Error: $e');
      print('💥 === END ERROR === 💥\n');
      
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
    PaymentResult? paymentResult, // Enhanced payment result parameter
    PaymentDataFormat paymentFormat = PaymentDataFormat.both, // Add format parameter
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
      paymentResult: paymentResult, // Pass payment result
      paymentFormat: paymentFormat, // Pass payment format
    );
  }
}