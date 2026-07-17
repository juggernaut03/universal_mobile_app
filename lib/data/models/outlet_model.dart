// lib/data/models/outlet_model.dart

class OutletModel {
  final String id;
  final String name;
  final String storeCode;
  final String address;
  final int minOrderAmount;
  final String openTime;
  final String deliveryTime;
  final String offerName;
  final String latitude;
  final String longitude;
  final bool homeDelivery;
  final bool selfPickup;
  final String contactPhone;
  final String storeMessage;
  final bool isEnabled;

  OutletModel({
    required this.id,
    required this.name,
    required this.storeCode,
    required this.address,
    required this.minOrderAmount,
    required this.openTime,
    required this.deliveryTime,
    required this.offerName,
    required this.latitude,
    required this.longitude,
    this.homeDelivery = true,
    this.selfPickup = false,
    this.contactPhone = '',
    this.storeMessage = '',
    this.isEnabled = true,
  });

  // Parses the universal backend's /api/stores/by-pincode shape
  // (store_name, location{}, delivery_options{}, contact{}) and falls back to
  // the flat legacy keys so outlets cached by toJson() keep loading.
  factory OutletModel.fromJson(Map<String, dynamic> json) {
    final location = json['location'] is Map<String, dynamic>
        ? json['location'] as Map<String, dynamic>
        : <String, dynamic>{};
    final deliveryOptions = json['delivery_options'] is Map<String, dynamic>
        ? json['delivery_options'] as Map<String, dynamic>
        : <String, dynamic>{};
    final contact = json['contact'] is Map<String, dynamic>
        ? json['contact'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawMinOrder = json['min_order_amount'];
    final int minOrder = rawMinOrder is int
        ? rawMinOrder
        : rawMinOrder is num
            ? rawMinOrder.toInt()
            : int.tryParse(rawMinOrder?.toString() ?? '') ?? 0;

    return OutletModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['store_name'] ?? json['mobile_outlet_name'] ?? '',
      storeCode: json['store_code'] ?? '',
      address: json['address'] ?? json['store_address'] ?? '',
      minOrderAmount: minOrder,
      openTime: json['store_open_time'] ?? '',
      deliveryTime: json['delivery_time'] ?? json['store_delivery_time'] ?? '',
      offerName: json['offer'] ?? json['store_offer_name'] ?? '',
      latitude: (location['latitude'] ?? json['latitude'] ?? '').toString(),
      longitude: (location['longitude'] ?? json['longitude'] ?? '').toString(),
      homeDelivery: deliveryOptions['home_delivery'] is bool
          ? deliveryOptions['home_delivery'] as bool
          : json['home_delivery'] is bool
              ? json['home_delivery'] as bool
              : true,
      selfPickup: deliveryOptions['self_pickup'] is bool
          ? deliveryOptions['self_pickup'] as bool
          : json['self_pickup'] is bool
              ? json['self_pickup'] as bool
              : false,
      contactPhone: (contact['phone'] ?? json['contact_phone'] ?? '').toString(),
      storeMessage: (json['message'] ?? json['store_message'] ?? '').toString(),
      isEnabled: json['is_enabled'] == null
          ? true
          : json['is_enabled'] == true || json['is_enabled'] == 'Enabled',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'mobile_outlet_name': name,
      'store_code': storeCode,
      'store_address': address,
      'min_order_amount': minOrderAmount,
      'store_open_time': openTime,
      'store_delivery_time': deliveryTime,
      'store_offer_name': offerName,
      'latitude': latitude,
      'longitude': longitude,
      'home_delivery': homeDelivery,
      'self_pickup': selfPickup,
      'contact_phone': contactPhone,
      'store_message': storeMessage,
      'is_enabled': isEnabled,
    };
  }
}