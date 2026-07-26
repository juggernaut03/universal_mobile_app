// lib/domain/repositories/i_payment_gateway.dart

import '../entities/payment.dart';

/// Collects a payment.
///
/// Razorpay sits behind this. The interface exists so the checkout flow can be
/// driven by a fake in tests — today nothing on the money path can run without
/// the real SDK and a live key.
abstract interface class IPaymentGateway {
  /// Presents the gateway and resolves once the customer finishes with it.
  ///
  /// Completes with an outcome rather than throwing: a declined card and a
  /// dismissed sheet are ordinary results, not exceptions.
  Future<PaymentOutcome> collect(PaymentRequest request);

  /// Releases SDK resources. Must be called when checkout is disposed.
  void dispose();
}
