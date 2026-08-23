// lib/data/models/loyalty_way_to_earn_model.dart
//
// One earning rule, formatted for customer display (as opposed to the admin
// panel's raw LoyaltyRule shape). See the dashboard's `waysToEarn` field,
// GET /api/loyalty.

class LoyaltyWayToEarn {
  final String code;
  final String label;
  final int points;
  final String description;

  const LoyaltyWayToEarn({
    required this.code,
    required this.label,
    required this.points,
    required this.description,
  });

  factory LoyaltyWayToEarn.fromJson(Map<String, dynamic> json) {
    return LoyaltyWayToEarn(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: (json['description'] ?? '').toString(),
    );
  }
}
