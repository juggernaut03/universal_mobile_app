// lib/data/services/payment_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../core/constants/app_constants.dart';

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;
  final Object? error;
  
  // Enhanced payment data from Razorpay
  final Map<String, dynamic>? fullPaymentData;
  final String? razorpayOrderId;
  final double? amount;
  final String? currency;
  final String? status;
  final String? method;
  final bool? captured;
  final String? vpa;
  final String? email;
  final String? contact;
  final Map<String, dynamic>? acquirerData;
  final Map<String, dynamic>? upiData;
  final int? createdAt;
  final int? capturedAt;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
    this.error,
    this.fullPaymentData,
    this.razorpayOrderId,
    this.amount,
    this.currency,
    this.status,
    this.method,
    this.captured,
    this.vpa,
    this.email,
    this.contact,
    this.acquirerData,
    this.upiData,
    this.createdAt,
    this.capturedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'payment_id': paymentId,
      'order_id': orderId,
      'signature': signature,
      'message': message,
      'full_payment_data': fullPaymentData,
      'razorpay_order_id': razorpayOrderId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'method': method,
      'captured': captured,
      'vpa': vpa,
      'email': email,
      'contact': contact,
      'acquirer_data': acquirerData,
      'upi_data': upiData,
      'created_at': createdAt,
      'captured_at': capturedAt,
    };
  }
}

class PaymentService {
  final Logger _logger;
  late Razorpay _razorpay;
  Completer<PaymentResult>? _paymentCompleter;

  // Store payment context for enhanced data collection
  double? _currentPaymentAmount;
  String? _currentCustomerEmail;
  String? _currentCustomerPhone;
  String? _currentCustomerName;
  String? _currentDescription;
  String? _currentRazorpayOrderId; // Store the created order ID
  String? _currentTempOrderId; // Store the temp order ID for tracking

  // Razorpay API credentials - LIVE KEYS
  static const String keyId = ApiConstants.razorpayKeyId;
  static const String keySecret = ApiConstants.razorpayKeySecret;

  PaymentService({Logger? logger}) : _logger = logger ?? Logger() {
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _setupListeners();
    _logger.log('Razorpay instance initialized with LIVE keys');
  }

  void _setupListeners() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Create a Razorpay order using their Orders API with temp order ID tracking
  Future<Map<String, dynamic>?> _createRazorpayOrder({
    required double amount,
    required String currency,
    String? receipt,
    String? tempOrderId,
  }) async {
    try {
      _logger.log('Creating Razorpay order for amount: ${amount.toStringAsFixed(2)} $currency');
      _logger.log('Temp Order ID: ${tempOrderId ?? "Not provided"}');
      
      final orderData = {
        'amount': (amount * 100).toInt(), // Amount in paise
        'currency': currency,
        'receipt': receipt ?? tempOrderId ?? 'order_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'customer_name': _currentCustomerName,
          'customer_email': _currentCustomerEmail,
          'customer_phone': _currentCustomerPhone,
          'description': _currentDescription,
          'app_platform': 'flutter',
          
          // CRITICAL: Include temp order ID for tracking
          'temp_order_id': tempOrderId ?? 'unknown',
         
          'flutter_timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          
          // Additional tracking info
          'payment_initiated_at': DateTime.now().toIso8601String(),
          'app_version': 'flutter_live',
          'environment': 'live',
        }
      };

      print('\n🏦 === CREATING RAZORPAY ORDER === 🏦');
      print('Amount: ₹${amount.toStringAsFixed(2)} (${(amount * 100).toInt()} paise)');
      print('Currency: $currency');
      print('Receipt: ${orderData['receipt']}');
      print('Customer: $_currentCustomerName');
      print('Temp Order ID: ${tempOrderId ?? "Not provided"}');
      print('🏦 === CALLING RAZORPAY API === 🏦\n');

      // Make API call to Razorpay Orders API
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$keyId:$keySecret'))}',
        },
        body: jsonEncode(orderData),
      );

      _logger.log('Razorpay order creation response status: ${response.statusCode}');
      _logger.log('Razorpay order creation response: ${response.body}');

      print('\n📋 === RAZORPAY ORDER RESPONSE === 📋');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('📋 === END RESPONSE === 📋\n');

      if (response.statusCode == 200) {
        final orderResponse = jsonDecode(response.body);
        _currentRazorpayOrderId = orderResponse['id'];
        
        print('\n✅ === ORDER CREATED SUCCESSFULLY === ✅');
        print('Razorpay Order ID: ${orderResponse['id']}');
        print('Amount: ${orderResponse['amount']} paise');
        print('Currency: ${orderResponse['currency']}');
        print('Status: ${orderResponse['status']}');
        print('Receipt: ${orderResponse['receipt']}');
        print('Temp Order ID in Notes: ${tempOrderId ?? "Not provided"}');
        print('✅ === END SUCCESS === ✅\n');
        
        return orderResponse;
      } else {
        _logger.error('Failed to create Razorpay order: ${response.statusCode} - ${response.body}');
        print('\n❌ === ORDER CREATION FAILED === ❌');
        print('Status: ${response.statusCode}');
        print('Error: ${response.body}');
        print('❌ === END FAILURE === ❌\n');
        return null;
      }
    } catch (e) {
      _logger.error('Error creating Razorpay order: $e');
      print('\n💥 === ORDER CREATION ERROR === 💥');
      print('Error: $e');
      print('💥 === END ERROR === 💥\n');
      return null;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _logger.log('Payment successful: ${response.paymentId}');
    
    print('\n💳 === RAZORPAY PAYMENT SUCCESS === 💳');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');
    print('Signature: ${response.signature}');
    print('💳 === PROCESSING SUCCESS === 💳\n');
    
    // Enhanced payment data with real Razorpay response + temp order ID
    final now = DateTime.now();
    final currentTimestamp = now.millisecondsSinceEpoch ~/ 1000;
    final amountInPaise = _currentPaymentAmount != null ? (_currentPaymentAmount! * 100).toInt() : null;
    
    // Create enhanced payment data structure with actual Razorpay data + temp order ID
    final enhancedPaymentData = {
      "id": response.paymentId,
      "entity": "payment",
      "amount": amountInPaise,
      "amount_captured": amountInPaise,
      "currency": "INR",
      "status": "captured",
      "order_id": response.orderId, // This will now have the actual Razorpay order ID
      "invoice_id": null,
      "international": false,
      "method": "upi", // Will be updated based on actual payment method
      "amount_refunded": 0,
      "refund_status": null,
      "captured": true,
      "description": _currentDescription ?? "Order Payment - PatelMart",
      "card_id": null,
      "bank": null,
      "wallet": null,
      "vpa": null, // Will be filled by webhook if UPI
      "email": _currentCustomerEmail ?? "orders@patelrmart.com",
      "contact": _currentCustomerPhone,
      "notes": {
        "customer_name": _currentCustomerName,
        "app_platform": "flutter",
        "transaction_source": "mobile_app",
        "razorpay_order_id": _currentRazorpayOrderId,
        "temp_order_id": _currentTempOrderId , // INCLUDE: Temp order ID
        "database_status": "payment_processing", // Status before payment
        "payment_flow_stage": "payment_completed",
      },
      "fee": 0,
      "tax": 0,
      "error_code": null,
      "error_description": null,
      "error_source": null,
      "error_step": null,
      "error_reason": null,
      "acquirer_data": {
        "rrn": null, // Will be updated by webhook
        "upi_transaction_id": null // Will be updated by webhook
      },
      "created_at": currentTimestamp,
      "provider": null,
      "upi": {
        "payer_account_type": null,
        "vpa": null // Will be filled by webhook if UPI
      },
      "reward": null,
      "authorized_at": currentTimestamp,
      "auto_captured": true,
      "captured_at": currentTimestamp,
      "late_authorized": false,
      
      // Additional metadata with temp order ID
      "flutter_sdk_response": {
        "payment_id": response.paymentId,
        "order_id": response.orderId,
        "signature": response.signature,
        "success_timestamp": now.millisecondsSinceEpoch,
        "created_razorpay_order_id": _currentRazorpayOrderId,
        "temp_order_id": _currentTempOrderId ?? "unknown", // INCLUDE: Temp order ID
      },
      "app_context": {
        "platform": "flutter",
        "payment_amount": _currentPaymentAmount,
        "customer_email": _currentCustomerEmail,
        "customer_phone": _currentCustomerPhone,
        "customer_name": _currentCustomerName,
        "description": _currentDescription,
        "test_mode": false, // Since using live keys
        "sdk_version": "razorpay_flutter",
        "environment": "live", // Correct environment
        "temp_order_id": _currentTempOrderId ?? "unknown", // INCLUDE: Temp order ID
        "database_reference": _currentTempOrderId,
      }
    };
    
    print('\n📊 === COMPLETE PAYMENT DATA === 📊');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');
    print('Signature: ${response.signature}');
    print('Amount: ₹${_currentPaymentAmount?.toStringAsFixed(2)}');
    print('Customer: $_currentCustomerName ($_currentCustomerPhone)');
    print('Email: $_currentCustomerEmail');
    print('Created Razorpay Order ID: $_currentRazorpayOrderId');
    print('Temp Order ID: ${_currentTempOrderId ?? "Not available"}');
    print('Environment: LIVE');
    print('Status: Payment Successful → Ready for Database Update');
    print('📊 === END PAYMENT DATA === 📊\n');
    
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: true,
        paymentId: response.paymentId,
        orderId: response.orderId,
        signature: response.signature,
        fullPaymentData: enhancedPaymentData,
        razorpayOrderId: response.orderId,
        amount: _currentPaymentAmount,
        currency: "INR",
        status: "captured",
        method: "upi", // Default assumption
        captured: true,
        vpa: null,
        email: _currentCustomerEmail,
        contact: _currentCustomerPhone,
        acquirerData: enhancedPaymentData["acquirer_data"] as Map<String, dynamic>?,
        upiData: enhancedPaymentData["upi"] as Map<String, dynamic>?,
        createdAt: currentTimestamp,
        capturedAt: currentTimestamp,
      ));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _logger.error('Payment error: ${response.code} - ${response.message}');
    
    print('\n❌ === PAYMENT ERROR === ❌');
    print('Error Code: ${response.code}');
    print('Error Message: ${response.message}');
    print('Temp Order ID: ${_currentTempOrderId ?? "Not available"}');
    print('❌ === END ERROR === ❌\n');
    
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: false,
        message: 'Payment failed: ${response.message}',
        error: Exception('Payment error: ${response.code}'),
        fullPaymentData: {
          'error_code': response.code,
          'error_message': response.message,
          'error_timestamp': DateTime.now().millisecondsSinceEpoch,
          'payment_amount': _currentPaymentAmount,
          'customer_info': {
            'name': _currentCustomerName,
            'email': _currentCustomerEmail,
            'phone': _currentCustomerPhone,
          },
          'environment': 'live',
          'temp_order_id': _currentTempOrderId ?? 'unknown', // INCLUDE: Temp order ID
          'database_status': 'payment_processing', // Status before payment failure
          'payment_flow_stage': 'payment_failed',
        },
      ));
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _logger.log('External wallet selected: ${response.walletName}');
    
    print('\n🔄 === EXTERNAL WALLET === 🔄');
    print('Wallet: ${response.walletName}');
    print('Temp Order ID: ${_currentTempOrderId ?? "Not available"}');
    print('🔄 === END WALLET === 🔄\n');
    
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: false,
        message: 'External wallet selected: ${response.walletName}',
        fullPaymentData: {
          'wallet_name': response.walletName,
          'external_wallet_timestamp': DateTime.now().millisecondsSinceEpoch,
          'payment_amount': _currentPaymentAmount,
          'customer_info': {
            'name': _currentCustomerName,
            'email': _currentCustomerEmail,
            'phone': _currentCustomerPhone,
          },
          'environment': 'live',
          'temp_order_id': _currentTempOrderId ?? 'unknown',
          'database_status': 'payment_processing',
          'payment_flow_stage': 'external_wallet_selected',
        },
      ));
    }
  }

  /// Start a payment process with Razorpay (with order creation and temp order ID tracking)
  /// UPDATED: Include tempOrderId parameter and pass it throughout the flow
  Future<PaymentResult> startPayment({
    required double amount, 
    required String description,
    required String customerName,
    String? customerEmail,
    String? customerPhone,
    String? customOrderId, // Optional custom order ID (can be temp order ID)
    String? tempOrderId, // EXPLICIT: Add temp order ID parameter
  }) async {
    try {
      // Use tempOrderId if provided, otherwise fall back to customOrderId
      final orderIdToUse = tempOrderId ?? customOrderId;
      
      _logger.log('Starting Razorpay payment for amount: ${amount.toStringAsFixed(2)}');
      _logger.log('Temp Order ID: ${orderIdToUse ?? "Not provided"}');
      
      // Store payment context including temp order ID
      _currentPaymentAmount = amount;
      _currentCustomerEmail = customerEmail;
      _currentCustomerPhone = customerPhone;
      _currentCustomerName = customerName;
      _currentDescription = description;
      _currentTempOrderId = orderIdToUse; // STORE: Temp order ID for tracking
      
      print('\n🚀 === STARTING PAYMENT PROCESS === 🚀');
      print('Amount: ₹${amount.toStringAsFixed(2)}');
      print('Customer: $customerName');
      print('Phone: ${customerPhone ?? "Not provided"}');
      print('Email: ${customerEmail ?? "Not provided"}');
      print('Description: $description');
      print('Temp Order ID: ${orderIdToUse ?? "Not provided"}');
      print('Environment: LIVE');
      print('🚀 === STEP 1: CREATE ORDER === 🚀\n');
      
      // Create a new completer for this payment attempt
      _paymentCompleter = Completer<PaymentResult>();
      
      // STEP 1: Create Razorpay order first - PASS THE TEMP ORDER ID
      final razorpayOrder = await _createRazorpayOrder(
        amount: amount,
        currency: 'INR',
        receipt: orderIdToUse ?? 'order_${DateTime.now().millisecondsSinceEpoch}',
        tempOrderId: orderIdToUse, // CRITICAL: Pass temp order ID
      );
      
      if (razorpayOrder == null) {
        // Order creation failed
        if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
          _paymentCompleter!.complete(PaymentResult(
            success: false,
            message: 'Failed to create payment order. Please try again.',
            error: Exception('Razorpay order creation failed'),
            fullPaymentData: {
              'order_creation_failed': true,
              'failure_timestamp': DateTime.now().millisecondsSinceEpoch,
              'payment_amount': _currentPaymentAmount,
              'temp_order_id': orderIdToUse,
              'environment': 'live',
            },
          ));
        }
        
        return PaymentResult(
          success: false,
          message: 'Failed to create payment order. Please try again.',
          error: Exception('Razorpay order creation failed'),
        );
      }
      
      print('\n🚀 === STEP 2: OPEN CHECKOUT === 🚀');
      print('Razorpay Order ID: ${razorpayOrder['id']}');
      print('Temp Order ID: ${orderIdToUse ?? "Not provided"}');
      print('Opening payment gateway...');
      print('🚀 === CHECKOUT OPENING === 🚀\n');
      
      // STEP 2: Create the payment options with the created order ID
      // Validate and prepare customer data for Razorpay
      final validatedPhone = (customerPhone?.isNotEmpty == true)
          ? customerPhone
          : '9999999999'; // Fallback phone for payment gateway
      final validatedEmail = (customerEmail?.isNotEmpty == true)
          ? customerEmail
          : 'orders@patelrmart.com';
      final validatedName = (customerName.isNotEmpty)
          ? customerName
          : 'Customer';

      final options = {
        'key': keyId,
        'amount': razorpayOrder['amount'], // Use amount from created order
        'currency': razorpayOrder['currency'],
        'name': 'PatelMart',
        'description': description,
        'order_id': razorpayOrder['id'], // CRITICAL: Use the created order ID
        'prefill': {
          'name': validatedName,
          'email': validatedEmail,
          'contact': validatedPhone,
        },
        'external': {
          'wallets': ['paytm']
        },
        'theme': {
          'color': '#3399cc'
        },
        'notes': {
          'customer_name': customerName,
          'app_platform': 'flutter',
          'environment': 'live',
          'temp_order_id': orderIdToUse ?? 'unknown', // INCLUDE: Temp order ID in checkout notes
          'database_status': 'payment_processing',
        }
      };
      
      _logger.log('Opening Razorpay checkout with order ID: ${razorpayOrder['id']}');
      _logger.log('Temp Order ID in checkout: ${orderIdToUse}');
      _logger.log('Payment options: ${jsonEncode(options)}');
      
      // STEP 3: Open the Razorpay checkout
      _razorpay.open(options);
      
      // Wait for the payment result
      final paymentResult = await _paymentCompleter!.future;
      
      _logger.log('Payment process completed. Success: ${paymentResult.success}');
      _logger.log('Temp Order ID: ${orderIdToUse}');
      
      return paymentResult;
    } catch (e) {
      _logger.error('Error starting Razorpay payment: $e');
      
      print('\n❌ === PAYMENT PROCESS ERROR === ❌');
      print('Error: $e');
      print('Temp Order ID: ${tempOrderId ?? customOrderId}');
      print('❌ === END ERROR === ❌\n');
      
      if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
        _paymentCompleter!.complete(PaymentResult(
          success: false,
          message: 'Failed to start payment process: ${e.toString()}',
          error: e,
          fullPaymentData: {
            'init_error': e.toString(),
            'init_error_timestamp': DateTime.now().millisecondsSinceEpoch,
            'payment_amount': _currentPaymentAmount,
            'temp_order_id': tempOrderId ?? customOrderId,
            'environment': 'live',
          },
        ));
      }
      
      return PaymentResult(
        success: false,
        message: 'Failed to start payment process: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Get the current temp order ID being processed
  String? getCurrentTempOrderId() {
    return _currentTempOrderId;
  }

  /// Clear the current payment context (useful for cleanup)
  void clearPaymentContext() {
    _currentPaymentAmount = null;
    _currentCustomerEmail = null;
    _currentCustomerPhone = null;
    _currentCustomerName = null;
    _currentDescription = null;
    _currentRazorpayOrderId = null;
    _currentTempOrderId = null;
    
    _logger.log('Payment context cleared');
  }

  /// Get current payment context for debugging
  Map<String, dynamic> getCurrentPaymentContext() {
    return {
      'payment_amount': _currentPaymentAmount,
      'customer_email': _currentCustomerEmail,
      'customer_phone': _currentCustomerPhone,
      'customer_name': _currentCustomerName,
      'description': _currentDescription,
      'razorpay_order_id': _currentRazorpayOrderId,
      'temp_order_id': _currentTempOrderId,
      'environment': 'live',
    };
  }

  void dispose() {
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: false,
        message: 'Payment cancelled due to service disposal',
        fullPaymentData: {
          'disposal_reason': 'Service disposed',
          'disposal_timestamp': DateTime.now().millisecondsSinceEpoch,
          'environment': 'live',
          'temp_order_id': _currentTempOrderId,
        },
      ));
    }
    
    // Clear payment context on disposal
    clearPaymentContext();
    
    _razorpay.clear();
    _logger.log('Razorpay instance disposed');
  }
}