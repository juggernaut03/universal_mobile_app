// lib/data/services/order_payment_processing_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/address_model.dart';
import '../../presentation/providers/cart_provider.dart';

class OrderPaymentProcessingResponse {
  final bool success;
  final String message;
  final String? orderId;
  final String? tempOrderId;
  final Map<String, dynamic>? data;
  final Object? error;

  OrderPaymentProcessingResponse({
    required this.success,
    required this.message,
    this.orderId,
    this.tempOrderId,
    this.data,
    this.error,
  });

  @override
  String toString() {
    return 'OrderPaymentProcessingResponse(success: $success, message: $message, orderId: $orderId, tempOrderId: $tempOrderId)';
  }
}

class OrderPaymentProcessingService {
  final http.Client _client;
  final Logger _logger;

  OrderPaymentProcessingService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  // FIXED: Enhanced method to call the order_payment_processing API with all required fields
  Future<OrderPaymentProcessingResponse> markOrderAsPaymentProcessing({
    required String deviceId,
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
    String? accessKey,
    String? mobileNo,
    String? specialNotes,
    String offerDetails = "No Offer",
    String mobPlatform = "Android",
  }) async {
    try {
      _logger.log('=== CALLING ORDER PAYMENT PROCESSING API ===');
      _logger.log('Temp Order ID: $tempOrderId');
      _logger.log('Store Code: $storeCode');
      _logger.log('Payment Mode: $paymentMode');
      _logger.log('Final Amount: ₹${finalPayableAmount.toStringAsFixed(2)}');
      
      // Validate required fields before API call
      if (tempOrderId.isEmpty) {
        throw Exception('Temp Order ID cannot be empty');
      }
      
      if (storeCode.isEmpty) {
        throw Exception('Store Code cannot be empty');
      }
      
      if (cartItems.isEmpty) {
        throw Exception('Cart items cannot be empty');
      }
      
      if (deliveryAddress.fullName.isEmpty) {
        throw Exception('Delivery address name cannot be empty');
      }
      
      // Calculate financial details
      final youSave = totalMrp - totalOurPrice;
      
      // Format cart items for API - ensure no null values
      final formattedCartItems = cartItems.map((item) => {
        "pcode": item.product.pCode,
        "product_name": item.product.productName,
        "product_mrp": item.product.productMrp,
        "selling_price": item.product.ourPrice,
        "package_size": item.product.packageSize ?? "1",
        "package_unit": item.product.packageUnit ?? "pc",
        "stock_message": "Yes", // Always "Yes" for payment processing
        "price_alert_message": "Yes", // Always "Yes" for payment processing
        "quantity": item.quantity,
        "product_image_link": item.product.pcodeImg ?? "",
      }).toList();

      // FIXED: Build complete request body with ALL required fields and proper validation
      final requestBody = {
        "temp_order_id": tempOrderId,
        "store_code": storeCode,
        "project_code": ApiConstants.projectCode, // CRITICAL: Must be present
        
        // FIXED: Ensure access_key and mobile_no are always present (not conditional)
        "access_key": accessKey ?? "", // Don't use conditional - always include
        "mobile_no": mobileNo ?? "", // Don't use conditional - always include
        "device_id": deviceId,
        
        // Cart items array - guaranteed not empty due to validation above
        "cart_items": formattedCartItems,
        
        // FIXED: Delivery address as array with complete data and null safety
        "delivery_address": [
          {
            "full_name": deliveryAddress.fullName.isNotEmpty ? deliveryAddress.fullName : "Customer",
            "mobile_number": deliveryAddress.mobileNumber.isNotEmpty ? deliveryAddress.mobileNumber : (mobileNo ?? ""),
            "email_id": deliveryAddress.emailId ?? "",
            "delivery_addr_line_1": deliveryAddress.deliveryAddrLine1.isNotEmpty ? deliveryAddress.deliveryAddrLine1 : "Address Line 1",
            "delivery_addr_line_2": deliveryAddress.deliveryAddrLine2 ?? "",
            "delivery_addr_city": deliveryAddress.deliveryAddrCity.isNotEmpty ? deliveryAddress.deliveryAddrCity : "City",
            "delivery_addr_pincode": deliveryAddress.deliveryAddrPincode.isNotEmpty ? deliveryAddress.deliveryAddrPincode : "000000",
            "state": deliveryAddress.state ?? "",
            "landmark": deliveryAddress.landmark ?? "",
            "area_id": deliveryAddress.areaId ?? "",
            "is_default": deliveryAddress.isDefault ?? "Yes",
            "latitude": deliveryAddress.latitude ?? "",
            "longitude": deliveryAddress.longitude ?? "",
          }
        ],
        
        // Delivery details
        "delivery_slot": deliverySlot,
        "delivery_slot_id": _getDeliverySlotId(deliverySlot),
        "order_status": "Payment Processing", // CRITICAL: This is the key status for this API
        "special_note": specialNotes ?? "",

        
        // Financial details (matching API format) - ensure all are strings
        "total_amount_mrp": totalMrp.toString(),
        "total_amount_our_price": totalOurPrice.toString(),
        "discount": "0", // Always 0 for payment processing stage
        "handling_charges": "0", // Always 0 for payment processing stage
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
        "payment_status": "Payment Processing", // Processing status
        "payment_status_id": 1, // Processing status ID
        "paid_amount": "0", // No payment captured yet
        "transaction_id": "", // Will be filled after payment
        "mob_platform": mobPlatform,
        
        // Add order_date_time field in correct format
      //  "order_date_time": {
      //    "\$date": DateTime.now().toUtc().toIso8601String()
      //  },
        
        // Empty payment gateway data initially
        "payment_gateway_data": [],
      };

      // ENHANCED: Comprehensive debugging output
      print('\n🔍 === COMPLETE API REQUEST DEBUG === 🔍');
      print('URL: ${ApiConstants.baseUrl}/order_payment_processing');
      print('Method: POST');
      print('Headers: Content-Type: application/json');
      print('');
      print('🔍 CRITICAL FIELDS VALIDATION:');
      print('- temp_order_id: ${requestBody["temp_order_id"]} ✓');
      print('- store_code: ${requestBody["store_code"]} ✓');
      print('- project_code: ${requestBody["project_code"]} ${requestBody["project_code"] != null ? "✓" : "❌ MISSING"}');
      print('- access_key: ${requestBody["access_key"]} ${(requestBody["access_key"] as String).isNotEmpty ? "✓" : "❌ EMPTY"}');
      print('- mobile_no: ${requestBody["mobile_no"]} ${(requestBody["mobile_no"] as String).isNotEmpty ? "✓" : "❌ EMPTY"}');
      print('- device_id: ${requestBody["device_id"]} ✓');
      print('- cart_items count: ${(requestBody["cart_items"] as List).length} ${(requestBody["cart_items"] as List).isNotEmpty ? "✓" : "❌ EMPTY"}');
      print('- delivery_address count: ${(requestBody["delivery_address"] as List).length} ✓');
      print('- order_status: ${requestBody["order_status"]} ✓');
      print('- final_payable_amt: ${requestBody["final_payable_amt"]} ✓');
      print('');
      
      print('📄 COMPLETE REQUEST BODY:');
      print('═══════════════════════════════════════════════════');
      final prettyJsonString = JsonEncoder.withIndent('  ').convert(requestBody);
      print(prettyJsonString);
      print('═══════════════════════════════════════════════════');
      print('🔍 === END COMPLETE DEBUG === 🔍\n');

      // Enhanced console output for debugging
      print('🔄 === ORDER PAYMENT PROCESSING API CALL === 🔄');
      print('URL: ${ApiConstants.baseUrl}/order_payment_processing');
      print('Temp Order ID: $tempOrderId');
      print('Status: Payment Processing');
      print('Amount: ₹${finalPayableAmount.toStringAsFixed(2)}');
      print('Customer: ${deliveryAddress.fullName}');
      print('Cart Items: ${cartItems.length}');
      print('🔄 === SENDING REQUEST === 🔄\n');
      
      _logger.log('=== ORDER PAYMENT PROCESSING REQUEST BODY ===');
      _logger.log('URL: ${ApiConstants.baseUrl}/order_payment_processing');
      _logger.log('POST BODY: ${jsonEncode(requestBody)}');
      _logger.log('===============================================');
      
      // Make the API call with timeout
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/order_payment_processing'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Payment processing API request timed out after 30 seconds');
        },
      );
      
      _logger.log('Order payment processing response status: ${response.statusCode}');
      _logger.log('Order payment processing response body: ${response.body}');
      
      // ENHANCED: Detailed response analysis
      print('\n📡 === PAYMENT PROCESSING API RESPONSE === 📡');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Time: ${DateTime.now().toIso8601String()}');
      print('');
      print('📄 Response Body:');
      print('─────────────────');
      print(response.body);
      print('─────────────────');
      
      // Try to parse and analyze response
      try {
        final responseJson = jsonDecode(response.body);
        print('');
        print('🔍 Parsed Response Analysis:');
        if (responseJson is Map) {
          responseJson.forEach((key, value) {
            print('  $key: $value');
          });
          
          // Check for specific fields
          if (responseJson.containsKey('order_status')) {
            print('✅ Backend confirmed order_status: ${responseJson['order_status']}');
          } else {
            print('⚠️  Backend did NOT return order_status field');
          }
          
          if (responseJson.containsKey('_id')) {
            print('✅ Backend generated order ID: ${responseJson['_id']}');
          }
          
          if (responseJson.containsKey('error')) {
            print('❌ Backend Error: ${responseJson['error']}');
          }
        }
      } catch (parseError) {
        print('⚠️  Could not parse response as JSON: $parseError');
      }
      print('📡 === END API RESPONSE === 📡\n');
      
      // Process successful response (200 or 201)
      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          responseData = {
            'message': 'Success but unable to parse response details',
            'raw_response': response.body,
          };
        }
        
        // Extract order ID and temp order ID from response with multiple strategies
        String? orderId;
        String? returnedTempOrderId;
        
        // Strategy 1: Check for _id field
        if (responseData.containsKey('_id')) {
          orderId = responseData['_id']?.toString();
        }
        
        // Strategy 2: Check for order_id field
        if (orderId == null && responseData.containsKey('order_id')) {
          orderId = responseData['order_id']?.toString();
        }
        
        // Strategy 3: Check insertedItems array
        if (orderId == null && responseData.containsKey('insertedItems')) {
          final insertedItems = responseData['insertedItems'];
          if (insertedItems is List && insertedItems.isNotEmpty) {
            final firstItem = insertedItems.first;
            if (firstItem is Map && firstItem.containsKey('_id')) {
              orderId = firstItem['_id']?.toString();
            }
          }
        }
        
        // Get temp order ID from response
        if (responseData.containsKey('temp_order_id')) {
          returnedTempOrderId = responseData['temp_order_id']?.toString();
        }
        
        // Enhanced success output
        print('\n✅ === PAYMENT PROCESSING MARKED === ✅');
        print('Order ID: ${orderId ?? "Generated"}');
        print('Temp Order ID: ${returnedTempOrderId ?? tempOrderId}');
        print('Status: Payment Processing');
        print('Message: ${responseData['message'] ?? 'Order marked for payment processing'}');
        print('API Response Code: ${response.statusCode}');
        if (responseData.containsKey('order_status')) {
          print('Confirmed Order Status: ${responseData['order_status']}');
        }
        print('✅ === END SUCCESS === ✅\n');
        
        _logger.log('Order marked as payment processing successfully');
        _logger.log('Order ID: ${orderId ?? "Generated"}');
        _logger.log('Response: ${responseData['message'] ?? 'Success'}');
        
        return OrderPaymentProcessingResponse(
          success: true,
          message: responseData['message'] ?? 'Order marked for payment processing',
          orderId: orderId,
          tempOrderId: returnedTempOrderId ?? tempOrderId,
          data: responseData,
        );
        
      } else {
        // Handle API error responses
        String errorMessage = 'Failed to mark order as payment processing: ${response.statusCode}';
        Map<String, dynamic>? errorData;
        
        try {
          final decodedResponse = jsonDecode(response.body);
          if (decodedResponse != null && decodedResponse is Map<String, dynamic>) {
            errorData = decodedResponse;
            if (errorData!.containsKey('message')) {
              errorMessage = errorData!['message']?.toString() ?? errorMessage;
            } else if (errorData!.containsKey('error')) {
              errorMessage = errorData!['error']?.toString() ?? errorMessage;
            }
          }
        } catch (e) {
          errorMessage = 'Server returned error: ${response.statusCode}';
        }
        
        _logger.error(errorMessage);
        _logger.error('Response body: ${response.body}');
        
        print('\n❌ === PAYMENT PROCESSING FAILED === ❌');
        print('Status Code: ${response.statusCode}');
        print('Error Message: $errorMessage');
        print('Response Body: ${response.body}');
        print('❌ === END FAILURE === ❌\n');
        
        return OrderPaymentProcessingResponse(
          success: false,
          message: errorMessage,
          tempOrderId: tempOrderId,
          error: response.body,
          data: errorData,
        );
      }
      
    } catch (e) {
      // Handle exceptions
      String errorMessage = 'Error calling order payment processing API';
      
      if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      _logger.error(errorMessage);
      _logger.error('Exception details: $e');
      
      print('\n💥 === PAYMENT PROCESSING ERROR === 💥');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $errorMessage');
      print('Exception: $e');
      print('💥 === END ERROR === 💥\n');
      
      return OrderPaymentProcessingResponse(
        success: false,
        message: errorMessage,
        tempOrderId: tempOrderId,
        error: e,
      );
    }
  }

  // ENHANCED: Helper method to get delivery slot ID with comprehensive mapping
  int _getDeliverySlotId(String deliverySlot) {
    // Normalize the delivery slot string
    final normalizedSlot = deliverySlot.toLowerCase().trim();
    
    // Map delivery slots to IDs - update these based on your API requirements
    if (normalizedSlot.contains('9:00') && normalizedSlot.contains('10:00')) {
      return 1; // 9:00 AM - 10:00 PM (Full Day)
    } else if (normalizedSlot.contains('9:00') && normalizedSlot.contains('1:00')) {
      return 2; // 9:00 AM - 1:00 PM (Morning)
    } else if (normalizedSlot.contains('1:00') && normalizedSlot.contains('6:00')) {
      return 3; // 1:00 PM - 6:00 PM (Afternoon)
    } else if (normalizedSlot.contains('6:00') && normalizedSlot.contains('10:00')) {
      return 4; // 6:00 PM - 10:00 PM (Evening)
    }
    
    // Default fallback
    _logger.warning('Unknown delivery slot format: $deliverySlot, using default ID: 1');
    return 1;
  }

  // ENHANCED: Helper method to get payment mode ID with comprehensive mapping
  int _getPaymentModeId(String paymentMode) {
    // Normalize the payment mode string
    final normalizedMode = paymentMode.toLowerCase().trim();
    
    // Map payment mode to ID
    if (normalizedMode.contains('online') || normalizedMode.contains('card') || 
        normalizedMode.contains('upi') || normalizedMode.contains('net banking')) {
      return 2; // Online Payment
    } else if (normalizedMode.contains('cash') || normalizedMode.contains('cod') || 
               normalizedMode.contains('delivery')) {
      return 1; // Cash on Delivery
    } else if (normalizedMode.contains('wallet')) {
      return 3; // Wallet Payment
    }
    
    // Default fallback to COD
    _logger.warning('Unknown payment mode format: $paymentMode, using default ID: 1 (COD)');
    return 1;
  }

  // UTILITY: Validate request data before sending
  bool _validateRequestData({
    required String tempOrderId,
    required String storeCode,
    required List<CartItem> cartItems,
    required Address deliveryAddress,
    String? accessKey,
    String? mobileNo,
  }) {
    final errors = <String>[];
    
    if (tempOrderId.isEmpty) errors.add('Temp Order ID is empty');
    if (storeCode.isEmpty) errors.add('Store Code is empty');
    if (cartItems.isEmpty) errors.add('Cart items are empty');
    if (deliveryAddress.fullName.isEmpty) errors.add('Delivery address name is empty');
    if (accessKey == null || accessKey.isEmpty) errors.add('Access key is missing');
    if (mobileNo == null || mobileNo.isEmpty) errors.add('Mobile number is missing');
    
    if (errors.isNotEmpty) {
      _logger.error('Request validation failed: ${errors.join(', ')}');
      return false;
    }
    
    return true;
  }
}