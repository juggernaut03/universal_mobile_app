// lib/data/services/delivery_charges_service.dart

import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' show locationFromAddress;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/address_model.dart';
import '../models/outlet_model.dart';

/// Result of a delivery-charge calculation from the universal backend.
///
/// [charge] is the combined total (distance + handling + package) the
/// backend calls `total_charges` — kept for callers that only need one
/// number. The three components are broken out separately so the checkout
/// summary can show them as line items instead of one opaque "Delivery Fee":
/// handling_fee and package_fee are store-configured flat charges
/// (models/Store.js) that are NOT waived by free delivery — only the
/// distance-based component is (see calculateDeliveryCharge in
/// utils/distanceCalculation.js), so lumping them together under "FREE" was
/// misleading whenever a store had either fee set.
class DeliveryChargeQuote {
  final bool available;
  final double charge;
  final double distanceCharge;
  final double handlingFee;
  final double packageFee;
  final double distanceKm;
  final bool freeDelivery;
  final String reason;

  DeliveryChargeQuote({
    required this.available,
    required this.charge,
    this.distanceCharge = 0.0,
    this.handlingFee = 0.0,
    this.packageFee = 0.0,
    required this.distanceKm,
    required this.freeDelivery,
    this.reason = '',
  });

  /// Fail-soft default: deliverable with no charge (matches legacy behavior
  /// of defaulting to free delivery on errors).
  factory DeliveryChargeQuote.fallback() => DeliveryChargeQuote(
        available: true,
        charge: 0.0,
        distanceKm: 0.0,
        freeDelivery: true,
      );
}

/// Service that handles delivery charge calculations and API integration
class DeliveryChargesService {
  final http.Client _client;
  final Logger _logger;

  DeliveryChargesService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  /// Calculate delivery charge via the universal backend
  /// (POST /api/delivery-charges/calculate). The server computes road
  /// distance from the address coordinates, so this needs lat/lng — resolve
  /// them with [resolveAddressCoordinates] first.
  Future<DeliveryChargeQuote> getDeliveryChargesForCoordinates({
    required double addressLatitude,
    required double addressLongitude,
    required String storeCode,
    required double orderAmount,
  }) async {
    try {
      _logger.log(
          'Fetching delivery charges - lat: $addressLatitude, lng: $addressLongitude, Store: $storeCode, Amount: $orderAmount');

      final response = await _client.post(
        Uri.parse(ApiConstants.deliveryChargesCalculate),
        headers: {
          'Content-Type': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
        },
        body: jsonEncode({
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
          'address_latitude': addressLatitude.toString(),
          'address_longitude': addressLongitude.toString(),
          'order_amount': orderAmount,
        }),
      ).timeout(const Duration(seconds: 10));

      _logger.log('Delivery charges API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map && decoded['data'] is Map
            ? decoded['data'] as Map
            : {};
        return DeliveryChargeQuote(
          available: data['delivery_available'] != false,
          charge: (data['total_charges'] ?? data['delivery_charge'] ?? 0)
              .toDouble(),
          distanceCharge: (data['distance_charge'] ?? 0).toDouble(),
          handlingFee: (data['handling_fee'] ?? 0).toDouble(),
          packageFee: (data['package_fee'] ?? 0).toDouble(),
          distanceKm: (data['distance_km'] ?? 0).toDouble(),
          freeDelivery: data['free_delivery'] == true,
          reason: (data['reason'] ?? '').toString(),
        );
      } else {
        _logger.error('Failed to fetch delivery charges: ${response.statusCode} - ${response.body}');
        return DeliveryChargeQuote.fallback();
      }
    } catch (e) {
      _logger.error('Error getting delivery charges: $e');
      return DeliveryChargeQuote.fallback();
    }
  }

  /// Resolve an address to coordinates: use stored lat/lng if present,
  /// otherwise geocode the address text. Returns null when unresolvable.
  Future<({double latitude, double longitude})?> resolveAddressCoordinates(
      Address userAddress) async {
    if (userAddress.latitude != null &&
        userAddress.latitude!.isNotEmpty &&
        userAddress.longitude != null &&
        userAddress.longitude!.isNotEmpty) {
      final lat = double.tryParse(userAddress.latitude!);
      final lng = double.tryParse(userAddress.longitude!);
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        return (latitude: lat, longitude: lng);
      }
    }

    try {
      final locations = await locationFromAddress(
          '${userAddress.deliveryAddrLine1}, ${userAddress.deliveryAddrLine2}, ${userAddress.deliveryAddrCity}, ${userAddress.deliveryAddrPincode}');
      if (locations.isNotEmpty) {
        return (
          latitude: locations.first.latitude,
          longitude: locations.first.longitude
        );
      }
    } catch (e) {
      _logger.error('Error geocoding address: $e');
    }
    return null;
  }

  /// Calculate the distance between a user's address and the store
  Future<double> calculateDistance({
    required Address userAddress,
    required OutletModel store,
  }) async {
    try {
      // Check if both addresses have coordinates
      if (store.latitude.isEmpty || store.longitude.isEmpty) {
        _logger.error('Store coordinates not available');
        return 10.0; // Default distance
      }

      // If address has coordinates directly, use them
      double? addressLat;
      double? addressLong;
      
      // Try to extract from address additional properties
      if (userAddress.latitude != null && userAddress.latitude!.isNotEmpty &&
          userAddress.longitude != null && userAddress.longitude!.isNotEmpty) {
        try {
          addressLat = double.parse(userAddress.latitude!);
          addressLong = double.parse(userAddress.longitude!);
        } catch (e) {
          _logger.error('Error parsing address coordinates: $e');
        }
      }
      
      // If we couldn't get coordinates from the address, try to geocode
      if (addressLat == null || addressLong == null) {
        _logger.log('Address coordinates not available, trying to geocode');
        try {
          // Get coordinates by geocoding the address
          final locations = await locationFromAddress(
            '${userAddress.deliveryAddrLine1}, ${userAddress.deliveryAddrLine2}, ${userAddress.deliveryAddrCity}, ${userAddress.deliveryAddrPincode}'
          );
          
          if (locations.isNotEmpty) {
            addressLat = locations.first.latitude;
            addressLong = locations.first.longitude;
          } else {
            _logger.error('Geocoding returned no results');
            return 10.0; // Default to 10 km if geocoding fails
          }
        } catch (e) {
          _logger.error('Error geocoding address: $e');
          return 10.0; // Default to 10 km if geocoding fails
        }
      }
      
      // Parse store coordinates
      double storeLat;
      double storeLong;
      
      try {
        storeLat = double.parse(store.latitude);
        storeLong = double.parse(store.longitude);
      } catch (e) {
        _logger.error('Error parsing store coordinates: $e');
        return 10.0; // Default to 10 km if parsing fails
      }
      
      // Use Geolocator for calculation if available
      try {
        // First try using Geolocator package for a direct calculation
        double distanceInKm = Geolocator.distanceBetween(
          addressLat, addressLong, storeLat, storeLong
        ) / 1000; // Convert meters to kilometers
        
        _logger.log('Calculated distance: $distanceInKm km');
        return distanceInKm;
      } catch (e) {
        _logger.error('Error calculating distance with Geolocator: $e');
        
        // Fallback to the Haversine formula
        return _calculateHaversineDistance(
          addressLat, addressLong, storeLat, storeLong
        );
      }
    } catch (e) {
      _logger.error('Error in distance calculation: $e');
      return 10.0; // Default to 10 km in case of any error
    }
  }
  
  // Calculate distance using the Haversine formula
  double _calculateHaversineDistance(
    double lat1, double lon1, double lat2, double lon2
  ) {
    const double earthRadius = 6371; // in kilometers
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * 
        sin(dLon / 2) * sin(dLon / 2);
        
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;
    
    _logger.log('Calculated distance (Haversine): $distance km');
    return distance;
  }
  
  // Helper function to convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}