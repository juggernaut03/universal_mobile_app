// lib/data/services/location_service.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/utils/location_utils.dart';
import '../../core/utils/logger.dart';
import '../../data/services/google_maps_service.dart';

class LocationService {
  final LocationUtils _locationUtils;
  final Logger _logger;
  final GoogleMapsService? _googleMapsService;

  LocationService({
    LocationUtils? locationUtils,
    GoogleMapsService? googleMapsService,
    Logger? logger,
  })  : _locationUtils = locationUtils ?? LocationUtils(googleMapsService: googleMapsService),
        _googleMapsService = googleMapsService,
        _logger = logger ?? Logger();

  Future<Position?> getCurrentPosition() async {
    try {
      final position = await _locationUtils.getCurrentPosition();
      _logger.log('Current position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      _logger.error('Error getting current position: $e');
      return null;
    }
  }
// Add this to lib/data/services/location_service.dart

// Static method to handle location errors with a dialog
static Future<void> handleLocationError(
  BuildContext context,
  LocationPermissionException exception, {
  VoidCallback? onCancel,
}) async {
  String title;
  String message;
  String actionText = 'Settings';
  VoidCallback action = () async {
    // Close the dialog
    Navigator.pop(context);
    // Open location settings
    await Geolocator.openLocationSettings();
  };

  if (exception.message.contains('disabled')) {
    title = 'Location Services Disabled';
    message = 'Please enable location services to detect your location automatically.';
  } else if (exception.message.contains('permanently denied')) {
    title = 'Location Permission Required';
    message = 'Location permissions are permanently denied. Please enable them in app settings.';
    action = () async {
      // Close the dialog
      Navigator.pop(context);
      // Open app settings
      await Geolocator.openAppSettings();
    };
  } else {
    title = 'Location Permission Required';
    message = 'Please grant location permission to detect your location automatically.';
  }

  // Show an error dialog
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(message),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
              if (onCancel != null) {
                onCancel();
              }
            },
          ),
          TextButton(
            onPressed: action,
            child: Text(actionText),
          ),
        ],
      );
    },
  );
}
  Future<String?> getPincodeFromCurrentLocation() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return null;
      
      return await _locationUtils.getPincodeFromPosition(position);
    } catch (e) {
      _logger.error('Error getting pincode from location: $e');
      return null;
    }
  }
  
  // Check if a location is within service area
  Future<bool> isLocationInServiceArea(Position position, List<String> servicePincodes) async {
    try {
      // If Google Maps service is available, use it
      if (_googleMapsService != null && _googleMapsService.isInitialized) {
        final coordinates = LatLng(position.latitude, position.longitude);
        return await _googleMapsService.isLocationInServiceArea(coordinates, servicePincodes);
      }
      
      // Fallback to basic pincode check
      final pincode = await _locationUtils.getPincodeFromPosition(position);
      if (pincode == null) return false;
      
      return servicePincodes.contains(pincode);
    } catch (e) {
      _logger.error('Error checking if location is in service area: $e');
      return false;
    }
  }
  
  // Get distance between user's location and a store (for finding nearest store)
  Future<double?> getDistanceToStore(Position userPosition, double storeLat, double storeLng) async {
    try {
      if (_googleMapsService != null && _googleMapsService.isInitialized) {
        final userCoordinates = LatLng(userPosition.latitude, userPosition.longitude);
        final storeCoordinates = LatLng(storeLat, storeLng);
        
        return await _googleMapsService.getDistance(userCoordinates, storeCoordinates);
      }
      
      // Fallback to basic distance calculation using Haversine formula
      return _locationUtils.calculateHaversineDistance(
        userPosition.latitude, userPosition.longitude,
        storeLat, storeLng
      );
    } catch (e) {
      _logger.error('Error calculating distance to store: $e');
      return null;
    }
  }
}