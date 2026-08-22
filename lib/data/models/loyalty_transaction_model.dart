// lib/data/models/loyalty_transaction_model.dart
//
// One ledger row (models/LoyaltyTransaction.js). See
// GET /api/loyalty/transactions.

class LoyaltyTransaction {
  final String id;
  final String type; // CREDIT | DEBIT | EXPIRATION | REVERSAL | ADJUSTMENT
  final String source;
  final int points;
  final String status; // PENDING | COMPLETED | REVERSED
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.source,
    required this.points,
    required this.status,
    required this.createdAt,
    required this.metadata,
  });

  bool get isCredit => type == 'CREDIT';

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : const {},
    );
  }
}
