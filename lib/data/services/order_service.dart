// lib/data/services/order_service.dart
// Updated with payment failure handling while keeping existing code intact

import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Added for Platform detection
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
  final String? tempOrderId;
  final Map<String, dynamic>? data;
  final Object? error;

  OrderConfirmationResponse({
    required this.success,
    required this.message,
    this.orderId,
    this.tempOrderId,
    this.data,
    this.error,
  });

  @override
  String toString() {
    return 'OrderConfirmationResponse(success: $success, message: $message, orderId: $orderId, tempOrderId: $tempOrderId)';
  }
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

  // Helper method to detect current platform
  String _getPlatform() {
    if (Platform.isIOS) {
      return "iOS";
    } else if (Platform.isAndroid) {
      return "Android";
    } else if (Platform.isWindows) {
      return "Windows";
    } else if (Platform.isMacOS) {
      return "MacOS";
    } else if (Platform.isLinux) {
      return "Linux";
    } else {
      return "Unknown";
    }
  }

  // ENHANCED: confirmOrder method with payment failure handling added
  Future<OrderConfirmationResponse> confirmOrder({
    required String deviceId,
    required String cartKey,
    required String tempOrderId, // Use the provided temp order ID consistently
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
    String? mobPlatform, // Now nullable - will auto-detect platform if not provided
    PaymentResult? paymentResult,
    PaymentDataFormat paymentFormat = PaymentDataFormat.both,
  }) async {
    try {
      _logger.log('=== STARTING ORDER CONFIRMATION WITH PAYMENT STATUS DETECTION ===');
      _logger.log('Preparing order confirmation request with provided temp order ID');
      
      // Use the provided temp order ID consistently
      final providedTempOrderId = tempOrderId;
      
      // Auto-detect platform if not provided
      final detectedMobPlatform = mobPlatform ?? _getPlatform();
      _logger.log('Platform: $detectedMobPlatform ${mobPlatform == null ? "(auto-detected)" : "(provided)"}');
      
      // NEW: Determine final order and payment status based on payment result
      String finalOrderStatus;
      String finalPaymentStatus;
      int finalPaymentStatusId;
      String finalPaidAmount;
      String finalTransactionId;
      
      if (paymentMode.toLowerCase() == "online payment") {
        if (paymentResult != null && paymentResult.success) {
          // Online payment successful
          finalOrderStatus = "Order Confirmed";
          finalPaymentStatus = "Payment Confirmed";
          finalPaymentStatusId = 2; // Success status ID
          finalPaidAmount = finalPayableAmount.toString();
          finalTransactionId = transactionId ?? paymentResult.paymentId ?? "";
          
          _logger.log('✅ Online Payment Successful - Order will be confirmed');
        } else {
          // Online payment failed
          finalOrderStatus = "Payment Failed";
          finalPaymentStatus = "Payment Failed";
          finalPaymentStatusId = 3; // Failed status ID
          finalPaidAmount = "0";
          finalTransactionId = transactionId ?? paymentResult?.paymentId ?? "";
          
          _logger.log('❌ Online Payment Failed - Order will be marked as failed');
          _logger.log('Payment Error: ${paymentResult?.message ?? "Unknown error"}');
        }
      } else {
        // Cash on Delivery
        finalOrderStatus = "Order Confirmed";
        finalPaymentStatus = "Pending";
        finalPaymentStatusId = 1; // Pending status ID
        finalPaidAmount = "0";
        finalTransactionId = "";
        
        _logger.log('💰 Cash on Delivery - Order confirmed with pending payment');
      }
      
      // Validate required parameters
      if (providedTempOrderId.isEmpty) {
        throw Exception('Temp Order ID cannot be empty');
      }
      
      if (cartItems.isEmpty) {
        throw Exception('Cart items cannot be empty');
      }
      
      if (deviceId.isEmpty || cartKey.isEmpty || storeCode.isEmpty) {
        throw Exception('Required identifiers (deviceId, cartKey, storeCode) cannot be empty');
      }
      
      // Create order_date_time in the required format (ISO 8601)
      final orderDateTime = DateTime.now().toUtc().toIso8601String();
      
      // Enhanced console output for order preparation
      print('\n📋 === PREPARING ORDER CONFIRMATION WITH STATUS DETECTION === 📋');
      print('Using Provided Temp Order ID: $providedTempOrderId');
      print('Store Code: $storeCode');
      print('Device ID: $deviceId');
      print('Cart Key: $cartKey');
      print('Cart Items: ${cartItems.length}');
      print('Payment Mode: $paymentMode');
      print('Final Amount: ₹${finalPayableAmount.toStringAsFixed(2)}');
      print('Order Date Time: $orderDateTime');
      print('Payment Result Available: ${paymentResult != null}');
      if (paymentResult != null) {
        print('Payment Success: ${paymentResult.success}');
        print('Payment ID: ${paymentResult.paymentId}');
        print('Payment Error: ${paymentResult.message ?? "None"}');
        print('Full Payment Data Available: ${paymentResult.fullPaymentData != null}');
      }
      // NEW: Status determination output
      print('');
      print('🎯 DETERMINED FINAL STATUSES:');
      print('Final Order Status: $finalOrderStatus');
      print('Final Payment Status: $finalPaymentStatus');
      print('Final Payment Status ID: $finalPaymentStatusId');
      print('Final Paid Amount: $finalPaidAmount');
      print('Final Transaction ID: $finalTransactionId');
      print('📋 === END PREPARATION === 📋\n');
      
      // Format cart items exactly as required by API
      final List<Map<String, dynamic>> formattedCartItems = cartItems.map((item) {
        return {
          "pcode": item.product.pCode,
          "product_name": item.product.productName,
          "product_mrp": item.product.productMrp,
          "selling_price": item.product.ourPrice,
          "package_size": item.product.packageSize,
          "package_unit": item.product.packageUnit,
          "stock_message": "Yes", // Default stock message
          "price_alert_message": "Yes", // Default price alert message
          "quantity": item.quantity,
          "product_image_link": item.product.pcodeImg ?? "",
        };
      }).toList();
      
      // Calculate savings correctly
      final youSave = totalMrp - totalOurPrice;
      
      // Validate financial calculations
      if (finalPayableAmount <= 0) {
        throw Exception('Final payable amount must be greater than 0');
      }
      
      // Create request body with the SAME temp order ID used throughout
      final Map<String, dynamic> requestBody = {
        "temp_order_id": providedTempOrderId, // Use provided temp order ID consistently
        "store_code": storeCode,
        "project_code": ApiConstants.projectCode, // Add project code if available
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
            "state": deliveryAddress.state ?? "",
            "landmark": deliveryAddress.landmark ?? "",
            "area_id": deliveryAddress.areaId ?? "",
            "is_default": deliveryAddress.isDefault ?? "No",
            "latitude": deliveryAddress.latitude ?? "",
            "longitude": deliveryAddress.longitude ?? "",
          }
        ],
        
        // Delivery details
        "delivery_slot": deliverySlot,
        "delivery_slot_id": _getDeliverySlotId(deliverySlot),
        "special_note": specialNotes ?? "",
        
        // Financial details (matching API format)
        "total_amount_mrp": totalMrp.toString(),
        "total_amount_our_price": totalOurPrice.toString(),
        "discount": "0",
        "handling_charges": "0", // Default handling charges
        "you_save": youSave.toString(),
        "delivery_charges": deliveryCharges.toString(),
        "discounted_amt": discountedAmount.toString(),
        "final_payable_amt": finalPayableAmount.toString(),
        
        "delivery_date": deliveryDate,
        "offer_applicable_details": offerDetails,
        "delivery_mode": deliveryMode,
        
        // NEW: Use determined final statuses instead of hardcoded values
        "order_status": finalOrderStatus,
        "payment_status": finalPaymentStatus,
        "payment_status_id": finalPaymentStatusId,
        
        // Payment details with proper handling
        "payment_mode": paymentMode,
        "payment_mode_id": _getPaymentModeId(paymentMode),
        "paid_amount": finalPaidAmount,
        "transaction_id": finalTransactionId,
        
        "mob_platform": detectedMobPlatform,
        "mobile_no": deliveryAddress.mobileNumber,
        
        // Add order_date_time in UTC ISO format
        "order_date_time": orderDateTime,
      };
      
      // NEW: Enhanced payment gateway data handling (includes failure data)
      List<Map<String, dynamic>> paymentGatewayDataArray = [];
      
      if (paymentResult != null && paymentResult.fullPaymentData != null) {
        // Create enhanced payment gateway data including failure information
        final gatewayData = {
          "gateway": "razorpay",
          "environment": "live",
          "payment_id": paymentResult.paymentId ?? "",
          "order_id": paymentResult.orderId ?? "",
          "signature": paymentResult.signature ?? "",
          "amount": paymentResult.amount ?? finalPayableAmount,
          "currency": paymentResult.currency ?? "INR",
          "status": paymentResult.status ?? (paymentResult.success ? "captured" : "failed"),
          "method": paymentResult.method ?? "unknown",
          "captured": paymentResult.captured ?? paymentResult.success,
          "vpa": paymentResult.vpa,
          "email": paymentResult.email ?? deliveryAddress.emailId,
          "contact": paymentResult.contact ?? deliveryAddress.mobileNumber,
          "created_at": paymentResult.createdAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
          "captured_at": paymentResult.capturedAt,
          "acquirer_data": paymentResult.acquirerData ?? {},
          "upi_data": paymentResult.upiData ?? {},
          "full_payment_response": paymentResult.fullPaymentData,
          "gateway_timestamp": DateTime.now().millisecondsSinceEpoch,
          "sdk_source": "flutter",
          // NEW: Payment success/failure tracking
          "payment_success": paymentResult.success,
          "payment_error_message": paymentResult.success ? null : paymentResult.message,
          "payment_error_code": paymentResult.success ? null : paymentResult.error?.toString(),
        };
        
        paymentGatewayDataArray.add(gatewayData);
        
        _logger.log('Enhanced payment gateway data prepared with failure tracking:');
        _logger.log('- Gateway: razorpay');
        _logger.log('- Payment Success: ${paymentResult.success}');
        _logger.log('- Payment ID: ${paymentResult.paymentId}');
        _logger.log('- Status: ${gatewayData["status"]}');
        if (!paymentResult.success) {
          _logger.log('- Error Message: ${paymentResult.message}');
        }
      }
      
      // ENHANCED: Add complete payment data using the flexible formatter
      if (paymentResult != null) {
        _logger.log('Adding enhanced payment data to order request using ${paymentFormat.toString()} format');
        
        print('\n💳 === ADDING PAYMENT DATA TO ORDER === 💳');
        print('Payment Format: ${paymentFormat.toString()}');
        print('Payment Success: ${paymentResult.success}');
        print('Payment ID: ${paymentResult.paymentId}');
        if (!paymentResult.success) {
          print('Payment Error: ${paymentResult.message}');
        }
        
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
        
        // NEW: Override payment_gateway_data with enhanced data if we have it
        if (paymentGatewayDataArray.isNotEmpty) {
          requestBody["payment_gateway_data"] = paymentGatewayDataArray;
        }
        
        // DEBUG: Log payment data being sent
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
          _logger.log('Error included in gateway data: Yes');
        }
        _logger.log('=====================================');
        
        print('Payment Data Fields Added: ${formattedPaymentData.keys.toList()}');
        print('Payment Gateway Data Records: ${paymentGatewayDataArray.length}');
        print('💳 === END PAYMENT DATA ADDITION === 💳\n');
      }
      
      _logger.log('Sending order confirmation with temp_order_id: $providedTempOrderId');
      _logger.log('Order date time: $orderDateTime');
      _logger.log('Final Order Status: $finalOrderStatus');
      _logger.log('Final Payment Status: $finalPaymentStatus');
      _logger.log('Request body keys: ${requestBody.keys.toList()}');
      
      // ENHANCED CONSOLE OUTPUT FOR POSTMAN DEBUGGING
      print('\n🚀 === COMPLETE ORDER POST BODY FOR POSTMAN === 🚀');
      print('URL: ${ApiConstants.baseUrl}/confirm_order');
      print('Method: POST');
      print('Headers: {"Content-Type": "application/json"}');
      print('');
      
      // NEW: Status verification output
      print('🎯 CRITICAL STATUS FIELDS BEING SENT:');
      print('─────────────────────────────────────');
      print('temp_order_id: ${requestBody["temp_order_id"]}');
      print('order_status: ${requestBody["order_status"]}');
      print('payment_status: ${requestBody["payment_status"]}');
      print('payment_status_id: ${requestBody["payment_status_id"]}');
      print('paid_amount: ${requestBody["paid_amount"]}');
      print('transaction_id: ${requestBody["transaction_id"]}');
      print('payment_mode: ${requestBody["payment_mode"]}');
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
      
      // CURL Command for testing
      print('🖥️  CURL COMMAND:');
      print('──────────────────');
      print('curl -X POST "${ApiConstants.baseUrl}/confirm_order" \\');
      print('  -H "Content-Type: application/json" \\');
      print('  -d \'${jsonEncode(requestBody)}\'');
      print('');
      
      // Request Summary
      print('📊 REQUEST SUMMARY:');
      print('─────────────────');
      print('Temp Order ID: $providedTempOrderId (CONSISTENT)');
      print('Final Order Status: $finalOrderStatus');
      print('Final Payment Status: $finalPaymentStatus');
      print('Total Fields: ${requestBody.keys.length}');
      print('Cart Items: ${cartItems.length}');
      print('Payment Data Included: ${paymentResult != null ? '✅' : '❌'}');
      print('Payment Success: ${paymentResult?.success ?? false ? '✅' : '❌'}');
      print('Order Date Time: ✅');
      print('Financial Total: ₹${finalPayableAmount.toStringAsFixed(2)}');
      print('JSON Size: ${jsonEncode(requestBody).length} characters');
      print('🚀 === END POSTMAN BODY === 🚀\n');
      
      // Legacy logging for compatibility
      _logger.log('=== COMPLETE ORDER CONFIRMATION REQUEST BODY FOR POSTMAN ===');
      _logger.log('URL: ${ApiConstants.baseUrl}/confirm_order');
      _logger.log('Method: POST');
      _logger.log('Headers: Content-Type: application/json');
      _logger.log('POST BODY: ${jsonEncode(requestBody)}');
      _logger.log('============================================================');
      
      // Make the API call with timeout
      print('\n📡 === MAKING API CALL === 📡');
      print('Sending request to: ${ApiConstants.baseUrl}/confirm_order');
      print('Temp Order ID: $providedTempOrderId');
      print('Expected Order Status: $finalOrderStatus');
      print('Expected Payment Status: $finalPaymentStatus');
      print('📡 === API CALL IN PROGRESS === 📡\n');
      
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/confirm_order'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Order confirmation request timed out after 30 seconds');
        },
      );
      
      _logger.log('Order confirmation response status: ${response.statusCode}');
      _logger.log('Order confirmation response body: ${response.body}');
      
      // ENHANCED CONSOLE OUTPUT FOR API RESPONSE
      print('\n📡 === API RESPONSE === 📡');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Time: ${DateTime.now().toIso8601String()}');
      print('');
      print('📄 Response Body:');
      print('─────────────────');
      try {
        final responseJson = jsonDecode(response.body);
        print(JsonEncoder.withIndent('  ').convert(responseJson));
        
        // NEW: Verify the status was set correctly
        print('');
        print('🔍 STATUS VERIFICATION:');
        if (responseJson.containsKey('order_status')) {
          print('✅ Database Order Status: ${responseJson['order_status']}');
        }
        if (responseJson.containsKey('payment_status')) {
          print('✅ Database Payment Status: ${responseJson['payment_status']}');
        }
        if (responseJson.containsKey('insertedItems')) {
          print('✅ Inserted Items: ${responseJson['insertedItems']}');
        }
      } catch (e) {
        print('Raw Response: ${response.body}');
        print('JSON Parse Error: $e');
      }
      print('─────────────────');
      print('📡 === END API RESPONSE === 📡\n');
      
      // Process successful response
      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          responseData = {
            'message': 'Success but unable to parse response details',
            'raw_response': response.body,
            'sent_order_status': finalOrderStatus,
            'sent_payment_status': finalPaymentStatus,
          };
        }
        
        // Extract order ID from response with multiple fallback strategies
        String? orderId;
        
        // Strategy 1: Check insertedItems array
        if (responseData['insertedItems'] != null && 
            responseData['insertedItems'] is List &&
            (responseData['insertedItems'] as List).isNotEmpty) {
          final firstInserted = (responseData['insertedItems'] as List).first;
          if (firstInserted is Map && firstInserted.containsKey('_id')) {
            orderId = firstInserted['_id']?.toString();
          }
        }
        
        // Strategy 2: Check direct _id field
        if (orderId == null && responseData.containsKey('_id')) {
          orderId = responseData['_id']?.toString();
        }
        
        // Strategy 3: Check order_id field
        if (orderId == null && responseData.containsKey('order_id')) {
          orderId = responseData['order_id']?.toString();
        }
        
        // Strategy 4: Check id field
        if (orderId == null && responseData.containsKey('id')) {
          orderId = responseData['id']?.toString();
        }
        
        // Strategy 5: Use temp order ID as fallback
        if (orderId == null) {
          orderId = providedTempOrderId;
          _logger.warning('No order ID found in response, using temp order ID as fallback');
        }
        
        // NEW: Determine success message based on final status
        String successMessage;
        if (finalOrderStatus == "Payment Failed") {
          successMessage = 'Payment failed - Order cancelled';
        } else if (finalOrderStatus == "Order Confirmed") {
          if (finalPaymentStatus == "Payment Confirmed") {
            successMessage = 'Order confirmed with successful payment';
          } else {
            successMessage = 'Order confirmed - Payment pending';
          }
        } else {
          successMessage = responseData['message'] ?? 'Order status updated';
        }
        
        // Enhanced success logging
        print('\n✅ === ORDER STATUS UPDATE SUCCESSFUL === ✅');
        print('Order ID: $orderId');
        print('Temp Order ID Used: $providedTempOrderId');
        print('Database Order Status: $finalOrderStatus');
        print('Database Payment Status: $finalPaymentStatus');
        print('Message: $successMessage');
        if (paymentResult != null && paymentResult.success) {
          print('Payment ID: ${paymentResult.paymentId}');
          print('Payment Status: Confirmed');
          print('Transaction Amount: ₹${finalPayableAmount.toStringAsFixed(2)}');
        } else if (paymentResult != null && !paymentResult.success) {
          print('Payment Failed: ${paymentResult.message}');
          print('Payment Error Logged: ✅');
        }
        print('Consistent ID Throughout Flow: ✅');
        print('API Response Status: ${response.statusCode}');
        print('Response Data Keys: ${responseData.keys.toList()}');
        print('✅ === END SUCCESS === ✅\n');
        
        _logger.log('Order placed successfully with ID: $orderId');
        _logger.log('Temp Order ID used consistently: $providedTempOrderId');
        _logger.log('Final Order Status: $finalOrderStatus');
        _logger.log('Final Payment Status: $finalPaymentStatus');
        _logger.log('Response message: $successMessage');
        
        return OrderConfirmationResponse(
          success: true,
          message: successMessage,
          orderId: orderId,
          tempOrderId: providedTempOrderId,
          data: {
            ...responseData,
            'sent_order_status': finalOrderStatus,
            'sent_payment_status': finalPaymentStatus,
            'sent_payment_status_id': finalPaymentStatusId,
          },
        );
        
      } else {
        // Handle API error responses
        String errorMessage = 'Failed to place order. Please try again.';
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
        
        print('\n❌ === ORDER FAILED === ❌');
        print('Status Code: ${response.statusCode}');
        print('Error Message: $errorMessage');
        print('Temp Order ID: $providedTempOrderId');
        print('Attempted Order Status: $finalOrderStatus');
        print('Attempted Payment Status: $finalPaymentStatus');
        print('Response Body: ${response.body}');
        print('❌ === END FAILURE === ❌\n');
        
        _logger.error('Order confirmation failed: ${response.statusCode} - $errorMessage');
        _logger.error('Response body: ${response.body}');
        
        return OrderConfirmationResponse(
          success: false,
          message: errorMessage,
          tempOrderId: providedTempOrderId,
          error: Exception('API Error: ${response.statusCode} - $errorMessage'),
          data: errorData,
        );
      }
      
    } catch (e) {
      // Handle exceptions
      String errorMessage = 'An error occurred while placing your order';
      
      if (e is TimeoutException) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid data format. Please try again.';
      } else {
        errorMessage = 'An error occurred: ${e.toString()}';
      }
      
      print('\n💥 === ORDER ERROR === 💥');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $errorMessage');
      print('Temp Order ID: $tempOrderId');
      print('Stack Trace Available: ${StackTrace.current.toString().isNotEmpty}');
      print('💥 === END ERROR === 💥\n');
      
      _logger.error('Error during order confirmation: $e');
      _logger.error('Error type: ${e.runtimeType}');
      
      return OrderConfirmationResponse(
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
    
    // Map delivery slot text to ID based on common patterns
    if (normalizedSlot.contains('9:00') && normalizedSlot.contains('10:00')) {
      return 1; // 9:00 AM - 10:00 PM (Full Day)
    } else if (normalizedSlot.contains('9:00') && normalizedSlot.contains('1:00')) {
      return 2; // 9:00 AM - 1:00 PM (Morning)
    } else if (normalizedSlot.contains('1:00') && normalizedSlot.contains('6:00')) {
      return 3; // 1:00 PM - 6:00 PM (Afternoon)
    } else if (normalizedSlot.contains('6:00') && normalizedSlot.contains('10:00')) {
      return 4; // 6:00 PM - 10:00 PM (Evening)
    } else if (normalizedSlot.contains('11:00') && normalizedSlot.contains('12:00')) {
      return 5; // 11:00 AM - 12:00 PM
    } else if (normalizedSlot.contains('12:00') && normalizedSlot.contains('01:00')) {
      return 6; // 12:00 PM - 01:00 PM
    } else if (normalizedSlot.contains('01:00') && normalizedSlot.contains('02:00')) {
      return 7; // 01:00 PM - 02:00 PM
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
    if (normalizedMode.contains('pod') || normalizedMode.contains('cash')) {
      return 1; // Cash on Delivery / Pay on Delivery
    } else if (normalizedMode.contains('online') || normalizedMode.contains('card') || 
               normalizedMode.contains('upi') || normalizedMode.contains('net banking')) {
      return 2; // Online Payment
    } else if (normalizedMode.contains('wallet')) {
      return 3; // Wallet Payment
    } else if (normalizedMode.contains('emi')) {
      return 4; // EMI Payment
    }
    
    // Default fallback to COD
    _logger.warning('Unknown payment mode format: $paymentMode, using default ID: 1 (COD)');
    return 1;
  }

  // UTILITY: Helper method for backward compatibility - converts Map to Address
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
    String? mobPlatform, // Now nullable - will auto-detect platform if not provided
    PaymentResult? paymentResult,
    PaymentDataFormat paymentFormat = PaymentDataFormat.both,
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
      paymentResult: paymentResult,
      paymentFormat: paymentFormat,
    );
  }

  // UTILITY: Create order summary for logging/debugging
  Map<String, dynamic> createOrderSummary({
    required String tempOrderId,
    required List<CartItem> cartItems,
    required double finalPayableAmount,
    required String paymentMode,
    String? transactionId,
  }) {
    return {
      'temp_order_id': tempOrderId,
      'total_items': cartItems.length,
      'total_quantity': cartItems.fold(0, (sum, item) => sum + item.quantity),
      'final_amount': finalPayableAmount,
      'payment_mode': paymentMode,
      'transaction_id': transactionId,
      'has_payment_data': transactionId != null && transactionId.isNotEmpty,
      'items_summary': cartItems.map((item) => {
        'pcode': item.product.pCode,
        'name': item.product.productName,
        'quantity': item.quantity,
        'price': item.product.ourPrice,
        'total': item.totalPrice,
      }).toList(),
    };
  }

  // UTILITY: Validate order data before sending
  bool validateOrderData({
    required String tempOrderId,
    required String deviceId,
    required String cartKey,
    required String storeCode,
    required List<CartItem> cartItems,
    required Address deliveryAddress,
    required double finalPayableAmount,
  }) {
    // Check required string fields
    if (tempOrderId.isEmpty || deviceId.isEmpty || cartKey.isEmpty || storeCode.isEmpty) {
      _logger.error('Validation failed: Required identifier fields are empty');
      return false;
    }
    
    // Check cart items
    if (cartItems.isEmpty) {
      _logger.error('Validation failed: Cart is empty');
      return false;
    }
    
    // Check delivery address
    if (deliveryAddress.fullName.isEmpty || deliveryAddress.mobileNumber.isEmpty) {
      _logger.error('Validation failed: Delivery address is incomplete');
      return false;
    }
    
    // Check amount
    if (finalPayableAmount <= 0) {
      _logger.error('Validation failed: Final payable amount must be greater than 0');
      return false;
    }
    
    _logger.log('Order data validation passed');
    return true;
  }
}