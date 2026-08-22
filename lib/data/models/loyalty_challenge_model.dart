// lib/data/models/loyalty_challenge_model.dart
//
// A gamified challenge (models/LoyaltyChallenge.js) plus this customer's
// progress against it, if any (models/LoyaltyChallengeProgress.js). See
// GET /api/loyalty/challenges.

class LoyaltyChallenge {
  final String id;
  final String name;
  final String description;
  final String type;
  final int targetValue;
  final int rewardPoints;
  final DateTime validUntil;
  final int currentValue;
  final String progressStatus; // IN_PROGRESS | COMPLETED | CLAIMED | EXPIRED | NOT_STARTED

  const LoyaltyChallenge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.rewardPoints,
    required this.validUntil,
    required this.currentValue,
    required this.progressStatus,
  });

  bool get isCompleted => progressStatus == 'COMPLETED';
  bool get isClaimed => progressStatus == 'CLAIMED';
  double get progressFraction => targetValue > 0 ? (currentValue / targetValue).clamp(0, 1) : 0;

  factory LoyaltyChallenge.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'];
    final progressMap = progress is Map ? Map<String, dynamic>.from(progress) : null;
    return LoyaltyChallenge(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      targetValue: (json['targetValue'] as num?)?.toInt() ?? 1,
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? '') ?? DateTime.now(),
      currentValue: (progressMap?['currentValue'] as num?)?.toInt() ?? 0,
      progressStatus: (progressMap?['status'] ?? 'NOT_STARTED').toString(),
    );
  }
}
