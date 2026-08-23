// lib/data/models/cart_offer_model.dart
//
// A cart-level discount offer (models/Offer.js, offer_type: 'cart_discount')
// — flat/% off the whole cart once min_cart_value is hit. See GET
// /api/offers/for-cart's `offers`/`best_offer` fields. Distinct from
// product_deal offers (steal_deals_provider.dart's StealDealOffer), which
// unlock specific SKUs at a deal price instead of discounting the cart.
//
// No coupon code anywhere - like the loyalty rewards this app already
// supports, this is a tap-to-apply list, never a text field.

class CartOffer {
  final String id;
  final String title;
  final String description;

  /// Already computed by the server (flat, or % capped at max_discount) -
  /// trusted verbatim, same as the web PWA does, never recomputed here.
  final double effectiveDiscount;

  final double minCartValue;

  /// How much more the cart needs to reach [minCartValue] - 0 once unlocked.
  final double remainingAmount;
  final bool unlocked;

  /// 0-100, how far toward [minCartValue] the current cart is.
  final int progress;

  const CartOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.effectiveDiscount,
    required this.minCartValue,
    required this.remainingAmount,
    required this.unlocked,
    required this.progress,
  });

  factory CartOffer.fromJson(Map<String, dynamic> json) {
    return CartOffer(
      id: (json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      effectiveDiscount: (json['effective_discount'] as num?)?.toDouble() ?? 0,
      minCartValue: (json['min_cart_value'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      unlocked: json['unlocked'] == true,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
    );
  }
}
