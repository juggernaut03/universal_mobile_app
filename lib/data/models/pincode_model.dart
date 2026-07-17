// lib/data/models/pincode_model.dart

class PincodeModel {
  final String id;
  final String pincode;

  PincodeModel({
    required this.id,
    required this.pincode,
  });

  factory PincodeModel.fromJson(Map<String, dynamic> json) {
    return PincodeModel(
      id: json['id'] ?? json['_id'] ?? '',
      pincode: json['pincode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'pincode': pincode,
    };
  }
}

class PincodeCheckResponse {
  final int count;
  final String message;

  PincodeCheckResponse({
    required this.count,
    required this.message,
  });

  // Universal backend: {success, available, serviceable, message, pincode}
  factory PincodeCheckResponse.fromJson(Map<String, dynamic> json) {
    final bool serviceable =
        json['serviceable'] == true && json['available'] == true;
    return PincodeCheckResponse(
      count: serviceable ? 1 : 0,
      message: json['message'] ?? '',
    );
  }

  bool isPincodeServiceable() => count == 1;
}