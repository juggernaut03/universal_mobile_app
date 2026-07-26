// lib/data/services/razorpay_payment_gateway.dart
//
// Razorpay behind IPaymentGateway.
//
// The SDK is callback-based: you call `open()` and later one of three handlers
// fires. PaymentService wires those handlers to scattered state and screen
// navigation, which is why nothing on the money path could be tested.
//
// This adapter turns the three callbacks into one awaited PaymentOutcome, so
// the caller reads as a straight line and the whole flow can be driven by a
// fake in tests.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/config/env_config.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/i_payment_gateway.dart';

final class RazorpayPaymentGateway implements IPaymentGateway {
  final Logger _logger;
  final Razorpay _razorpay;

  /// Completes when the SDK reports an outcome.
  ///
  /// Non-null only while a payment sheet is open.
  Completer<PaymentOutcome>? _pending;

  RazorpayPaymentGateway({required Logger logger, Razorpay? razorpay})
      : _logger = logger,
        _razorpay = razorpay ?? Razorpay() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  Future<PaymentOutcome> collect(PaymentRequest request) {
    // Two sheets open at once would leave the first Completer dangling and its
    // caller awaiting forever.
    final existing = _pending;
    if (existing != null && !existing.isCompleted) {
      _logger.warning('A payment is already in progress; refusing a second');
      return Future.value(const PaymentFailed(
        code: 'payment_in_progress',
        message: 'A payment is already in progress.',
      ));
    }

    final completer = Completer<PaymentOutcome>();
    _pending = completer;

    try {
      _razorpay.open({
        'key': EnvConfig.razorpayKeyId,
        // Gateways charge in the smallest unit; PaymentRequest rounds rather
        // than truncates so the amount cannot land a paisa short.
        'amount': request.amountInPaise,
        'name': request.customerName,
        'order_id': request.gatewayOrderId,
        'description': 'Order ${request.orderReference}',
        'prefill': {
          'contact': request.customerPhone,
          'email': request.customerEmail,
        },
        'retry': {'enabled': true, 'max_count': 1},
      });
    } on Object catch (e, st) {
      _logger.error('Could not open the Razorpay sheet: $e', e, st);
      _complete(PaymentFailed(code: 'sdk_open_failed', message: '$e'));
    }

    return completer.future;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    // Signature is a credential — recorded in the outcome for the server to
    // verify, never logged.
    _logger.log('Payment succeeded: ${response.paymentId}');
    _complete(PaymentSucceeded(
      paymentId: response.paymentId ?? '',
      orderReference: response.orderId ?? '',
      signature: response.signature ?? '',
    ));
  }

  void _onError(PaymentFailureResponse response) {
    final code = '${response.code ?? ''}';
    final message = response.message ?? '';

    // Razorpay reports a user-dismissed sheet as an error. Treating it as a
    // failure marks the order failed and shows an error dialog for something
    // the customer did deliberately.
    final cancelled = code == '2' ||
        message.toLowerCase().contains('cancelled by user') ||
        message.toLowerCase().contains('payment cancelled');

    if (cancelled) {
      _logger.log('Payment cancelled by the customer');
      _complete(const PaymentCancelled());
      return;
    }

    _logger.error('Payment failed [$code]: $message');
    _complete(PaymentFailed(code: code, message: message));
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // The wallet app takes over; success or failure still arrives through the
    // handlers above, so nothing is completed here.
    if (kDebugMode) {
      _logger.log('External wallet selected: ${response.walletName}');
    }
  }

  void _complete(PaymentOutcome outcome) {
    final completer = _pending;
    _pending = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }

  @override
  void dispose() {
    // A sheet open at dispose time would never complete; resolve it so the
    // awaiting caller is not stuck.
    _complete(const PaymentCancelled());
    _razorpay.clear();
  }
}
