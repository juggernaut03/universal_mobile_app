// lib/data/models/cart_offer_model.dart
//
// A discount offer (models/Offer.js): cart_discount (flat/% off the whole
// cart), category_discount (off matching departments/categories/brands) or
// buy_x_get_y. See GET /api/offers/for-cart's `offers`/`best_offer` fields,
// and POST /api/offers/apply-coupon for coupon-code offers. Distinct from
// product_deal offers (steal_deals_provider.dart's StealDealOffer), which
// unlock specific SKUs at a deal price instead of discounting the cart.

class CartOffer {
  final String id;
  final String title;
  final String description;

  /// cart_discount, category_discount or buy_x_get_y.
  final String offerType;

  /// Set when this offer came from a coupon the shopper entered.
  final String? couponCode;

  /// Why a locked offer is locked ("Add ₹120 more to unlock", "Add 3
  /// eligible items to unlock") — null once unlocked.
  final String? lockedReason;

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
    this.offerType = 'cart_discount',
    this.couponCode,
    this.lockedReason,
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
      offerType: (json['offer_type'] ?? 'cart_discount').toString(),
      couponCode: json['coupon_code']?.toString(),
      lockedReason: json['locked_reason']?.toString(),
      effectiveDiscount: (json['effective_discount'] as num?)?.toDouble() ?? 0,
      minCartValue: (json['min_cart_value'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      unlocked: json['unlocked'] == true,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A free_delivery offer (models/Offer.js): waives the distance-based
/// delivery fee once [minCartValue] is reached. Comes from GET
/// /api/offers/for-cart's `free_delivery_offer`, or from a free-delivery
/// coupon via POST /api/offers/apply-coupon. Stacks with a [CartOffer].
class FreeDeliveryOffer {
  final String id;
  final String title;
  final String? couponCode;
  final double minCartValue;
  final double remainingAmount;
  final bool unlocked;
  final int progress;

  const FreeDeliveryOffer({
    required this.id,
    required this.title,
    this.couponCode,
    required this.minCartValue,
    required this.remainingAmount,
    required this.unlocked,
    required this.progress,
  });

  factory FreeDeliveryOffer.fromJson(Map<String, dynamic> json) {
    return FreeDeliveryOffer(
      id: (json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      couponCode: json['coupon_code']?.toString(),
      minCartValue: (json['min_cart_value'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      unlocked: json['unlocked'] == true,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A coupon code the shopper entered and the server accepted. Exactly one
/// of [discountOffer] / [freeDeliveryOffer] is set, depending on the
/// coupon's offer type.
class AppliedCoupon {
  final String code;
  final CartOffer? discountOffer;
  final FreeDeliveryOffer? freeDeliveryOffer;

  const AppliedCoupon({required this.code, this.discountOffer, this.freeDeliveryOffer});

  factory AppliedCoupon.fromJson(String code, Map<String, dynamic> json) {
    final isFreeDelivery = json['offer_type'] == 'free_delivery';
    return AppliedCoupon(
      code: code,
      discountOffer: isFreeDelivery ? null : CartOffer.fromJson(json),
      freeDeliveryOffer: isFreeDelivery ? FreeDeliveryOffer.fromJson(json) : null,
    );
  }
}
