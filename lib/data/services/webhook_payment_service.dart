// lib/data/services/webhook_payment_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import 'payment_service.dart';

class WebhookPaymentService {
  final Logger _logger;
  final http.Client _client;

  WebhookPaymentService({
    Logger? logger,
    http.Client? client,
  }) : 
    _logger = logger ?? Logger(),
    _client = client ?? http.Client();

  /// Fetch complete payment details using Razorpay Payments API
  /// This gets the updated data that includes UPI details
  Future<Map<String, dynamic>?> fetchCompletePaymentDetails({
    required String paymentId,
    required String keyId,
    required String keySecret,
  }) async {
    try {
      _logger.log('Fetching complete payment details for: $paymentId');
      
      print('\n🔍 === FETCHING COMPLETE PAYMENT DATA === 🔍');
      print('Payment ID: $paymentId');
      print('Using Razorpay Payments API...');
      print('🔍 === CALLING API === 🔍\n');

      // Call Razorpay Payments API to get complete details
      final response = await _client.get(
        Uri.parse('https://api.razorpay.com/v1/payments/$paymentId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$keyId:$keySecret'))}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      _logger.log('Payment details API response status: ${response.statusCode}');
      _logger.log('Payment details API response: ${response.body}');

      print('\n📋 === PAYMENT API RESPONSE === 📋');
      print('Status Code: ${response.statusCode}');
      print('Response Body:');
      try {
        final responseJson = jsonDecode(response.body);
        print(JsonEncoder.withIndent('  ').convert(responseJson));
      } catch (e) {
        print(response.body);
      }
      print('📋 === END API RESPONSE === 📋\n');

      if (response.statusCode == 200) {
        final paymentData = jsonDecode(response.body);
        
        // Log what we got
        print('\n✅ === COMPLETE PAYMENT DATA RECEIVED === ✅');
        print('Payment ID: ${paymentData['id']}');
        print('Method: ${paymentData['method']}');
        print('Status: ${paymentData['status']}');
        print('VPA: ${paymentData['vpa'] ?? "null"}');
        print('Bank: ${paymentData['bank'] ?? "null"}');
        print('Wallet: ${paymentData['wallet'] ?? "null"}');
        
        if (paymentData['acquirer_data'] != null) {
          print('Acquirer Data: ${paymentData['acquirer_data']}');
        }
        
        if (paymentData['upi'] != null) {
          print('UPI Data: ${paymentData['upi']}');
        }
        print('✅ === END COMPLETE DATA === ✅\n');
        
        return paymentData;
      } else {
        _logger.error('Failed to fetch payment details: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.error('Error fetching complete payment details: $e');
      print('\n❌ === ERROR FETCHING PAYMENT DATA === ❌');
      print('Error: $e');
      print('❌ === END ERROR === ❌\n');
      return null;
    }
  }

  /// Enhanced payment result with webhook data
  Future<PaymentResult> getEnhancedPaymentResult({
    required PaymentResult originalResult,
    required String keyId,
    required String keySecret,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 5),
  }) async {
    if (!originalResult.success || originalResult.paymentId == null) {
      return originalResult;
    }

    print('\n🔄 === ENHANCING PAYMENT DATA === 🔄');
    print('Original Payment ID: ${originalResult.paymentId}');
    print('Will retry up to $maxRetries times with ${retryDelay.inSeconds}s delay');
    print('🔄 === STARTING ENHANCEMENT === 🔄\n');

    // Try multiple times to get complete data (sometimes takes a few seconds)
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('\n🔄 === ATTEMPT $attempt/$maxRetries === 🔄');
      
      // Wait before each attempt (except first)
      if (attempt > 1) {
        print('Waiting ${retryDelay.inSeconds} seconds before retry...');
        await Future.delayed(retryDelay);
      }

      final completePaymentData = await fetchCompletePaymentDetails(
        paymentId: originalResult.paymentId!,
        keyId: keyId,
        keySecret: keySecret,
      );

      if (completePaymentData != null) {
        // Check if we got the enhanced data we need
        final hasVpa = completePaymentData['vpa'] != null;
        final hasAcquirerData = completePaymentData['acquirer_data'] != null && 
                               completePaymentData['acquirer_data'] is Map &&
                               (completePaymentData['acquirer_data'] as Map).isNotEmpty;
        final hasUpiData = completePaymentData['upi'] != null &&
                          completePaymentData['upi'] is Map &&
                          (completePaymentData['upi'] as Map).isNotEmpty;

        print('Enhanced data check - VPA: $hasVpa, Acquirer: $hasAcquirerData, UPI: $hasUpiData');

        // If we have meaningful enhanced data OR this is our last attempt, use what we have
        if ((hasVpa || hasAcquirerData || hasUpiData) || attempt == maxRetries) {
          print('\n🎉 === PAYMENT DATA ENHANCED === 🎉');
          print('VPA: ${completePaymentData['vpa'] ?? "Not available"}');
          print('Method: ${completePaymentData['method'] ?? "Unknown"}');
          print('Bank: ${completePaymentData['bank'] ?? "Not available"}');
          print('Wallet: ${completePaymentData['wallet'] ?? "Not available"}');
          
          if (hasAcquirerData) {
            print('Acquirer Data Keys: ${(completePaymentData['acquirer_data'] as Map).keys.toList()}');
          }
          
          if (hasUpiData) {
            print('UPI Data Keys: ${(completePaymentData['upi'] as Map).keys.toList()}');
          }
          print('🎉 === END ENHANCEMENT === 🎉\n');

          // Create enhanced PaymentResult
          return PaymentResult(
            success: originalResult.success,
            paymentId: originalResult.paymentId,
            orderId: originalResult.orderId,
            signature: originalResult.signature,
            message: originalResult.message,
            error: originalResult.error,
            
            // Enhanced data from API
            fullPaymentData: completePaymentData,
            razorpayOrderId: completePaymentData['order_id'],
            amount: completePaymentData['amount'] != null 
                ? (completePaymentData['amount'] as int) / 100.0 
                : originalResult.amount,
            currency: completePaymentData['currency'] ?? originalResult.currency,
            status: completePaymentData['status'] ?? originalResult.status,
            method: completePaymentData['method'] ?? originalResult.method,
            captured: completePaymentData['captured'] ?? originalResult.captured,
            vpa: completePaymentData['vpa'], // This should now have real UPI VPA
            email: completePaymentData['email'] ?? originalResult.email,
            contact: completePaymentData['contact'] ?? originalResult.contact,
            acquirerData: completePaymentData['acquirer_data'] as Map<String, dynamic>?,
            upiData: completePaymentData['upi'] as Map<String, dynamic>?,
            createdAt: completePaymentData['created_at'] ?? originalResult.createdAt,
            capturedAt: completePaymentData['captured_at'] ?? originalResult.capturedAt,
          );
        }
      }

      print('No enhanced data yet, will retry...');
    }

    print('\n⚠️ === NO ENHANCED DATA AVAILABLE === ⚠️');
    print('Returning original payment result');
    print('⚠️ === END ENHANCEMENT === ⚠️\n');

    // Return original result if no enhancement possible
    return originalResult;
  }
}

// Updated payment service with webhook enhancement
class EnhancedPaymentService extends PaymentService {
  final WebhookPaymentService _webhookService;

  EnhancedPaymentService({
    Logger? logger,
  }) : 
    _webhookService = WebhookPaymentService(logger: logger),
    super(logger: logger);

  @override
  Future<PaymentResult> startPayment({
    required double amount, 
    required String description,
    required String customerName,
    String? customerEmail,
    String? customerPhone,
    String? customOrderId,
    bool enhanceWithWebhookData = true, // New parameter
  }) async {
    // Get the initial payment result
    final initialResult = await super.startPayment(
      amount: amount,
      description: description,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      customOrderId: customOrderId,
    );

    // If payment failed or enhancement disabled, return as-is
    if (!initialResult.success || !enhanceWithWebhookData) {
      return initialResult;
    }

    print('\n🚀 === STARTING PAYMENT ENHANCEMENT === 🚀');
    print('Initial payment successful, fetching complete details...');
    print('🚀 === ENHANCEMENT IN PROGRESS === 🚀\n');

    // Enhance with webhook/API data
    final enhancedResult = await _webhookService.getEnhancedPaymentResult(
      originalResult: initialResult,
      keyId: PaymentService.keyId,
      keySecret: PaymentService.keySecret,
      maxRetries: 3,
      retryDelay: const Duration(seconds: 5),
    );

    print('\n📊 === FINAL PAYMENT COMPARISON === 📊');
    print('Original VPA: ${initialResult.vpa ?? "null"}');
    print('Enhanced VPA: ${enhancedResult.vpa ?? "null"}');
    print('Original Method: ${initialResult.method ?? "unknown"}');
    print('Enhanced Method: ${enhancedResult.method ?? "unknown"}');
    print('Original Acquirer Data: ${initialResult.acquirerData != null ? "Available" : "null"}');
    print('Enhanced Acquirer Data: ${enhancedResult.acquirerData != null ? "Available" : "null"}');
    print('📊 === END COMPARISON === 📊\n');

    return enhancedResult;
  }
}