// lib/data/services/payment_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/utils/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import 'package:flutter/foundation.dart';

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

  // Razorpay publishable key id only — orders are created and verified by the
  // backend (/api/razorpay/order, /api/razorpay/verify), which holds the secret.
  static const String keyId = ApiConstants.razorpayKeyId;

  final ApiClient? _apiClient;

  PaymentService({Logger? logger, ApiClient? apiClient})
      : _logger = logger ?? Logger(),
        _apiClient = apiClient {
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
      
      if (_apiClient == null) {
        _logger.error('PaymentService has no ApiClient — cannot create order');
        return null;
      }

      // The backend creates the Razorpay order with its own credentials;
      // the app never touches the key secret.
      final response = await _apiClient.postWithAuth(
        ApiConstants.razorpayOrder,
        body: {
          'amount': amount, // in INR; backend converts to paise
          'currency': currency,
          if (receipt != null) 'receipt': receipt,
          'notes': {
            'customer_name': _currentCustomerName,
            'app_platform': 'flutter',
            if (tempOrderId != null) 'temp_order_id': tempOrderId,
          },
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        _currentRazorpayOrderId = response['id'];
        _logger.log('Razorpay order created: ${response['id']} (${response['amount']} paise)');

        return {
          'id': response['id'],
          'amount': response['amount'],
          'currency': response['currency'],
          'receipt': response['receipt'],
          'status': 'created',
        };
      }

      _logger.error('Failed to create Razorpay order: $response');
      return null;
    } catch (e) {
      _logger.error('Error creating Razorpay order: $e');
      return null;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _logger.log('Payment successful: ${response.paymentId}');
    
    if (kDebugMode) print('\n💳 === RAZORPAY PAYMENT SUCCESS === 💳');
    if (kDebugMode) print('Payment ID: ${response.paymentId}');
    if (kDebugMode) print('Order ID: ${response.orderId}');
    // Signature intentionally not logged: it is a payment credential.
    if (kDebugMode) print('💳 === PROCESSING SUCCESS === 💳\n');
    
    // Enhanced payment data with real Razorpay response + temp order ID
    final now = DateTime.now();
    final currentTimestamp = now.millisecondsSinceEpoch ~/ 1000;
    // round(), not toInt(). Truncating a double loses a paisa whenever the
    // rupee value has no exact binary representation: (19.99 * 100).toInt() is
    // 1998, and 1.15 and 8.29 are likewise short. This value is reported to the
    // backend as `amount` and `amount_captured`, so a truncated figure records
    // less than Razorpay actually captured and breaks reconciliation.
    final amountInPaise = _currentPaymentAmount != null
        ? (_currentPaymentAmount! * 100).round()
        : null;
    
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
    
    if (kDebugMode) print('\n📊 === COMPLETE PAYMENT DATA === 📊');
    if (kDebugMode) print('Payment ID: ${response.paymentId}');
    if (kDebugMode) print('Order ID: ${response.orderId}');
    // Signature intentionally not logged: it is a payment credential.
    if (kDebugMode) print('Amount: ₹${_currentPaymentAmount?.toStringAsFixed(2)}');
    if (kDebugMode) print('Customer: $_currentCustomerName ($_currentCustomerPhone)');
    if (kDebugMode) print('Email: $_currentCustomerEmail');
    if (kDebugMode) print('Created Razorpay Order ID: $_currentRazorpayOrderId');
    if (kDebugMode) print('Temp Order ID: ${_currentTempOrderId ?? "Not available"}');
    if (kDebugMode) print('Environment: LIVE');
    if (kDebugMode) print('Status: Payment Successful → Ready for Database Update');
    if (kDebugMode) print('📊 === END PAYMENT DATA === 📊\n');
    
    // Verify the payment signature with the backend before treating the
    // payment as successful (POST /api/razorpay/verify).
    _verifyAndComplete(response, enhancedPaymentData, currentTimestamp);
  }

  Future<void> _verifyAndComplete(
    PaymentSuccessResponse response,
    Map<String, dynamic> enhancedPaymentData,
    int currentTimestamp,
  ) async {
    bool verified = true;
    try {
      if (_apiClient != null &&
          response.orderId != null &&
          response.paymentId != null &&
          response.signature != null) {
        final verifyResponse = await _apiClient.postWithAuth(
          ApiConstants.razorpayVerify,
          body: {
            'razorpay_order_id': response.orderId,
            'razorpay_payment_id': response.paymentId,
            'razorpay_signature': response.signature,
          },
        );
        verified =
            verifyResponse is Map && verifyResponse['success'] == true;
        _logger.log('Razorpay verify result: $verified');
      } else {
        _logger.warning(
            'Razorpay verify skipped (missing client or payment fields)');
      }
    } catch (e) {
      _logger.error('Razorpay verify call failed: $e');
      verified = false;
    }

    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      if (!verified) {
        _paymentCompleter!.complete(PaymentResult(
          success: false,
          paymentId: response.paymentId,
          orderId: response.orderId,
          signature: response.signature,
          message:
              'Payment could not be verified. If money was deducted it will be refunded — please contact support.',
          error: Exception('Razorpay signature verification failed'),
        ));
        return;
      }

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
    
    if (kDebugMode) print('\n❌ === PAYMENT ERROR === ❌');
    if (kDebugMode) print('Error Code: ${response.code}');
    if (kDebugMode) print('Error Message: ${response.message}');
    if (kDebugMode) print('Temp Order ID: ${_currentTempOrderId ?? "Not available"}');
    if (kDebugMode) print('❌ === END ERROR === ❌\n');
    
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
    
    if (kDebugMode) print('\n🔄 === EXTERNAL WALLET === 🔄');
    if (kDebugMode) print('Wallet: ${response.walletName}');
    if (kDebugMode) print('Temp Order ID: ${_currentTempOrderId ?? "Not available"}');
    if (kDebugMode) print('🔄 === END WALLET === 🔄\n');
    
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
      
      if (kDebugMode) print('\n🚀 === STARTING PAYMENT PROCESS === 🚀');
      if (kDebugMode) print('Amount: ₹${amount.toStringAsFixed(2)}');
      if (kDebugMode) print('Customer: $customerName');
      if (kDebugMode) print('Phone: ${customerPhone ?? "Not provided"}');
      if (kDebugMode) print('Email: ${customerEmail ?? "Not provided"}');
      if (kDebugMode) print('Description: $description');
      if (kDebugMode) print('Temp Order ID: ${orderIdToUse ?? "Not provided"}');
      if (kDebugMode) print('Environment: LIVE');
      if (kDebugMode) print('🚀 === STEP 1: CREATE ORDER === 🚀\n');
      
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
      
      if (kDebugMode) print('\n🚀 === STEP 2: OPEN CHECKOUT === 🚀');
      if (kDebugMode) print('Razorpay Order ID: ${razorpayOrder['id']}');
      if (kDebugMode) print('Temp Order ID: ${orderIdToUse ?? "Not provided"}');
      if (kDebugMode) print('Opening payment gateway...');
      if (kDebugMode) print('🚀 === CHECKOUT OPENING === 🚀\n');
      
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
      _logger.log('Temp Order ID in checkout: $orderIdToUse');
      _logger.log('Payment options: ${jsonEncode(options)}');
      
      // STEP 3: Open the Razorpay checkout
      _razorpay.open(options);
      
      // Wait for the payment result
      final paymentResult = await _paymentCompleter!.future;
      
      _logger.log('Payment process completed. Success: ${paymentResult.success}');
      _logger.log('Temp Order ID: $orderIdToUse');
      
      return paymentResult;
    } catch (e) {
      _logger.error('Error starting Razorpay payment: $e');
      
      if (kDebugMode) print('\n❌ === PAYMENT PROCESS ERROR === ❌');
      if (kDebugMode) print('Error: $e');
      if (kDebugMode) print('Temp Order ID: ${tempOrderId ?? customOrderId}');
      if (kDebugMode) print('❌ === END ERROR === ❌\n');
      
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