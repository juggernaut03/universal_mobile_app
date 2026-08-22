// lib/data/models/loyalty_tier_model.dart
//
// A VIP tier definition (models/LoyaltyTier.js). See GET /api/loyalty/tiers.

class LoyaltyTier {
  final String code;
  final String name;
  final double minimumSpend;
  final double? maximumSpend;
  final double pointMultiplier;

  const LoyaltyTier({
    required this.code,
    required this.name,
    required this.minimumSpend,
    required this.maximumSpend,
    required this.pointMultiplier,
  });

  factory LoyaltyTier.fromJson(Map<String, dynamic> json) {
    return LoyaltyTier(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      minimumSpend: (json['minimumSpend'] as num?)?.toDouble() ?? 0,
      maximumSpend: (json['maximumSpend'] as num?)?.toDouble(),
      pointMultiplier: (json['pointMultiplier'] as num?)?.toDouble() ?? 1,
    );
  }
}

/// The current customer's tier standing, embedded in the dashboard response.
class LoyaltyTierStatus {
  final String? code;
  final String? name;
  final double multiplier;
  final double currentSpend;
  final String? nextTier;
  final double? nextTierSpend;
  final int progress;

  const LoyaltyTierStatus({
    required this.code,
    required this.name,
    required this.multiplier,
    required this.currentSpend,
    required this.nextTier,
    required this.nextTierSpend,
    required this.progress,
  });

  factory LoyaltyTierStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LoyaltyTierStatus(
        code: null, name: null, multiplier: 1, currentSpend: 0, nextTier: null, nextTierSpend: null, progress: 0,
      );
    }
    return LoyaltyTierStatus(
      code: json['code']?.toString(),
      name: json['name']?.toString(),
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1,
      currentSpend: (json['currentSpend'] as num?)?.toDouble() ?? 0,
      nextTier: json['nextTier']?.toString(),
      nextTierSpend: (json['nextTierSpend'] as num?)?.toDouble(),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
    );
  }
}
