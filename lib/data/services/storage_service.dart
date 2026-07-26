// lib/data/services/storage_service.dart

import 'dart:convert';
import 'package:patelmart/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import '../models/outlet_model.dart';

class StorageService {
  final SharedPreferences _prefs;
  final Logger _logger;

  StorageService({
    required SharedPreferences prefs,
    Logger? logger,
  })  : _prefs = prefs,
        _logger = logger ?? Logger();

  // Store selected pincode
  Future<bool> saveSelectedPincode(String pincode) async {
    try {
      return await _prefs.setString(ApiConstants.keyPincode, pincode);
    } catch (e) {
      _logger.error('Error saving pincode: $e');
      return false;
    }
  }

  // Get selected pincode
  String? getSelectedPincode() {
    try {
      return _prefs.getString(ApiConstants.keyPincode);
    } catch (e) {
      _logger.error('Error getting pincode: $e');
      return null;
    }
  }

  // Store selected outlet
  Future<bool> saveSelectedOutlet(OutletModel outlet) async {
    try {
      return await _prefs.setString(
        ApiConstants.keyOutlet,
        jsonEncode(outlet.toJson()),
      );
    } catch (e) {
      _logger.error('Error saving outlet: $e');
      return false;
    }
  }

  /// Removes the stored pincode.
  ///
  /// Callers previously "cleared" it by saving an empty string, which then
  /// loaded back as a selected pincode of ''.
  Future<bool> clearSelectedPincode() async {
    try {
      return await _prefs.remove(ApiConstants.keyPincode);
    } catch (e) {
      _logger.error('Error clearing pincode: $e');
      return false;
    }
  }

  /// Removes the stored outlet.
  ///
  /// Added because callers previously "cleared" the selection by persisting a
  /// dummy OutletModel with empty fields, which then loaded back as a real
  /// outlet with an empty store code.
  Future<bool> clearSelectedOutlet() async {
    try {
      return await _prefs.remove(ApiConstants.keyOutlet);
    } catch (e) {
      _logger.error('Error clearing outlet: $e');
      return false;
    }
  }

  // Get selected outlet
  OutletModel? getSelectedOutlet() {
    try {
      final jsonString = _prefs.getString(ApiConstants.keyOutlet);
      if (jsonString == null) return null;
      return OutletModel.fromJson(jsonDecode(jsonString));
    } catch (e) {
      _logger.error('Error getting outlet: $e');
      return null;
    }
  }

  // Store location coordinates
  Future<bool> saveUserLocation(double latitude, double longitude) async {
    try {
      final locationData = {
        'latitude': latitude,
        'longitude': longitude,
      };
      return await _prefs.setString(
        ApiConstants.keyLocation,
        jsonEncode(locationData),
      );
    } catch (e) {
      _logger.error('Error saving location: $e');
      return false;
    }
  }

  // Get location coordinates
  Map<String, double>? getUserLocation() {
    try {
      final jsonString = _prefs.getString(ApiConstants.keyLocation);
      if (jsonString == null) return null;
      
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return {
        'latitude': data['latitude'] as double,
        'longitude': data['longitude'] as double,
      };
    } catch (e) {
      _logger.error('Error getting location: $e');
      return null;
    }
  }

  // Clear all stored data
  Future<bool> clearAllData() async {
    try {
      await _prefs.remove(ApiConstants.keyPincode);
      await _prefs.remove(ApiConstants.keyOutlet);
      await _prefs.remove(ApiConstants.keyLocation);
      return true;
    } catch (e) {
      _logger.error('Error clearing data: $e');
      return false;
    }
  }
}