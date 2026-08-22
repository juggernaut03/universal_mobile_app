// lib/data/services/order_service.dart
//
// Places orders against the universal backend (POST /api/orders/place-order).
// The server computes totals from ITS saved cart (pushed via CartValidator),
// so the legacy mega-payload (cart items + totals in the request) is gone.

import 'dart:async';
import 'package:patelmart/utils/payment_data_formatter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/address_model.dart';
import '../models/cart_item.dart';
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
  final ApiClient? _apiClient;
  final Logger _logger;

  OrderService({
    ApiClient? apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// Place an order on the universal backend.
  ///
  /// Signature kept compatible with the legacy confirmOrder call sites; the
  /// legacy identifier / totals parameters are accepted but no longer sent —
  /// the server derives items and totals from the saved cart. Pass
  /// [deliverySlotId] and [paymentModeId] when available (falls back to
  /// mapping the display strings).
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
    String? mobPlatform,
    PaymentResult? paymentResult,
    PaymentDataFormat paymentFormat = PaymentDataFormat.both,
    int? deliverySlotId,
    int? paymentModeId,
    double? deliveryDistance,
    String? offerId,
    // A LoyaltyRedemption id (from GET /api/loyalty/redemptions/active) the
    // customer chose to apply. The server validates it, computes the
    // discount itself, and marks it used atomically with the order - see
    // utils/orderService.js's loyalty_redemption_id handling. Not yet wired
    // to a checkout UI picker; the field exists so callers can pass it once
    // one is built.
    String? loyaltyRedemptionId,
  }) async {
    try {
      _logger.log('=== PLACING ORDER (universal backend) ===');

      if (_apiClient == null) {
        return OrderConfirmationResponse(
          success: false,
          message: 'Order service unavailable',
          tempOrderId: tempOrderId,
        );
      }

      final bool isOnlinePayment =
          paymentMode.toLowerCase().contains('online');

      // A failed online payment never reaches the server — there is no
      // pre-payment order row on the universal backend.
      if (isOnlinePayment && (paymentResult == null || !paymentResult.success)) {
        _logger.error(
            'Online payment failed — order not placed: ${paymentResult?.message ?? "no payment result"}');
        return OrderConfirmationResponse(
          success: false,
          message: paymentResult?.message ?? 'Payment failed. Order not placed.',
          tempOrderId: tempOrderId,
          error: paymentResult?.error,
        );
      }

      if (cartItems.isEmpty) {
        throw Exception('Cart items cannot be empty');
      }
      if (deliveryAddress.id.isEmpty) {
        throw Exception(
            'Delivery address is missing its server id — re-select the address');
      }

      Map<String, dynamic>? paymentDetails;
      if (isOnlinePayment && paymentResult != null) {
        paymentDetails = {
          'razorpay_payment_id':
              paymentResult.paymentId ?? transactionId ?? '',
          'razorpay_order_id':
              paymentResult.razorpayOrderId ?? paymentResult.orderId ?? '',
          if (paymentResult.signature != null)
            'razorpay_signature': paymentResult.signature,
          'method': 'online_payment',
        };
      }

      final body = <String, dynamic>{
        'store_code': storeCode,
        'cart_validated': true,
        'delivery_slot_id': deliverySlotId ?? _getDeliverySlotId(deliverySlot),
        'delivery_date': _toIsoDate(deliveryDate),
        'address_id': deliveryAddress.id,
        'payment_mode_id': paymentModeId ?? _getPaymentModeId(paymentMode),
        if (specialNotes != null && specialNotes.trim().isNotEmpty)
          'order_notes': specialNotes.trim(),
        if (paymentDetails != null) 'payment_details': paymentDetails,
        'delivery_charges': deliveryCharges,
        if (deliveryDistance != null) 'delivery_distance': deliveryDistance,
        if (offerId != null && offerId.isNotEmpty) 'offer_id': offerId,
        if (loyaltyRedemptionId != null && loyaltyRedemptionId.isNotEmpty)
          'loyalty_redemption_id': loyaltyRedemptionId,
      };

      _logger.log(
          'place-order: store=$storeCode slot=${body['delivery_slot_id']} date=${body['delivery_date']} '
          'payment_mode=${body['payment_mode_id']} online=$isOnlinePayment');

      final response = await _apiClient.postWithAuth(
        ApiConstants.ordersPlace,
        body: body,
      );

      if (response is Map && response['success'] == true) {
        final order = response['order'] is Map
            ? Map<String, dynamic>.from(response['order'] as Map)
            : <String, dynamic>{};
        final orderNumber = (order['order_number'] ?? '').toString();

        _logger.log('✅ Order placed successfully: $orderNumber');

        return OrderConfirmationResponse(
          success: true,
          message: (response['message'] ?? 'Order placed successfully').toString(),
          orderId: orderNumber,
          tempOrderId: tempOrderId,
          data: order,
        );
      }

      _logger.error('place-order failed: $response');
      return OrderConfirmationResponse(
        success: false,
        message: response is Map
            ? (response['message'] ?? response['error'] ?? 'Failed to place order')
                .toString()
            : 'Failed to place order',
        tempOrderId: tempOrderId,
      );
    } on ApiException catch (e) {
      _logger.error('place-order ApiException: ${e.message}');
      return OrderConfirmationResponse(
        success: false,
        message: e.message,
        tempOrderId: tempOrderId,
        error: e,
      );
    } catch (e) {
      _logger.error('Error placing order: $e');
      return OrderConfirmationResponse(
        success: false,
        message: 'Error placing order: $e',
        tempOrderId: tempOrderId,
        error: e,
      );
    }
  }

  /// Convert dd/MM/yyyy (legacy UI format) to yyyy-MM-dd; passes through
  /// values that already parse.
  String _toIsoDate(String date) {
    final trimmed = date.trim();
    final ddmmyyyy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
    if (ddmmyyyy != null) {
      final d = ddmmyyyy.group(1)!.padLeft(2, '0');
      final m = ddmmyyyy.group(2)!.padLeft(2, '0');
      return '${ddmmyyyy.group(3)}-$m-$d';
    }
    return trimmed;
  }

  // Helper: map delivery slot display text to iddelivery_slot (fallback only —
  // prefer passing deliverySlotId explicitly from the selected slot object).
  int _getDeliverySlotId(String deliverySlot) {
    final normalizedSlot = deliverySlot.toLowerCase().trim();

    if (normalizedSlot.contains('9:00') && normalizedSlot.contains('10:00')) {
      return 1;
    } else if (normalizedSlot.contains('9:00') && normalizedSlot.contains('1:00')) {
      return 2;
    } else if (normalizedSlot.contains('1:00') && normalizedSlot.contains('6:00')) {
      return 3;
    } else if (normalizedSlot.contains('6:00') && normalizedSlot.contains('10:00')) {
      return 4;
    } else if (normalizedSlot.contains('11:00') && normalizedSlot.contains('12:00')) {
      return 5;
    } else if (normalizedSlot.contains('12:00') && normalizedSlot.contains('01:00')) {
      return 6;
    } else if (normalizedSlot.contains('01:00') && normalizedSlot.contains('02:00')) {
      return 7;
    }

    _logger.warning('Unknown delivery slot format: $deliverySlot, using default ID: 1');
    return 1;
  }

  // Helper: map payment mode display text to idpayment_mode (fallback only)
  int _getPaymentModeId(String paymentMode) {
    final normalizedMode = paymentMode.toLowerCase().trim();

    if (normalizedMode.contains('pod') || normalizedMode.contains('cash')) {
      return 1;
    } else if (normalizedMode.contains('online') ||
        normalizedMode.contains('card') ||
        normalizedMode.contains('upi') ||
        normalizedMode.contains('net banking')) {
      return 2;
    }

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
    required Map<String, dynamic> deliveryAddressMap,
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
    String? mobPlatform,
    PaymentResult? paymentResult,
    PaymentDataFormat paymentFormat = PaymentDataFormat.both,
    int? deliverySlotId,
    int? paymentModeId,
  }) async {
    final address = Address.fromJson(deliveryAddressMap);

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
      deliverySlotId: deliverySlotId,
      paymentModeId: paymentModeId,
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
    if (storeCode.isEmpty) {
      _logger.error('Validation failed: store code is empty');
      return false;
    }

    if (cartItems.isEmpty) {
      _logger.error('Validation failed: Cart is empty');
      return false;
    }

    if (deliveryAddress.fullName.isEmpty || deliveryAddress.mobileNumber.isEmpty) {
      _logger.error('Validation failed: Delivery address is incomplete');
      return false;
    }

    if (finalPayableAmount <= 0) {
      _logger.error('Validation failed: Final payable amount must be greater than 0');
      return false;
    }

    _logger.log('Order data validation passed');
    return true;
  }
}
