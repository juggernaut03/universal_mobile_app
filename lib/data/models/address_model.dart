// lib/data/models/address_model.dart

import '../../domain/entities/customer_address.dart';
import '../../domain/entities/outlet.dart' show GeoPoint;

class Address {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String emailId;
  final String deliveryAddrLine1;
  final String deliveryAddrLine2;
  final String deliveryAddrCity;
  final String deliveryAddrPincode;
  final String isDefault;
  final String areaId;
  final String landmark;
  final String state;
  final String? latitude;  // Added latitude field
  final String? longitude; // Added longitude field

  Address({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.emailId,
    required this.deliveryAddrLine1,
    required this.deliveryAddrLine2,
    required this.deliveryAddrCity,
    required this.deliveryAddrPincode,
    required this.isDefault,
    required this.areaId,
    this.landmark = '',
    this.state = '',
    this.latitude = '',  // Default to empty string
    this.longitude = '', // Default to empty string
  });

  // Updated fromJson to handle multiple API response field formats
  factory Address.fromJson(Map<String, dynamic> json) {
    // Handle various ID formats that might be in the response
    String addressId = '';
    if (json.containsKey('_id')) {
      addressId = json['_id'];
    } else if (json.containsKey('id')) {
      addressId = json['id'];
    } else if (json.containsKey('idaddress_book')) {
      addressId = json['idaddress_book'];
    }

    // Handle different field mappings in the API response
    String mobileNumber = '';
    if (json.containsKey('mobile_number')) {
      mobileNumber = json['mobile_number'];
    } else if (json.containsKey('contact_no')) {
      mobileNumber = json['contact_no'];
    }

    String emailId = '';
    if (json.containsKey('email_id')) {
      emailId = json['email_id'];
    } else if (json.containsKey('email')) {
      emailId = json['email'];
    }

    String deliveryAddrLine1 = '';
    if (json.containsKey('delivery_addr_line_1')) {
      deliveryAddrLine1 = json['delivery_addr_line_1'];
    } else if (json.containsKey('address_1')) {
      deliveryAddrLine1 = json['address_1'];
    }

    String deliveryAddrLine2 = '';
    if (json.containsKey('delivery_addr_line_2')) {
      deliveryAddrLine2 = json['delivery_addr_line_2'];
    } else if (json.containsKey('address_2')) {
      deliveryAddrLine2 = json['address_2'];
    }

    String deliveryAddrCity = '';
    if (json.containsKey('delivery_addr_city')) {
      deliveryAddrCity = json['delivery_addr_city'];
    } else if (json.containsKey('city')) {
      deliveryAddrCity = json['city'];
    }

    String deliveryAddrPincode = '';
    if (json.containsKey('delivery_addr_pincode')) {
      deliveryAddrPincode = json['delivery_addr_pincode'];
    } else if (json.containsKey('pincode')) {
      deliveryAddrPincode = json['pincode'];
    }

    String areaId = '';
    if (json.containsKey('area_id')) {
      areaId = json['area_id'];
    } else if (json.containsKey('area')) {
      areaId = json['area'];
    } else {
      areaId = '1'; // Default area ID
    }

    String landmarkValue = '';
    if (json.containsKey('landmark')) {
      landmarkValue = json['landmark'];
    } else if (json.containsKey('landmart')) { // Note the typo in API
      landmarkValue = json['landmart'];
    }
    
    // Extract latitude and longitude if available
    String? latitude = '';
    if (json.containsKey('latitude')) {
      latitude = json['latitude']?.toString() ?? '';
    }
    
    String? longitude = '';
    if (json.containsKey('longitude')) {
      longitude = json['longitude']?.toString() ?? '';
    }

    return Address(
      id: addressId,
      fullName: json['full_name'] ?? '',
      mobileNumber: mobileNumber,
      emailId: emailId,
      deliveryAddrLine1: deliveryAddrLine1,
      deliveryAddrLine2: deliveryAddrLine2,
      deliveryAddrCity: deliveryAddrCity,
      deliveryAddrPincode: deliveryAddrPincode,
      isDefault: json['is_default'] ?? 'No',
      areaId: areaId,
      landmark: landmarkValue,
      state: json['state'] ?? '',
      latitude: latitude, // Add latitude
      longitude: longitude, // Add longitude
    );
  }

  // Updated toJson to include both field formats for compatibility
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'contact_no': mobileNumber,
      'email_id': emailId,
      'email': emailId,
      'delivery_addr_line_1': deliveryAddrLine1,
      'address_1': deliveryAddrLine1,
      'delivery_addr_line_2': deliveryAddrLine2,
      'address_2': deliveryAddrLine2,
      'delivery_addr_city': deliveryAddrCity,
      'city': deliveryAddrCity,
      'delivery_addr_pincode': deliveryAddrPincode,
      'pincode': deliveryAddrPincode,
      'is_default': isDefault,
      'area_id': areaId,
      'area': areaId,
      'landmark': landmark,
      'landmart': landmark, // Include both spellings for compatibility
      'state': state,
      'latitude': latitude, // Include latitude
      'longitude': longitude, // Include longitude
    };
  }

  // Convert to API format for add/update requests - Updated to match Postman
  Map<String, dynamic> toApiRequest({required String accessKey, required String projectCode}) {
    final Map<String, dynamic> request = {
      "idaddress_book": id.isEmpty ? "12" : id, // Use "12" as placeholder for new addresses
      "project_code": projectCode,
      "full_name": fullName.trim(),
      "access_key": accessKey,
      "mobile_number": mobileNumber.trim(),
      "email_id": emailId.trim(),
      "delivery_addr_line_1": deliveryAddrLine1.trim(),
      "delivery_addr_line_2": deliveryAddrLine2.trim(),
      "delivery_addr_city": deliveryAddrCity.trim(),
      "delivery_addr_pincode": deliveryAddrPincode.trim(),
      "is_default": isDefault,
      "latitude": latitude ?? "",  // Include latitude
      "longitude": longitude ?? "", // Include longitude
      "area_id": areaId,
    };
    
    return request;
  }

  Address copyWith({
    String? id,
    String? fullName,
    String? mobileNumber,
    String? emailId,
    String? deliveryAddrLine1,
    String? deliveryAddrLine2,
    String? deliveryAddrCity,
    String? deliveryAddrPincode,
    String? isDefault,
    String? areaId,
    String? landmark,
    String? state,
    String? latitude,
    String? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      emailId: emailId ?? this.emailId,
      deliveryAddrLine1: deliveryAddrLine1 ?? this.deliveryAddrLine1,
      deliveryAddrLine2: deliveryAddrLine2 ?? this.deliveryAddrLine2,
      deliveryAddrCity: deliveryAddrCity ?? this.deliveryAddrCity,
      deliveryAddrPincode: deliveryAddrPincode ?? this.deliveryAddrPincode,
      isDefault: isDefault ?? this.isDefault,
      areaId: areaId ?? this.areaId,
      landmark: landmark ?? this.landmark,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  static fromMap(Map<String, dynamic> deliveryAddressMap) {}
  /// Converts to the domain entity.
  ///
  /// `isDefault` arrives as a String — '1', 'true' or 'yes' depending on the
  /// route. Decoded once here instead of at each call site.
  CustomerAddress toEntity() {
    final flag = isDefault.trim().toLowerCase();
    return CustomerAddress(
      id: id,
      fullName: fullName,
      mobileNumber: mobileNumber,
      email: emailId,
      line1: deliveryAddrLine1,
      line2: deliveryAddrLine2,
      landmark: landmark,
      city: deliveryAddrCity,
      state: state,
      pincode: deliveryAddrPincode,
      isDefault: flag == '1' || flag == 'true' || flag == 'yes',
      areaId: areaId,
      location: GeoPoint.tryParse(latitude, longitude),
    );
  }

  /// Rebuilds a DTO from the entity, for screens still typed to Address.
  factory Address.fromEntity(CustomerAddress a) => Address(
        id: a.id,
        fullName: a.fullName,
        mobileNumber: a.mobileNumber,
        emailId: a.email,
        deliveryAddrLine1: a.line1,
        deliveryAddrLine2: a.line2,
        deliveryAddrCity: a.city,
        deliveryAddrPincode: a.pincode,
        // The backend's is_default is a strict Mongoose enum of 'Yes'/'No' —
        // '1'/'0' fails validation outright (every add-address call from this
        // path 400'd until this was caught, 2026-08-22).
        isDefault: a.isDefault ? 'Yes' : 'No',
        areaId: a.areaId,
        landmark: a.landmark,
        state: a.state,
        latitude: a.location?.latitude.toString(),
        longitude: a.location?.longitude.toString(),
      );

}