class OutletStatus {
  final String id;
  final bool isEnabled;
  final String storeMessage;
  final bool homeDeliveryAvailable;
  final bool selfPickupAvailable;

  OutletStatus({
    required this.id,
    required this.isEnabled,
    required this.storeMessage,
    required this.homeDeliveryAvailable,
    required this.selfPickupAvailable,
  });

  factory OutletStatus.fromJson(Map<String, dynamic> json) {
    return OutletStatus(
      id: json['_id'] ?? '',
      isEnabled: (json['is_enabled'] ?? '').toString().toLowerCase() != 'disabled',
      storeMessage: json['store_message'] ?? '',
      homeDeliveryAvailable: (json['home_delivery'] ?? 'no').toLowerCase() == 'yes',
      selfPickupAvailable: (json['self_pickup'] ?? 'no').toLowerCase() == 'yes',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'is_enabled': isEnabled ? 'Enabled' : 'Disabled',
      'store_message': storeMessage,
      'home_delivery': homeDeliveryAvailable ? 'yes' : 'no',
      'self_pickup': selfPickupAvailable ? 'yes' : 'no',
    };
  }

  // Helper getters for business logic
  bool get hasAnyServiceAvailable => homeDeliveryAvailable || selfPickupAvailable;
  bool get isFullyOperational => isEnabled && hasAnyServiceAvailable;
  bool get hasDeliveryOnly => homeDeliveryAvailable && !selfPickupAvailable;
  bool get hasPickupOnly => selfPickupAvailable && !homeDeliveryAvailable;
  bool get hasBothServices => homeDeliveryAvailable && selfPickupAvailable;

  // Get available delivery methods as a list
  List<String> get availableDeliveryMethods {
    List<String> methods = [];
    if (homeDeliveryAvailable) methods.add('Home Delivery');
    if (selfPickupAvailable) methods.add('Store Pickup');
    return methods;
  }

  // Get status message for UI display
  String get statusMessage {
    if (!isEnabled) {
      return storeMessage.isNotEmpty 
          ? storeMessage 
          : 'This outlet is temporarily closed';
    }
    
    if (!hasAnyServiceAvailable) {
      return storeMessage.isNotEmpty 
          ? storeMessage 
          : 'No delivery services currently available';
    }
    
    if (hasDeliveryOnly) {
      return 'Only Home Delivery is available';
    }
    
    if (hasPickupOnly) {
      return 'Only Store Pickup is available';
    }
    
    return 'All services are available';
  }

  @override
  String toString() {
    return 'OutletStatus(id: $id, enabled: $isEnabled, homeDelivery: $homeDeliveryAvailable, pickup: $selfPickupAvailable)';
  }
}