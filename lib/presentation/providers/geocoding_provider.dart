// lib/presentation/providers/geocoding_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patelmart/core/utils/geocoding_utils.dart';
import '../../di/infrastructure_providers.dart';

// Provider for the GeocodingUtils class
final geocodingUtilsProvider = Provider<GeocodingUtils>((ref) {
  final logger = ref.watch(loggerProvider);
  return GeocodingUtils(logger: logger);
});

// Provider to get coordinates from an address
final addressToCoordinatesProvider = FutureProvider.family<Map<String, double>?, String>((ref, address) async {
  final geocodingUtils = ref.watch(geocodingUtilsProvider);
  return await geocodingUtils.getCoordinatesFromAddress(address);
});

// Provider to get an address from coordinates
final coordinatesToAddressProvider = FutureProvider.family<Placemark?, ({double latitude, double longitude})>((ref, coords) async {
  final geocodingUtils = ref.watch(geocodingUtilsProvider);
  return await geocodingUtils.getAddressFromCoordinates(coords.latitude, coords.longitude);
});

// Provider to check if location permissions are granted
final locationPermissionsProvider = FutureProvider<bool>((ref) async {
  final geocodingUtils = ref.watch(geocodingUtilsProvider);
  return await geocodingUtils.checkLocationPermissions();
});

// Provider to get the current position
final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final geocodingUtils = ref.watch(geocodingUtilsProvider);
  return await geocodingUtils.getCurrentPosition();
});

// Custom class for location results
class LocationResult {
  final Position? position;
  final Placemark? address;
  final String? error;

  LocationResult({
    this.position,
    this.address,
    this.error,
  });

  bool get hasLocation => position != null;
  bool get hasAddress => address != null;
  bool get hasError => error != null;
}

// Provider that combines position and address for a complete location result
final completeLocationProvider = FutureProvider<LocationResult>((ref) async {
  final geocodingUtils = ref.watch(geocodingUtilsProvider);

  try {
    // Check permissions
    final hasPermission = await geocodingUtils.checkLocationPermissions();
    if (!hasPermission) {
      return LocationResult(error: 'Location permission denied');
    }

    // Get current position
    final position = await geocodingUtils.getCurrentPosition();
    if (position == null) {
      return LocationResult(error: 'Failed to get current position');
    }

    // Get address from position
    final placemark = await geocodingUtils.getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );

    return LocationResult(
      position: position,
      address: placemark,
    );
  } catch (e) {
    ref.read(loggerProvider).error('Error in complete location provider: $e');
    return LocationResult(error: e.toString());
  }
});