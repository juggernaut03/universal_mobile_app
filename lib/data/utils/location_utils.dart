// lib/core/utils/location_utils.dart

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' show atan2, cos, sin, sqrt, pi;
import 'package:geocoding/geocoding.dart' as geocoding;
import '../../core/utils/logger.dart';
import '../services/google_maps_service.dart';

class LocationPermissionException implements Exception {
  final String message;
  LocationPermissionException(this.message);
  
  @override
  String toString() => 'LocationPermissionException: $message';
}

class LocationUtils {
  final Logger _logger;
  final GoogleMapsService? _googleMapsService;

  LocationUtils({
    GoogleMapsService? googleMapsService,
    Logger? logger,
  })  : _googleMapsService = googleMapsService,
        _logger = logger ?? Logger();

  Future<Position> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationPermissionException('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw LocationPermissionException('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationPermissionException(
            'Location permissions are permanently denied, please enable in settings');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _logger.log('Error getting location: $e');
      rethrow;
    }
  }

  Future<String?> getPincodeFromPosition(Position position) async {
    try {
      // If Google Maps service is available, use it
      if (_googleMapsService != null && _googleMapsService.isInitialized) {
        final coordinates = LatLng(position.latitude, position.longitude);
        return await _googleMapsService.getPincodeFromCoordinates(coordinates);
      } 
      
      // Fallback to Geocoding package if Google Maps is not available
      _logger.log('Using geocoding package fallback for pincode lookup');
      
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        String? pincode = placemarks.first.postalCode;
        _logger.log('Fetched pincode using geocoding package: $pincode');
        return pincode;
      }
      return null;
    } catch (e) {
      _logger.error('Error getting pincode: $e');
      return null;
    }
  }
  
  // Calculate distance using Haversine formula (as fallback)
  double calculateHaversineDistance(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    const int earthRadiusKm = 6371;
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = 
      _haversin(dLat) + 
      _haversin(dLon) * _cosine(_degreesToRadians(lat1)) * _cosine(_degreesToRadians(lat2));
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c;
  }
  
  double _degreesToRadians(double degrees) => degrees * pi / 180;
  double _haversin(double theta) => sin(theta / 2) * sin(theta / 2);
  double _cosine(double theta) => cos(theta);
  
  // Utility method to convert Position to LatLng
  LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }
}