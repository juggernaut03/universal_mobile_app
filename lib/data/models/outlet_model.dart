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
  });

  factory OutletModel.fromJson(Map<String, dynamic> json) {
    return OutletModel(
      id: json['_id'] ?? '',
      name: json['mobile_outlet_name'] ?? '',
      storeCode: json['store_code'] ?? '',
      address: json['store_address'] ?? '',
      minOrderAmount: json['min_order_amount'] ?? 0,
      openTime: json['store_open_time'] ?? '',
      deliveryTime: json['store_delivery_time'] ?? '',
      offerName: json['store_offer_name'] ?? '',
      latitude: json['latitude'] ?? '',
      longitude: json['longitude'] ?? '',
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
    };
  }
}