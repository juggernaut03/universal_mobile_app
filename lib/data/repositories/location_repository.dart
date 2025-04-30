// lib/data/repositories/location_repository.dart

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/pincode_model.dart';
import '../../core/utils/logger.dart';

class LocationRepository {
  final LocationService _locationService;
  final ApiService _apiService;
  final StorageService _storageService;
  final Logger _logger;

  LocationRepository({
    required LocationService locationService,
    required ApiService apiService,
    required StorageService storageService,
    Logger? logger,
  })  : _locationService = locationService,
        _apiService = apiService,
        _storageService = storageService,
        _logger = logger ?? Logger();

  Future<Position?> getCurrentPosition() async {
    return await _locationService.getCurrentPosition();
  }

  Future<String?> getPincodeFromCurrentLocation() async {
    return await _locationService.getPincodeFromCurrentLocation();
  }

  Future<bool> isPincodeServiceable(String pincode) async {
    try {
      final response = await _apiService.checkIfPincodeExists(pincode);
      return response.isPincodeServiceable();
    } catch (e) {
      _logger.error('Error checking if pincode is serviceable: $e');
      return false;
    }
  }

  Future<List<PincodeModel>> getAllPincodes() async {
    return await _apiService.getPincodeList();
  }

  Future<bool> saveSelectedPincode(String pincode) async {
    return await _storageService.saveSelectedPincode(pincode);
  }

  String? getSelectedPincode() {
    return _storageService.getSelectedPincode();
  }

  Future<bool> saveUserLocation(Position position) async {
    return await _storageService.saveUserLocation(
      position.latitude,
      position.longitude,
    );
  }
  
  // Check if a location is within a service area using the LocationService
  Future<bool> isLocationInServiceArea(Position position, List<String> servicePincodes) async {
    return await _locationService.isLocationInServiceArea(position, servicePincodes);
  }
  
  // Get distance between user's location and a store
  Future<double?> getDistanceToStore(Position userPosition, double storeLat, double storeLng) async {
    return await _locationService.getDistanceToStore(userPosition, storeLat, storeLng);
  }
}