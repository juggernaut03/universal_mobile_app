// lib/utils/payment_data_formatter.dart

import 'dart:convert';
import '../data/services/payment_service.dart';

enum PaymentDataFormat {
  array,
  string,
  object,
  both, // Sends both array and string formats
}

class PaymentDataFormatter {
  
  /// Format payment result for API based on the specified format
  static Map<String, dynamic> formatPaymentData({
    required PaymentResult paymentResult,
    required PaymentDataFormat format,
    String arrayFieldName = "payment_gateway_data",
    String stringFieldName = "payment_data_string",
    String razorpayArrayFieldName = "razorpay_payment_details",
    String razorpayStringFieldName = "razorpay_payment_string",
  }) {
    
    final Map<String, dynamic> result = {};
    
    if (!paymentResult.success) {
      // Handle payment failure
      final failureData = {
        "gateway": "razorpay",
        "payment_failed": true,
        "failure_reason": paymentResult.message,
        "failure_data": paymentResult.fullPaymentData,
        "gateway_timestamp": DateTime.now().millisecondsSinceEpoch,
        "environment": "live"
      };
      
      switch (format) {
        case PaymentDataFormat.array:
          result[arrayFieldName] = [failureData];
          break;
        case PaymentDataFormat.string:
          result[stringFieldName] = jsonEncode(failureData);
          break;
        case PaymentDataFormat.object:
          result[arrayFieldName] = failureData;
          break;
        case PaymentDataFormat.both:
          result[arrayFieldName] = [failureData];
          result[stringFieldName] = jsonEncode(failureData);
          break;
      }
      
      return result;
    }
    
    // Handle successful payment - Enhanced with all available data
    final paymentData = {
      "gateway": "razorpay",
      "environment": "live",
      "payment_id": paymentResult.paymentId,
      "order_id": paymentResult.orderId,
      "signature": paymentResult.signature,
      "amount": paymentResult.amount,
      "currency": paymentResult.currency ?? "INR",
      "status": paymentResult.status ?? "captured",
      "method": paymentResult.method ?? "unknown",
      "captured": paymentResult.captured ?? true,
      "vpa": paymentResult.vpa,
      "email": paymentResult.email,
      "contact": paymentResult.contact,
      "created_at": paymentResult.createdAt,
      "captured_at": paymentResult.capturedAt,
      "acquirer_data": paymentResult.acquirerData,
      "upi_data": paymentResult.upiData,
      "full_payment_response": paymentResult.fullPaymentData,
      "gateway_timestamp": DateTime.now().millisecondsSinceEpoch,
      "sdk_source": "flutter",
    };
    
    // Format main payment data based on specified format
    switch (format) {
      case PaymentDataFormat.array:
        result[arrayFieldName] = [paymentData];
        break;
      case PaymentDataFormat.string:
        result[stringFieldName] = jsonEncode(paymentData);
        break;
      case PaymentDataFormat.object:
        result[arrayFieldName] = paymentData;
        break;
      case PaymentDataFormat.both:
        result[arrayFieldName] = [paymentData];
        result[stringFieldName] = jsonEncode(paymentData);
        break;
    }
    
    // Add complete Razorpay payment details if available
    if (paymentResult.fullPaymentData != null) {
      switch (format) {
        case PaymentDataFormat.array:
          result[razorpayArrayFieldName] = [paymentResult.fullPaymentData];
          break;
        case PaymentDataFormat.string:
          result[razorpayStringFieldName] = jsonEncode(paymentResult.fullPaymentData);
          break;
        case PaymentDataFormat.object:
          result[razorpayArrayFieldName] = paymentResult.fullPaymentData;
          break;
        case PaymentDataFormat.both:
          result[razorpayArrayFieldName] = [paymentResult.fullPaymentData];
          result[razorpayStringFieldName] = jsonEncode(paymentResult.fullPaymentData);
          break;
      }
    }
    
    return result;
  }
  
  /// Get payment data specifically for your exact JSON structure
  static Map<String, dynamic> getExactRazorpayFormat(PaymentResult paymentResult) {
    if (paymentResult.fullPaymentData == null) {
      return {};
    }
    
    // Return the exact structure you provided
    return {
      "razorpay_payment_data": paymentResult.fullPaymentData,
      "razorpay_payment_array": [paymentResult.fullPaymentData],
      "razorpay_payment_string": jsonEncode(paymentResult.fullPaymentData),
      "razorpay_complete_data": paymentResult.fullPaymentData,
    };
  }
  
  /// Format for different API requirements
  static Map<String, dynamic> formatForCommonApis({
    required PaymentResult paymentResult,
    bool includeArrayFormat = true,
    bool includeStringFormat = true,
    bool includeObjectFormat = false,
  }) {
    final Map<String, dynamic> result = {};
    
    if (!paymentResult.success || paymentResult.fullPaymentData == null) {
      return result;
    }
    
    // Array format - wrapped in array
    if (includeArrayFormat) {
      result["payment_data"] = [paymentResult.fullPaymentData];
      result["razorpay_data"] = [paymentResult.fullPaymentData];
    }
    
    // String format - JSON encoded
    if (includeStringFormat) {
      result["payment_data_json"] = jsonEncode(paymentResult.fullPaymentData);
      result["razorpay_data_json"] = jsonEncode(paymentResult.fullPaymentData);
    }
    
    // Object format - direct object
    if (includeObjectFormat) {
      result["payment_data_object"] = paymentResult.fullPaymentData;
      result["razorpay_data_object"] = paymentResult.fullPaymentData;
    }
    
    return result;
  }
  
  /// Debug method to show all possible formats
  static void logAllFormats(PaymentResult paymentResult) {
    print('\n💳 === ALL PAYMENT DATA FORMATS === 💳');
    
    // Array format
    final arrayFormat = formatPaymentData(
      paymentResult: paymentResult,
      format: PaymentDataFormat.array,
    );
    print('ARRAY FORMAT:');
    print(JsonEncoder.withIndent('  ').convert(arrayFormat));
    print('');
    
    // String format
    final stringFormat = formatPaymentData(
      paymentResult: paymentResult,
      format: PaymentDataFormat.string,
    );
    print('STRING FORMAT:');
    print(JsonEncoder.withIndent('  ').convert(stringFormat));
    print('');
    
    // Object format
    final objectFormat = formatPaymentData(
      paymentResult: paymentResult,
      format: PaymentDataFormat.object,
    );
    print('OBJECT FORMAT:');
    print(JsonEncoder.withIndent('  ').convert(objectFormat));
    print('');
    
    // Both formats
    final bothFormat = formatPaymentData(
      paymentResult: paymentResult,
      format: PaymentDataFormat.both,
    );
    print('BOTH FORMATS:');
    print(JsonEncoder.withIndent('  ').convert(bothFormat));
    print('');
    
    // Exact Razorpay format
    final exactFormat = getExactRazorpayFormat(paymentResult);
    print('EXACT RAZORPAY FORMAT:');
    print(JsonEncoder.withIndent('  ').convert(exactFormat));
    
    print('💳 === END ALL FORMATS === 💳\n');
  }
}