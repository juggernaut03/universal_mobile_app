// lib/presentation/providers/store_details_providers.dart
//
// Store contact details, moved out of help_support_screen.dart.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../di/infrastructure_providers.dart';
import 'outlet_provider.dart';

// Store details model
class StoreDetails {
  final String id;
  final String pincode;
  final String mobileOutletName;
  final String storeCode;
  final String isEnabled;
  final String storeAddress;
  final int minOrderAmount;
  final String storeOpenTime;
  final String storeDeliveryTime;
  final String latitude;
  final String longitude;
  final String contactNumber;
  final String email;

  StoreDetails({
    required this.id,
    required this.pincode,
    required this.mobileOutletName,
    required this.storeCode,
    required this.isEnabled,
    required this.storeAddress,
    required this.minOrderAmount,
    required this.storeOpenTime,
    required this.storeDeliveryTime,
    required this.latitude,
    required this.longitude,
    required this.contactNumber,
    required this.email,
  });

  factory StoreDetails.fromJson(Map<String, dynamic> json) {
    return StoreDetails(
      id: json['_id'] ?? '',
      pincode: json['pincode'] ?? '',
      mobileOutletName: json['mobile_outlet_name'] ?? '',
      storeCode: json['store_code'] ?? '',
      isEnabled: json['is_enabled'] ?? '',
      storeAddress: json['store_address'] ?? '',
      minOrderAmount: json['min_order_amount'] ?? 0,
      storeOpenTime: json['store_open_time'] ?? '',
      storeDeliveryTime: json['store_delivery_time'] ?? '',
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      email: json['email'] ?? '',
    );
  }
}

final storeDetailsProvider = FutureProvider<StoreDetails?>((ref) async {
  final selectedOutlet = ref.watch(selectedOutletProvider).valueOrNull;
  final logger = ref.read(loggerProvider);
  
  if (selectedOutlet == null) {
    logger.log('No outlet selected for store details');
    return null;
  }

  try {
    logger.log('Fetching store details for store code: ${selectedOutlet.storeCode}');
    
    final apiService = ref.read(apiServiceProvider);
    final response = await apiService.getStoreDetails(selectedOutlet.storeCode);

    if (response != null && response.isNotEmpty) {
      final storeDetails = StoreDetails.fromJson(response);
      logger.log('Store details fetched successfully: ${storeDetails.mobileOutletName}');
      return storeDetails;
    } else {
      logger.error('Invalid or empty response format for store details');
      return null;
    }
  } catch (e) {
    logger.error('Error fetching store details: $e');
    return null;
  }
});
