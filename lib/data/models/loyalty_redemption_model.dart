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
}
