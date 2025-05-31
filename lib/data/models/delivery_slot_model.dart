// lib/data/models/delivery_slot_model.dart

class DeliverySlot {
  final int id;
  final String slotFrom;
  final String slotTo;
  final bool isActive;

  DeliverySlot({
    required this.id,
    required this.slotFrom,
    required this.slotTo,
    required this.isActive,
  });

  factory DeliverySlot.fromJson(Map<String, dynamic> json) {
    return DeliverySlot(
      id: json['iddelivery_slot'] ?? 0,
      slotFrom: json['delivery_slot_from'] ?? '',
      slotTo: json['delivery_slot_to'] ?? '',
      isActive: (json['is_active'] ?? 'no').toLowerCase() == 'yes',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iddelivery_slot': id,
      'delivery_slot_from': slotFrom,
      'delivery_slot_to': slotTo,
      'is_active': isActive ? 'yes' : 'no',
    };
  }

  // Get formatted time slot string for display
  String get displayText {
    return '$slotFrom - $slotTo';
  }

  // Get slot ID as string for storage/comparison
  String get slotId {
    return id.toString();
  }

  @override
  String toString() {
    return displayText;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliverySlot &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}