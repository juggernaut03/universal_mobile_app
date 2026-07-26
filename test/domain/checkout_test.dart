// test/domain/checkout_test.dart
//
// Checkout flow transitions and payment vocabulary.
//
// None of this was testable before: the step order lived in an int index inside
// a 4,708-line widget, and payment outcomes existed only as Razorpay SDK
// callbacks.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/domain/entities/checkout_step.dart';
import 'package:patelmart/domain/entities/payment.dart';

void main() {
  group('CheckoutFlow — delivery', () {
    test('runs through all four steps', () {
      const flow = CheckoutFlow.start();

      expect(flow.steps, [
        CheckoutStep.fulfilment,
        CheckoutStep.address,
        CheckoutStep.slot,
        CheckoutStep.payment,
      ]);
      expect(flow.totalSteps, 4);
    });

    test('advances to the end and stops', () {
      var flow = const CheckoutFlow.start();

      flow = flow.advance();
      expect(flow.current, CheckoutStep.address);
      flow = flow.advance();
      expect(flow.current, CheckoutStep.slot);
      flow = flow.advance();
      expect(flow.current, CheckoutStep.payment);
      expect(flow.isLast, isTrue);

      // Advancing past payment must not wrap or overrun.
      expect(flow.advance().current, CheckoutStep.payment);
    });

    test('goes back and stops at the start', () {
      const flow = CheckoutFlow(current: CheckoutStep.address);

      expect(flow.goBack().current, CheckoutStep.fulfilment);
      expect(flow.goBack().goBack().current, CheckoutStep.fulfilment);
      expect(flow.goBack().isFirst, isTrue);
    });
  });

  group('CheckoutFlow — self pickup', () {
    test('skips the address step', () {
      const flow = CheckoutFlow.start(isSelfPickup: true);

      expect(flow.steps, [
        CheckoutStep.fulfilment,
        CheckoutStep.slot,
        CheckoutStep.payment,
      ]);
      expect(flow.totalSteps, 3);
    });

    test('advances straight from fulfilment to slot', () {
      const flow = CheckoutFlow.start(isSelfPickup: true);

      expect(flow.advance().current, CheckoutStep.slot);
    });

    test('position counts within the pickup flow, not the delivery one', () {
      // "Step 2 of 3" for pickup, not "step 3 of 4" — the screen previously
      // derived this from a shared int index, so the same index meant different
      // things depending on fulfilment method.
      const flow = CheckoutFlow(current: CheckoutStep.slot, isSelfPickup: true);

      expect(flow.position, 2);
      expect(flow.totalSteps, 3);
      expect(flow.progress, closeTo(2 / 3, 0.001));
    });
  });

  group('switching fulfilment mid-flow', () {
    test('keeps the current step when it still applies', () {
      const flow = CheckoutFlow(current: CheckoutStep.slot);

      expect(flow.withFulfilment(isSelfPickup: true).current, CheckoutStep.slot);
    });

    test('rewinds when the current step no longer exists', () {
      // On the address step, switching to pickup removes that step entirely.
      // Without this the flow strands on a step not in its own list.
      const flow = CheckoutFlow(current: CheckoutStep.address);

      final switched = flow.withFulfilment(isSelfPickup: true);
      expect(switched.current, CheckoutStep.fulfilment);
      expect(switched.steps.contains(switched.current), isTrue);
    });

    test('every reachable step is always within the flow', () {
      for (final pickup in [true, false]) {
        for (final step in CheckoutStep.values) {
          final flow =
              CheckoutFlow(current: step, isSelfPickup: !pickup)
                  .withFulfilment(isSelfPickup: pickup);
          expect(flow.steps.contains(flow.current), isTrue,
              reason: 'pickup=$pickup step=$step');
        }
      }
    });
  });

  group('PaymentRequest', () {
    test('converts rupees to paise by rounding, not truncating', () {
      // (19.99 * 100).toInt() is 1998 on a double — a paisa short, which the
      // gateway rejects as an amount mismatch.
      expect(
        const PaymentRequest(
          amount: 19.99,
          orderReference: 'O1',
          customerName: 'A',
          customerPhone: '9',
        ).amountInPaise,
        1999,
      );
    });

    test('handles whole rupees', () {
      expect(
        const PaymentRequest(
          amount: 250,
          orderReference: 'O1',
          customerName: 'A',
          customerPhone: '9',
        ).amountInPaise,
        25000,
      );
    });

    test('toString does not leak customer contact details', () {
      const request = PaymentRequest(
        amount: 100,
        orderReference: 'O1',
        customerName: 'Jane Doe',
        customerPhone: '9876543210',
        customerEmail: 'jane@example.com',
      );

      final text = request.toString();
      expect(text, isNot(contains('9876543210')));
      expect(text, isNot(contains('jane@example.com')));
    });
  });

  group('PaymentOutcome', () {
    test('cancellation is distinct from failure', () {
      // Razorpay reports a dismissed sheet through its error callback. Treating
      // it as a failure marks the order failed and shows an error dialog for
      // something the customer did on purpose.
      const PaymentOutcome cancelled = PaymentCancelled();
      const PaymentOutcome failed =
          PaymentFailed(code: '1', message: 'Card declined');

      expect(cancelled, isA<PaymentCancelled>());
      expect(cancelled, isNot(isA<PaymentFailed>()));
      expect(failed, isA<PaymentFailed>());
    });

    test('a switch over outcomes is exhaustive', () {
      String describe(PaymentOutcome outcome) => switch (outcome) {
            PaymentSucceeded(:final paymentId) => 'ok:$paymentId',
            PaymentFailed(:final code) => 'fail:$code',
            PaymentCancelled() => 'cancelled',
          };

      expect(
        describe(const PaymentSucceeded(
            paymentId: 'p1', orderReference: 'o1', signature: 's')),
        'ok:p1',
      );
      expect(describe(const PaymentFailed(code: '5', message: '')), 'fail:5');
      expect(describe(const PaymentCancelled()), 'cancelled');
    });

    test('an empty gateway message falls back to readable copy', () {
      expect(
        const PaymentFailed(code: '1', message: '   ').userMessage,
        isNotEmpty,
      );
      expect(
        const PaymentFailed(code: '1', message: 'Card declined').userMessage,
        'Card declined',
      );
    });

    test('success toString does not leak the signature', () {
      const outcome = PaymentSucceeded(
        paymentId: 'pay_1',
        orderReference: 'o1',
        signature: 'super-secret-signature',
      );

      expect(outcome.toString(), isNot(contains('super-secret-signature')));
    });
  });

  group('cancellation vs failure — the distinction that was missing', () {
    // PaymentResult.success was false for both a declined card and a dismissed
    // sheet, and payment_step's else-branch wrote "Payment Failed" to the
    // database for both. These pin the two apart.
    test('a dismissed sheet is not a failure', () {
      const PaymentOutcome outcome = PaymentCancelled();

      expect(outcome, isA<PaymentCancelled>());
      expect(outcome is PaymentFailed, isFalse);
    });

    test('a declined card is a failure with a code', () {
      const outcome = PaymentFailed(code: '1', message: 'Card declined');

      expect(outcome.code, '1');
      expect(outcome.userMessage, 'Card declined');
    });

    test('handling must be exhaustive, so neither case can be forgotten', () {
      bool marksOrderFailed(PaymentOutcome o) => switch (o) {
            PaymentSucceeded() => false,
            PaymentCancelled() => false,
            PaymentFailed() => true,
          };

      expect(marksOrderFailed(const PaymentCancelled()), isFalse);
      expect(
        marksOrderFailed(const PaymentFailed(code: '1', message: 'x')),
        isTrue,
      );
    });
  });

  group('PaymentMethod', () {
    test('only online payment is prepaid', () {
      expect(PaymentMethod.online.isPrepaid, isTrue);
      expect(PaymentMethod.cashOnDelivery.isPrepaid, isFalse);
    });
  });
}
