// lib/data/services/google_maps_service.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/utils/logger.dart';


class GoogleMapsService {
  final http.Client _client;
  final Logger _logger;
  final String _apiKey;
  bool _isInitialized = false;

  GoogleMapsService({
    required String apiKey,
    http.Client? client,
    Logger? logger,
  })  : _apiKey = apiKey,
        _client = client ?? http.Client(),
        _logger = logger ?? Logger();

  /// Initialize the Google Maps service
  Future<bool> initialize() async {
    try {
      // Validate API key with a simple request
      final response = await _client.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=0,0&key=$_apiKey',
        ),
      );
      
      final data = json.decode(response.body);
      if (data['status'] == 'REQUEST_DENIED') {
        _logger.error('Google Maps API key validation failed: ${data['error_message']}');
        return false;
      }
      
      _isInitialized = true;
      _logger.log('Google Maps API initialized successfully');
      return true;
    } catch (e) {
      _logger.error('Failed to initialize Google Maps API: $e');
      return false;
    }
  }
  
  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get pincode from coordinates using Google's Geocoding API
  Future<String?> getPincodeFromCoordinates(LatLng coordinates) async {
    if (!_isInitialized) {
      _logger.error('Google Maps API not initialized');
      return null;
    }
    
    try {
      final response = await _client.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${coordinates.latitude},${coordinates.longitude}&key=$_apiKey',
        ),
      );
      
      final data = json.decode(response.body);
      if (data['status'] != 'OK') {
        _logger.error('Geocoding API error: ${data['status']}');
        return null;
      }
      
      // Extract postal code from address components
      String? postalCode;
      
      for (final result in data['results']) {
        final components = result['address_components'] as List;
        for (final component in components) {
          final types = component['types'] as List;
          if (types.contains('postal_code')) {
            postalCode = component['long_name'];
            break;
          }
        }
        
        if (postalCode != null) break;
      }
      
      _logger.log('Retrieved pincode from Google Maps: $postalCode');
      return postalCode;
    } catch (e) {
      _logger.error('Error getting pincode from coordinates: $e');
      return null;
    }
  }
  
  /// Validate if a location is within a service area (pincode)
  Future<bool> isLocationInServiceArea(LatLng coordinates, List<String> servicePincodes) async {
    final pincode = await getPincodeFromCoordinates(coordinates);
    if (pincode == null) return false;
    
    return servicePincodes.contains(pincode);
  }
  
  /// Get distance between two coordinates in kilometers
  Future<double?> getDistance(LatLng origin, LatLng destination) async {
    if (!_isInitialized) {
      _logger.error('Google Maps API not initialized');
      return null;
    }
    
    try {
      final response = await _client.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origin.latitude},${origin.longitude}&destinations=${destination.latitude},${destination.longitude}&key=$_apiKey',
        ),
      );
      
      final data = json.decode(response.body);
      if (data['status'] != 'OK') {
        _logger.error('Distance Matrix API error: ${data['status']}');
        return null;
      }
      
      // Extract distance in meters and convert to kilometers
      final distanceInMeters = data['rows'][0]['elements'][0]['distance']['value'];
      return distanceInMeters / 1000.0;
    } catch (e) {
      _logger.error('Error calculating distance: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}