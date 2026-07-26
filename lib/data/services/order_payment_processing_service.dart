// lib/data/services/order_payment_processing_service.dart
//
// REPURPOSED. The old backend created a pre-payment "Payment Processing"
// order row before opening the Razorpay checkout. The universal backend has
// no such concept — instead, this pre-payment step now pushes the local cart
// to the server and validates it (POST /api/cart/save-cart + validate-cart),
// which place-order requires. The checkout flow's step sequence is unchanged.

import '../../core/utils/logger.dart';
import '../models/address_model.dart';
import '../models/cart_item.dart';
import 'cart_validator.dart';

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
  final Logger _logger;
  final CartValidator? _cartValidator;

  OrderPaymentProcessingService({
    Object? client,
    Logger? logger,
    CartValidator? cartValidator,
  })  : _logger = logger ?? Logger(),
        _cartValidator = cartValidator;

  /// Pre-payment gate: push the local cart to the server and validate it so
  /// the subsequent place-order call finds a fresh, valid server cart.
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
    if (_cartValidator == null) {
      _logger.warning(
          'markOrderAsPaymentProcessing: no CartValidator wired — skipping server cart sync');
      return OrderPaymentProcessingResponse(
        success: true,
        message: 'Proceeding to payment',
        tempOrderId: tempOrderId,
      );
    }

    _logger.log(
        'markOrderAsPaymentProcessing: syncing server cart before payment (store $storeCode)');

    final result = await _cartValidator.validateCart(cartItems, storeCode);

    if (result == null || result.isSaveError) {
      return OrderPaymentProcessingResponse(
        success: false,
        message: result?.validationMessage ?? 'Failed to save cart to server',
        tempOrderId: tempOrderId,
      );
    }

    if (!result.isValid || result.hasChanges) {
      // Stock/price changed between cart screen and checkout — send the user
      // back rather than placing an order that no longer matches their cart.
      return OrderPaymentProcessingResponse(
        success: false,
        message: result.validationMessage.isNotEmpty
            ? result.validationMessage
            : 'Some items in your cart changed. Please review your cart.',
        tempOrderId: tempOrderId,
      );
    }

    return OrderPaymentProcessingResponse(
      success: true,
      message: 'Cart synced and validated — proceeding to payment',
      tempOrderId: tempOrderId,
    );
  }
}
