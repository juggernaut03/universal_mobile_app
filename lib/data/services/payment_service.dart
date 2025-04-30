// lib/data/services/payment_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/utils/logger.dart';

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;
  final Object? error;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
    this.error,
  });
}

class PaymentService {
  final Logger _logger;
  late Razorpay _razorpay;
  Completer<PaymentResult>? _paymentCompleter;

  // Razorpay API credentials
  static const String keyId = 'rzp_test_5yy0US6kMQYbpU';
  // Note: The key secret should only be used on your server, not in the app
  // We're including it here for reference only
  static const String keySecret = '7ZwGbFIgsktyJlZOEbFNj6aN';

  PaymentService({Logger? logger}) : _logger = logger ?? Logger() {
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _setupListeners();
    _logger.log('Razorpay instance initialized');
  }

  void _setupListeners() {
    // Configure the event listeners only once during initialization
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _logger.log('Payment successful: ${response.paymentId}');
    
    // Only complete if the completer exists and hasn't been completed yet
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: true,
        paymentId: response.paymentId,
        orderId: response.orderId,
        signature: response.signature,
      ));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _logger.error('Payment error: ${response.code} - ${response.message}');
    
    // Only complete if the completer exists and hasn't been completed yet
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: false,
        message: 'Payment failed: ${response.message}',
        error: Exception('Payment error: ${response.code}'),
      ));
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _logger.log('External wallet selected: ${response.walletName}');
    
    // Only complete if the completer exists and hasn't been completed yet
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: false,
        message: 'External wallet selected: ${response.walletName}',
      ));
    }
  }

  /// Start a payment process with Razorpay
  /// 
  /// Parameters:
  /// - amount: The amount to be paid (in the smallest currency unit, e.g., paise for INR)
  /// - description: Description of the payment
  /// - customerName: Name of the customer
  /// - customerEmail: Email of the customer (optional)
  /// - customerPhone: Phone number of the customer (optional)
  /// - orderId: A unique order ID for reference (optional)
  Future<PaymentResult> startPayment({
    required double amount, 
    required String description,
    required String customerName,
    String? customerEmail,
    String? customerPhone,
    String? orderId,
  }) async {
    try {
      _logger.log('Starting Razorpay payment for amount: ${amount.toStringAsFixed(2)}');
      
      // Create a new completer for this payment attempt
      // Ensure any existing completer is discarded
      _paymentCompleter = Completer<PaymentResult>();
      
      // Create the payment options
      final options = {
        'key': keyId,
        'amount': (amount * 100).toInt(), // Convert to smallest currency unit (paise)
        'name': 'PatelMart',
        'description': description,
        'prefill': {
          'name': customerName,
          'email': customerEmail ?? '',
          'contact': customerPhone ?? '',
        },
        'external': {
          'wallets': ['paytm']
        }
      };
      
      // Add order ID if provided
      if (orderId != null && orderId.isNotEmpty) {
        options['order_id'] = orderId;
      }
      
      // Open the Razorpay checkout
      _razorpay.open(options);
      
      // Wait for the payment result
      return await _paymentCompleter!.future;
    } catch (e) {
      _logger.error('Error starting Razorpay payment: $e');
      
      // If we encounter an error before the payment process starts,
      // and the completer hasn't been completed yet, complete it with an error
      if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
        _paymentCompleter!.complete(PaymentResult(
          success: false,
          message: 'Failed to start payment process: ${e.toString()}',
          error: e,
        ));
      }
      
      return PaymentResult(
        success: false,
        message: 'Failed to start payment process: ${e.toString()}',
        error: e,
      );
    }
  }

  void dispose() {
    // Clean up any pending completers
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PaymentResult(
        success: false,
        message: 'Payment cancelled due to service disposal',
      ));
    }
    
    // Clear event handlers and dispose Razorpay instance
    _razorpay.clear();
    _logger.log('Razorpay instance disposed');
  }
}