// lib/domain/entities/payment.dart
//
// Payment vocabulary, independent of Razorpay.
//
// PaymentService talks to the Razorpay SDK directly and is referenced from
// checkout_flow_screen, so nothing on the money path can be exercised without
// the real gateway. These types let the flow be driven by a fake.

import 'package:meta/meta.dart';

/// How the customer is paying.
enum PaymentMethod {
  /// Cash or card at the door.
  cashOnDelivery,

  /// Anything settled through the gateway before dispatch.
  online;

  bool get isPrepaid => this == PaymentMethod.online;
}

/// A payment the app is asking the gateway to collect.
@immutable
final class PaymentRequest {
  /// Amount in rupees.
  final double amount;

  /// Our own order reference, echoed back by the gateway.
  final String orderReference;

  /// Gateway-side order id, when one was created up front.
  final String? gatewayOrderId;

  final String customerName;
  final String customerPhone;
  final String customerEmail;

  const PaymentRequest({
    required this.amount,
    required this.orderReference,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = '',
    this.gatewayOrderId,
  });

  /// Amount in the smallest currency unit, which is what gateways charge in.
  ///
  /// Rounded rather than truncated: `(x * 100).toInt()` on a double can land a
  /// paisa short through binary representation, and the gateway then rejects
  /// the amount as mismatched.
  int get amountInPaise => (amount * 100).round();

  /// Never interpolates customer contact details — this reaches logs.
  @override
  String toString() =>
      'PaymentRequest($orderReference, ₹${amount.toStringAsFixed(2)})';
}

/// What the gateway came back with.
///
/// Sealed: a payment attempt has exactly three outcomes, and the caller must
/// handle all of them. The previous flow used SDK callbacks with no shared
/// type, so "cancelled" and "failed" were handled in different places and
/// sometimes not at all.
@immutable
sealed class PaymentOutcome {
  const PaymentOutcome();
}

/// The gateway collected the money.
final class PaymentSucceeded extends PaymentOutcome {
  /// Gateway payment id, needed to reconcile and to refund.
  final String paymentId;

  final String orderReference;

  /// Gateway signature, used server-side to verify authenticity.
  ///
  /// A credential: never log it, never render it.
  final String signature;

  const PaymentSucceeded({
    required this.paymentId,
    required this.orderReference,
    required this.signature,
  });

  @override
  String toString() => 'PaymentSucceeded($paymentId)';
}

/// The gateway refused or errored.
final class PaymentFailed extends PaymentOutcome {
  final String code;
  final String message;

  const PaymentFailed({required this.code, required this.message});

  /// Text safe to show the customer.
  ///
  /// Gateway messages are often internal, so a known-empty one falls back to
  /// generic copy rather than showing a blank dialog.
  String get userMessage => message.trim().isEmpty
      ? 'The payment could not be completed. Please try again.'
      : message;

  @override
  String toString() => 'PaymentFailed($code)';
}

/// The customer dismissed the gateway sheet.
///
/// Distinct from [PaymentFailed]: nothing went wrong, so it must not surface as
/// an error, and the order must not be marked failed.
final class PaymentCancelled extends PaymentOutcome {
  const PaymentCancelled();

  @override
  String toString() => 'PaymentCancelled()';
}
