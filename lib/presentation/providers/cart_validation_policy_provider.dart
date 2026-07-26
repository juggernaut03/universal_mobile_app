// lib/presentation/providers/cart_validation_policy_provider.dart
//
// Checkout eligibility, derived from the single CartValidationPolicy.
//
// Replaces the rule that lived in cart_screen's build method:
//
//     outlet?.minOrderAmount.toDouble() ?? 499.0   // Default to 499
//
// — a business threshold invented in a widget, applied when no outlet had
// loaded yet, and duplicated across the loading and error branches. A cart
// cannot be judged before its outlet is known, so "unknown" is now its own
// state rather than a guessed number.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../domain/entities/cart_validation.dart';
import 'cart_provider.dart';
import 'outlet_provider.dart';

/// The rule set. Exposed so a test or a build flavour can substitute it.
final cartValidationPolicyProvider =
    Provider<CartValidationPolicy>((ref) => const CartValidationPolicy());

/// Current verdict on the cart, or null while the outlet is still loading.
///
/// Null means "not yet knowable" — distinct from "invalid", which the old
/// hardcoded default conflated by treating an unloaded outlet as a ₹499 floor.
final cartValidationProvider = Provider<CartValidation?>((ref) {
  final outlet = ref.watch(selectedOutletProvider).valueOrNull;
  if (outlet == null) return null;

  final cart = ref.watch(cartItemsProvider).toCart(outlet.storeCode);

  return ref.watch(cartValidationPolicyProvider).validate(
        cart: cart,
        outlet: outlet.toEntity(),
      );
});

/// Whether checkout may proceed. False while the outlet is unknown.
final canCheckoutProvider = Provider<bool>((ref) {
  return ref.watch(cartValidationProvider)?.isValid ?? false;
});

/// The single most relevant problem to show, or null when the cart is fine.
final cartProblemProvider = Provider<CartProblem?>((ref) {
  return ref.watch(cartValidationProvider)?.primary;
});
