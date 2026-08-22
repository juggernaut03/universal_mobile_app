// lib/data/models/loyalty_reward_model.dart
//
// A redeemable catalog entry from the universal backend
// (models/LoyaltyReward.js). See GET /api/loyalty/rewards.

class LoyaltyReward {
  final String id;
  final String name;
  final String description;
  final String? image;
  final String type;
  final int pointsRequired;
  final double discountValue;
  final double minimumOrderValue;
  final double? maximumDiscount;
  final List<String> applicableTiers;

  const LoyaltyReward({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.type,
    required this.pointsRequired,
    required this.discountValue,
    required this.minimumOrderValue,
    required this.maximumDiscount,
    required this.applicableTiers,
  });

  factory LoyaltyReward.fromJson(Map<String, dynamic> json) {
    return LoyaltyReward(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      image: json['image']?.toString(),
      type: (json['type'] ?? 'FIXED_DISCOUNT').toString(),
      pointsRequired: (json['pointsRequired'] as num?)?.toInt() ?? 0,
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
      minimumOrderValue: (json['minimumOrderValue'] as num?)?.toDouble() ?? 0,
      maximumDiscount: (json['maximumDiscount'] as num?)?.toDouble(),
      applicableTiers: json['applicableTiers'] is List
          ? List<String>.from((json['applicableTiers'] as List).map((e) => e.toString()))
          : const [],
    );
  }
}
