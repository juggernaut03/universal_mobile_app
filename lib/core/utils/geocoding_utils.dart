// lib/core/utils/geocoding_utils.dart

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patelmart/core/utils/logger.dart';

/// A utility class for geocoding operations
class GeocodingUtils {
  final Logger _logger;

  GeocodingUtils({required Logger logger}) : _logger = logger;

  /// Convert an address string to latitude and longitude coordinates
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    if (address.isEmpty) {
      _logger.error('Address string is empty, cannot geocode');
      return null;
    }
    
    try {
      _logger.log('Geocoding address: $address');
      final locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        _logger.log('Got coordinates: ${location.latitude}, ${location.longitude}');
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      } else {
        _logger.error('No coordinates found for address: $address');
        return null;
      }
    } catch (e) {
      _logger.error('Error geocoding address: $e');
      return null;
    }
  }

  /// Convert latitude and longitude to an address (reverse geocoding)
  Future<Placemark?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      _logger.log('Reverse geocoding coordinates: $latitude, $longitude');
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _logger.log('Got address: ${place.street}, ${place.locality}, ${place.postalCode}');
        return place;
      } else {
        _logger.error('No address found for coordinates: $latitude, $longitude');
        return null;
      }
    } catch (e) {
      _logger.error('Error reverse geocoding coordinates: $e');
      return null;
    }
  }

  /// Check if location services are enabled and permissions are granted
  Future<bool> checkLocationPermissions() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.error('Location services are disabled');
        return false;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.error('Location permission denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _logger.error('Location permission permanently denied');
        return false;
      }
      
      return true;
    } catch (e) {
      _logger.error('Error checking location permissions: $e');
      return false;
    }
  }

  /// Get current position
  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      // Check permissions first
      if (!await checkLocationPermissions()) {
        return null;
      }
      
      // Get current position
      _logger.log('Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      _logger.log('Current position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      _logger.error('Error getting current position: $e');
      return null;
    }
  }

  /// Build a complete address string from components
  static String buildAddressString({
    String? house,
    String? street,
    String? area,
    String? city,
    String? state,
    String? pincode,
  }) {
    return [
      house,
      street,
      area,
      city,
      state,
      pincode,
    ].where((part) => part != null && part.isNotEmpty).join(', ');
  }
}