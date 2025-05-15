// lib/data/services/delivery_charges_service.dart

import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' show locationFromAddress;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/address_model.dart';
import '../models/outlet_model.dart';

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

  /// Calculate delivery charge based on distance, store code, and order amount
  Future<double> getDeliveryCharges({
    required double distance, 
    required String storeCode,
    required double orderAmount,
  }) async {
    try {
      _logger.log('Fetching delivery charges - Distance: $distance, Store: $storeCode, Amount: $orderAmount');
      
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/get_delivery_charges'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'distance': distance.round().toString(),
          'store_code': storeCode,
          'order_amount': orderAmount.round(),
        }),
      ).timeout(const Duration(seconds: 10));

      _logger.log('Delivery charges API response status: ${response.statusCode}');
      _logger.log('Delivery charges API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        // The API returns just a number as a string
        try {
          final double deliveryCharge = double.parse(response.body.trim());
          return deliveryCharge;
        } catch (e) {
          _logger.error('Error parsing delivery charge response: $e');
          return 0.0; // Default to free delivery on parsing error
        }
      } else {
        _logger.error('Failed to fetch delivery charges: ${response.statusCode}');
        return 0.0; // Default to free delivery on error
      }
    } catch (e) {
      _logger.error('Error getting delivery charges: $e');
      return 0.0; // Default to free delivery on error
    }
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