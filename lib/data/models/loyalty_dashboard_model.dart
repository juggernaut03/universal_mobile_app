// lib/data/models/loyalty_dashboard_model.dart
//
// The full loyalty dashboard payload. See GET /api/loyalty.

import 'loyalty_tier_model.dart';
import 'loyalty_reward_model.dart';
import 'loyalty_challenge_model.dart';
import 'loyalty_transaction_model.dart';

class LoyaltyReferralSummary {
  final String code;
  final int? successfulReferrals;
  final int? earnedPoints;

  const LoyaltyReferralSummary({required this.code, required this.successfulReferrals, required this.earnedPoints});

  factory LoyaltyReferralSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LoyaltyReferralSummary(code: '', successfulReferrals: null, earnedPoints: null);
    return LoyaltyReferralSummary(
      code: (json['code'] ?? '').toString(),
      successfulReferrals: (json['successfulReferrals'] as num?)?.toInt(),
      earnedPoints: (json['earnedPoints'] as num?)?.toInt(),
    );
  }
}

class LoyaltyDashboard {
  final int availablePoints;
  final int pendingPoints;
  final LoyaltyTierStatus tier;
  final List<LoyaltyReward> rewards;
  final List<LoyaltyChallenge> challenges;
  final LoyaltyReferralSummary referral;
  final List<LoyaltyTransaction> recentTransactions;

  const LoyaltyDashboard({
    required this.availablePoints,
    required this.pendingPoints,
    required this.tier,
    required this.rewards,
    required this.challenges,
    required this.referral,
    required this.recentTransactions,
  });

  factory LoyaltyDashboard.fromJson(Map<String, dynamic> json) {
    final points = json['points'] is Map ? Map<String, dynamic>.from(json['points'] as Map) : const {};
    return LoyaltyDashboard(
      availablePoints: (points['available'] as num?)?.toInt() ?? 0,
      pendingPoints: (points['pending'] as num?)?.toInt() ?? 0,
      tier: LoyaltyTierStatus.fromJson(json['tier'] is Map ? Map<String, dynamic>.from(json['tier'] as Map) : null),
      rewards: json['rewards'] is List
          ? (json['rewards'] as List).whereType<Map>().map((e) => LoyaltyReward.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
      challenges: json['challenges'] is List
          ? (json['challenges'] as List).whereType<Map>().map((e) => LoyaltyChallenge.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
      referral: LoyaltyReferralSummary.fromJson(
        json['referral'] is Map ? Map<String, dynamic>.from(json['referral'] as Map) : null,
      ),
      recentTransactions: json['recentTransactions'] is List
          ? (json['recentTransactions'] as List)
              .whereType<Map>()
              .map((e) => LoyaltyTransaction.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  static const empty = LoyaltyDashboard(
    availablePoints: 0,
    pendingPoints: 0,
    tier: LoyaltyTierStatus(code: null, name: null, multiplier: 1, currentSpend: 0, nextTier: null, nextTierSpend: null, progress: 0),
    rewards: [],
    challenges: [],
    referral: LoyaltyReferralSummary(code: '', successfulReferrals: null, earnedPoints: null),
    recentTransactions: [],
  );
}
