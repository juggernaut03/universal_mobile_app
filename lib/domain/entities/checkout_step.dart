// lib/domain/entities/checkout_step.dart
//
// The checkout flow as an explicit state machine.
//
// checkout_flow_screen.dart is 4,708 lines holding four step widgets and the
// transitions between them, driven by an int index and scattered setState
// calls. Which steps are reachable, and in what order, is not stated anywhere —
// it is implied by the widget tree.

import 'package:meta/meta.dart';

/// A stage of checkout.
enum CheckoutStep {
  /// Choose home delivery or store pickup.
  fulfilment,

  /// Choose the delivery address. Skipped for pickup orders.
  address,

  /// Choose a delivery slot.
  slot,

  /// Choose a payment method and pay.
  payment;

  /// Position shown in the progress bar, 1-based.
  int get displayPosition => index + 1;

  String get title => switch (this) {
        CheckoutStep.fulfilment => 'Delivery method',
        CheckoutStep.address => 'Delivery address',
        CheckoutStep.slot => 'Delivery time',
        CheckoutStep.payment => 'Payment',
      };
}

/// Which steps apply to an order, and how to move between them.
///
/// Pickup orders skip the address step. That rule was previously expressed by
/// index arithmetic inside the screen, so "step 3" meant a different thing
/// depending on fulfilment method.
@immutable
final class CheckoutFlow {
  /// Whether the order is collected in store rather than delivered.
  final bool isSelfPickup;

  final CheckoutStep current;

  const CheckoutFlow({
    required this.current,
    this.isSelfPickup = false,
  });

  const CheckoutFlow.start({bool isSelfPickup = false})
      : this(current: CheckoutStep.fulfilment, isSelfPickup: isSelfPickup);

  /// The steps this order actually goes through.
  List<CheckoutStep> get steps => isSelfPickup
      ? const [CheckoutStep.fulfilment, CheckoutStep.slot, CheckoutStep.payment]
      : const [
          CheckoutStep.fulfilment,
          CheckoutStep.address,
          CheckoutStep.slot,
          CheckoutStep.payment,
        ];

  int get totalSteps => steps.length;

  /// Position of [current] within [steps], 1-based.
  int get position => steps.indexOf(current) + 1;

  bool get isFirst => position <= 1;
  bool get isLast => position >= totalSteps;

  /// Progress through the flow, 0.0 to 1.0.
  double get progress => totalSteps == 0 ? 0 : position / totalSteps;

  /// The next step, or null when already at payment.
  CheckoutStep? get nextStep {
    final i = steps.indexOf(current);
    return i >= 0 && i < steps.length - 1 ? steps[i + 1] : null;
  }

  /// The previous step, or null when at the start.
  CheckoutStep? get previousStep {
    final i = steps.indexOf(current);
    return i > 0 ? steps[i - 1] : null;
  }

  CheckoutFlow advance() {
    final next = nextStep;
    return next == null ? this : CheckoutFlow(current: next, isSelfPickup: isSelfPickup);
  }

  CheckoutFlow goBack() {
    final previous = previousStep;
    return previous == null
        ? this
        : CheckoutFlow(current: previous, isSelfPickup: isSelfPickup);
  }

  /// Switches fulfilment method, keeping the flow on a step that still exists.
  ///
  /// Switching to pickup while on the address step would otherwise strand the
  /// flow on a step that is no longer part of it.
  CheckoutFlow withFulfilment({required bool isSelfPickup}) {
    final updated = CheckoutFlow(current: current, isSelfPickup: isSelfPickup);
    if (updated.steps.contains(current)) return updated;
    return CheckoutFlow(current: CheckoutStep.fulfilment, isSelfPickup: isSelfPickup);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutFlow &&
          other.current == current &&
          other.isSelfPickup == isSelfPickup;

  @override
  int get hashCode => Object.hash(current, isSelfPickup);

  @override
  String toString() => 'CheckoutFlow($current, $position/$totalSteps)';
}
