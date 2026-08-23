// lib/data/models/loyalty_redemption_model.dart
//
// An issued voucher from redeeming points for a reward
// (models/LoyaltyRedemption.js). See GET /api/loyalty/redemptions/active
// and POST /api/loyalty/rewards/:id/redeem.

class LoyaltyRedemption {
  final String id;
  final String rewardName;
  final String rewardType;
  final double discountValue;
  final double? maximumDiscount;
  final double minimumOrderValue;
  final String couponCode;
  final int pointsSpent;
  final DateTime expiresAt;

  const LoyaltyRedemption({
    required this.id,
    required this.rewardName,
    required this.rewardType,
    required this.discountValue,
    required this.maximumDiscount,
    required this.minimumOrderValue,
    required this.couponCode,
    required this.pointsSpent,
    required this.expiresAt,
  });

  factory LoyaltyRedemption.fromJson(Map<String, dynamic> json) {
    final snapshot = json['rewardSnapshot'] is Map
        ? Map<String, dynamic>.from(json['rewardSnapshot'] as Map)
        : const <String, dynamic>{};
    return LoyaltyRedemption(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      rewardName: (snapshot['name'] ?? json['rewardName'] ?? 'Reward').toString(),
      rewardType: (snapshot['type'] ?? '').toString(),
      discountValue: (snapshot['discountValue'] as num?)?.toDouble() ?? 0,
      maximumDiscount: (snapshot['maximumDiscount'] as num?)?.toDouble(),
      minimumOrderValue: (snapshot['minimumOrderValue'] as num?)?.toDouble() ?? 0,
      couponCode: (json['couponCode'] ?? '').toString(),
      pointsSpent: (json['pointsSpent'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Display-only estimate of the discount this voucher would produce
  /// against [orderSubtotal]/[deliveryCharges] right now - mirrors
  /// previewRedemptionDiscount() in the backend's utils/loyaltyRedemption.js
  /// so the checkout summary shows the same number the server will actually
  /// apply. Not authoritative: place-order recomputes this itself from the
  /// voucher id, exactly like every other total on this screen is a client
  /// estimate the server re-derives (see finalAmount in payment_step.dart).
  ///
  /// Returns null if [orderSubtotal] doesn't meet minimumOrderValue, or for
  /// FREE_PRODUCT/SPECIAL_OFFER (fulfilled manually, no checkout-time amount)
  /// - callers should treat null as "can't apply this voucher right now".
  double? estimateDiscount({required double orderSubtotal, double deliveryCharges = 0}) {
    if (orderSubtotal < minimumOrderValue) return null;

    switch (rewardType) {
      case 'FIXED_DISCOUNT':
      case 'CASHBACK':
        return discountValue;
      case 'PERCENTAGE_DISCOUNT':
        var amount = orderSubtotal * discountValue / 100;
        if (maximumDiscount != null) amount = amount > maximumDiscount! ? maximumDiscount! : amount;
        return amount;
      case 'FREE_SHIPPING':
        return deliveryCharges;
      default:
        return null;
    }
  }
}
