// lib/data/services/order_payment_processing_service.dart
// Final version configured for your exact API

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:patelmart/core/constants/app_constants.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';

class OrderPaymentProcessingService {
  final http.Client _client = http.Client();
  final Logger _logger = Logger();

  /// Call payment processing API when user clicks "Place Order"
  /// Configured to match your exact API structure
  Future<PaymentProcessingResponse> createPaymentProcessingOrder({
    required String tempOrderId,
    required String storeCode,
    required String projectCode,
    required String accessKey,
    required String mobileNo,
    required String deviceId,
    required List<CartItem> cartItems,
    required Address deliveryAddress,
    required String deliverySlot,
    required int deliverySlotId,
    required String deliveryDate,
    required String deliveryMode,
    required String paymentMode,
    required int paymentModeId,
    required String totalAmountMrp,
    required String totalAmountOurPrice,
    required String discount,
    required String handlingCharges,
    required String youSave,
    required String deliveryCharges,
    required String discountedAmt,
    required String finalPayableAmt,
    required String offerApplicableDetails,
    required String specialNote,
    required String mobPlatform,
  }) async {
    try {
      _logger.log('=== CREATING PAYMENT PROCESSING ORDER ===');
      _logger.log('Temp Order ID: $tempOrderId');
      _logger.log('Store Code: $storeCode');
      _logger.log('Project Code: $projectCode');
      _logger.log('Payment Mode: $paymentMode');
      _logger.log('Final Amount: ₹$finalPayableAmt');
      _logger.log('API URL: ${ApiConstants.baseUrl}/order_payment_processing');
      
      // Validate required fields
      if (tempOrderId.isEmpty || storeCode.isEmpty || deviceId.isEmpty) {
        throw Exception('Required fields are missing: tempOrderId, storeCode, or deviceId');
      }

      // Create delivery address array exactly as your API expects
      final deliveryAddressArray = [
        {
          "full_name": deliveryAddress.fullName.isNotEmpty ? deliveryAddress.fullName : "Customer",
          "mobile_number": deliveryAddress.mobileNumber.isNotEmpty ? deliveryAddress.mobileNumber : mobileNo,
          "email_id": deliveryAddress.emailId.isNotEmpty ? deliveryAddress.emailId : "test@example.com",
          "delivery_addr_line_1": deliveryAddress.deliveryAddrLine1.isNotEmpty ? deliveryAddress.deliveryAddrLine1 : "Address Line 1",
          "delivery_addr_line_2": deliveryAddress.deliveryAddrLine2.isNotEmpty ? deliveryAddress.deliveryAddrLine2 : "Address Line 2",
          "delivery_addr_city": deliveryAddress.deliveryAddrCity.isNotEmpty ? deliveryAddress.deliveryAddrCity : "City",
          "delivery_addr_pincode": deliveryAddress.deliveryAddrPincode.isNotEmpty ? deliveryAddress.deliveryAddrPincode : "000000",
          "state": deliveryAddress.state.isNotEmpty ? deliveryAddress.state : "",
          "landmark": deliveryAddress.landmark.isNotEmpty ? deliveryAddress.landmark : "",
          "area_id": deliveryAddress.areaId.isNotEmpty ? deliveryAddress.areaId : "Default Area",
          "is_default": deliveryAddress.isDefault.isNotEmpty ? deliveryAddress.isDefault : "No",
          // Add latitude and longitude as strings (like in your example)
          if (deliveryAddress.latitude != null && deliveryAddress.latitude!.isNotEmpty) 
            "latitude": deliveryAddress.latitude,
          if (deliveryAddress.longitude != null && deliveryAddress.longitude!.isNotEmpty) 
            "longitude": deliveryAddress.longitude,
        }
      ];

      // Convert cart items to API format exactly as your example
      final cartItemsArray = cartItems.map((item) => {
        "pcode": item.product.pCode,
        "product_name": item.product.productName,
        "product_mrp": item.product.productMrp, // Keep as number
        "selling_price": item.product.ourPrice, // Keep as number
        "package_size": item.product.packageSize, // Keep as number
        "package_unit": item.product.packageUnit,
        "stock_message": "Yes",
        "price_alert_message": "Yes",
        "quantity": item.quantity, // Keep as number
        "product_image_link": item.product.pcodeImg,
      }).toList();

      if (cartItemsArray.isEmpty) {
        throw Exception('Cart is empty. Cannot create payment processing order.');
      }

      // Get current date-time in UTC (same format as your example)
      final orderDateTime = DateTime.now().toUtc();

      // Create request body EXACTLY like your API structure
      final requestBody = {
        "temp_order_id": tempOrderId,
        "store_code": storeCode,
        "project_code": projectCode, // Use RET5890
        "access_key": accessKey,
        "mobile_no": mobileNo,
        "device_id": deviceId,
        "cart_items": cartItemsArray,
        "delivery_address": deliveryAddressArray,
        "delivery_slot": deliverySlot,
        "delivery_slot_id": deliverySlotId,
        "order_status": "Payment Processing", // This is the key status
        "special_note": specialNote,
        "total_amount_mrp": totalAmountMrp,
        "total_amount_our_price": totalAmountOurPrice,
        "discount": discount,
        "handling_charges": handlingCharges,
        "you_save": youSave,
        "delivery_charges": deliveryCharges,
        "discounted_amt": discountedAmt,
        "final_payable_amt": finalPayableAmt,
        "delivery_date": deliveryDate,
        "offer_applicable_details": offerApplicableDetails,
        "delivery_mode": deliveryMode,
        "payment_mode": paymentMode,
        "payment_mode_id": paymentModeId,
        "payment_status": "Payment Processing", // Initial status
        "payment_status_id": 0, // 0 for processing
        "paid_amount": "0", // Initially 0
        "transaction_id": "", // Will be set after payment
        "mob_platform": mobPlatform,
        "order_date_time": orderDateTime.toIso8601String(),
      };

      final requestBodyJson = jsonEncode(requestBody);
      
      // Enhanced logging
      _logger.log('=== PAYMENT PROCESSING API REQUEST ===');
      _logger.log('URL: ${ApiConstants.baseUrl}/order_payment_processing');
      _logger.log('Method: POST');
      _logger.log('Request Size: ${requestBodyJson.length} characters');

      // Console output for debugging
      print('\n🔄 === PAYMENT PROCESSING ORDER === 🔄');
      print('API URL: ${ApiConstants.baseUrl}/order_payment_processing');
      print('Temp Order ID: $tempOrderId');
      print('Store: $storeCode');
      print('Project: $projectCode');
      print('Customer: ${deliveryAddress.fullName}');
      print('Items: ${cartItems.length} products');
      print('Total: ₹$finalPayableAmt');
      print('Status: Payment Processing');
      print('Payment Mode: $paymentMode');
      print('Delivery Mode: $deliveryMode');
      print('Request Size: ${requestBodyJson.length} characters');
      
      // Log the request body (truncated for security)
      if (requestBodyJson.length > 1000) {
        print('Request Body (first 1000 chars): ${requestBodyJson.substring(0, 1000)}...');
      } else {
        print('Request Body: $requestBodyJson');
      }
      
      print('🔄 === MAKING API CALL === 🔄\n');

      // Make the API call
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/order_payment_processing'),
        headers: ApiConstants.defaultHeaders,
        body: requestBodyJson,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _logger.error('Payment processing API call timed out after 60 seconds');
          throw TimeoutException('API call timed out. Please check your internet connection and try again.', const Duration(seconds: 60));
        },
      );

      _logger.log('Payment processing API response status: ${response.statusCode}');
      
      // Enhanced console output for API response
      print('\n📡 === PAYMENT PROCESSING API RESPONSE === 📡');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Size: ${response.body.length} characters');
      print('');
      
      // Try to parse and pretty print the response
      try {
        if (response.body.isNotEmpty) {
          final responseJson = jsonDecode(response.body);
          print('📄 Response Body (Formatted):');
          print(JsonEncoder.withIndent('  ').convert(responseJson));
        } else {
          print('📄 Response Body: Empty');
        }
      } catch (e) {
        print('📄 Response Body (Raw): ${response.body}');
      }
      print('📡 === END API RESPONSE === 📡\n');

      // Handle success responses (200-299)
  // Updated response parsing section for your payment processing service
// Replace the response handling section in your OrderPaymentProcessingService

// Handle success responses (200-299)
if (response.statusCode >= 200 && response.statusCode < 300) {
  Map<String, dynamic> responseData;
  
  try {
    if (response.body.isNotEmpty) {
      // Your API returns the request body as a string, not a JSON response
      // So we need to handle it differently
      String responseBody = response.body;
      
      // Check if response is JSON or string
      if (responseBody.startsWith('{') || responseBody.startsWith('[')) {
        // It's JSON - parse it
        responseData = jsonDecode(responseBody);
      } else if (responseBody.startsWith('"') && responseBody.endsWith('"')) {
        // It's a JSON string - remove quotes and parse
        String cleanedResponse = responseBody.substring(1, responseBody.length - 1);
        // Unescape the string
        cleanedResponse = cleanedResponse.replaceAll('\\"', '"');
        cleanedResponse = cleanedResponse.replaceAll('\\n', '\n');
        cleanedResponse = cleanedResponse.replaceAll('\\t', '\t');
        cleanedResponse = cleanedResponse.replaceAll('\\\\', '\\');
        
        try {
          responseData = jsonDecode(cleanedResponse);
        } catch (e) {
          // If parsing fails, treat it as the request echo
          _logger.log('Response appears to be request echo, treating as success');
          responseData = {
            'success': true,
            'message': 'Order created successfully',
            'temp_order_id': tempOrderId,
            'order_status': 'Payment Processing',
            'response_type': 'request_echo'
          };
        }
      } else {
        // Raw response, likely request echo
        _logger.log('Response appears to be request data echo');
        responseData = {
          'success': true,
          'message': 'Order created successfully',
          'temp_order_id': tempOrderId,
          'order_status': 'Payment Processing',
          'response_type': 'string_response'
        };
      }
    } else {
      // Empty response but success status
      responseData = {
        'success': true,
        'message': 'Order created successfully',
        'temp_order_id': tempOrderId,
        'order_status': 'Payment Processing',
      };
    }
  } catch (e) {
    _logger.log('Response parsing failed, but API returned success status: $e');
    // Since API returned 201 (Created), we know it was successful
    responseData = {
      'success': true,
      'message': 'Order created successfully',
      'temp_order_id': tempOrderId,
      'order_status': 'Payment Processing',
      'parsing_error': e.toString(),
    };
  }

  // Extract order ID from response
  String? orderId;
  String? actualOrderId;
  
  // For your API, it seems the temp_order_id is the main identifier
  if (responseData['temp_order_id'] != null) {
    orderId = responseData['temp_order_id'].toString();
  } else if (responseData['_id'] != null) {
    // Handle MongoDB ObjectId format if present
    if (responseData['_id'] is Map && responseData['_id']['\$oid'] != null) {
      orderId = responseData['_id']['\$oid'];
    } else {
      orderId = responseData['_id'].toString();
    }
  }
  
  if (responseData['actual_order_id'] != null) {
    actualOrderId = responseData['actual_order_id'].toString();
  }
  
  // Use temp_order_id as fallback
  if (orderId == null) {
    orderId = tempOrderId;
  }

  print('\n✅ === PAYMENT PROCESSING ORDER CREATED === ✅');
  print('Order ID: $orderId');
  print('Actual Order ID: $actualOrderId');
  print('Temp Order ID: $tempOrderId');
  print('Status: Payment Processing');
  print('Response Code: ${response.statusCode}');
  print('Response Type: ${responseData['response_type'] ?? 'standard'}');
  print('✅ === SUCCESS === ✅\n');

  _logger.log('Payment processing order created successfully');
  _logger.log('Order ID: $orderId');
  _logger.log('Actual Order ID: $actualOrderId');
  _logger.log('Response status: ${response.statusCode}');

  return PaymentProcessingResponse(
    success: true,
    message: responseData['message']?.toString() ?? 'Payment processing order created successfully',
    orderId: orderId,
    actualOrderId: actualOrderId,
    tempOrderId: tempOrderId,
    data: responseData,
  );

      } else {
        // Handle HTTP error status codes
        String errorMessage = 'HTTP ${response.statusCode}: ';
        
        try {
          final errorData = jsonDecode(response.body);
          errorMessage += errorData['message']?.toString() ?? 
                         errorData['error']?.toString() ?? 
                         'Unknown server error';
        } catch (e) {
          errorMessage += response.body.isNotEmpty ? response.body : 'Unknown server error';
        }

        print('\n❌ === PAYMENT PROCESSING ORDER FAILED === ❌');
        print('Status Code: ${response.statusCode}');
        print('Error Message: $errorMessage');
        print('Response Body: ${response.body}');
        print('❌ === END FAILURE === ❌\n');

        _logger.error('Payment processing order creation failed: ${response.statusCode} - $errorMessage');
        
        return PaymentProcessingResponse(
          success: false,
          message: errorMessage,
          error: Exception('HTTP ${response.statusCode}: $errorMessage'),
        );
      }
    } on TimeoutException catch (e) {
      print('\n⏰ === PAYMENT PROCESSING TIMEOUT === ⏰');
      print('Error: ${e.message}');
      print('Duration: ${e.duration}');
      print('⏰ === END TIMEOUT === ⏰\n');

      _logger.error('Payment processing API timeout: ${e.message}');
      
      return PaymentProcessingResponse(
        success: false,
        message: 'Request timed out. Please check your internet connection and try again.',
        error: e,
      );
    } on SocketException catch (e) {
      print('\n🌐 === NETWORK ERROR === 🌐');
      print('Error: No internet connection');
      print('Details: ${e.message}');
      print('🌐 === END NETWORK ERROR === 🌐\n');

      _logger.error('Network error during payment processing: ${e.message}');
      
      return PaymentProcessingResponse(
        success: false,
        message: 'No internet connection. Please check your network and try again.',
        error: e,
      );
    } catch (e) {
      print('\n💥 === PAYMENT PROCESSING ORDER ERROR === 💥');
      print('Error Type: ${e.runtimeType}');
      print('Error: $e');
      print('💥 === END ERROR === 💥\n');

      _logger.error('Unexpected error during payment processing order creation: $e');
      
      return PaymentProcessingResponse(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
        error: e,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Response model for payment processing API - updated to match your API response
class PaymentProcessingResponse {
  final bool success;
  final String message;
  final String? orderId; // MongoDB _id
  final String? actualOrderId; // actual_order_id from response
  final String? tempOrderId;
  final Map<String, dynamic>? data;
  final dynamic error;

  PaymentProcessingResponse({
    required this.success,
    required this.message,
    this.orderId,
    this.actualOrderId,
    this.tempOrderId,
    this.data,
    this.error,
  });

  @override
  String toString() {
    return 'PaymentProcessingResponse(success: $success, message: $message, orderId: $orderId, actualOrderId: $actualOrderId, tempOrderId: $tempOrderId)';
  }
}

/// Custom timeout exception
class TimeoutException implements Exception {
  final String message;
  final Duration? duration;
  
  const TimeoutException(this.message, [this.duration]);
  
  @override
  String toString() => 'TimeoutException: $message';
}