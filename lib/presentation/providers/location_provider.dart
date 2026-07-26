// lib/presentation/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/models/pincode_model.dart';
import 'splash_provider.dart';
import '../../di/repository_providers.dart';
import '../../core/result/result.dart';
import '../../di/location_providers.dart';
import '../../domain/usecases/location/check_pincode_serviceability.dart';
import '../../domain/entities/delivery_location.dart';
import '../../di/infrastructure_providers.dart';

// Provider for the Location Repository

// Current Location provider - refreshable
final currentLocationProvider = FutureProvider<Position?>((ref) async {
  final repository = ref.watch(locationRepositoryProvider);
  return await repository.getCurrentPosition();
});

// Current Pincode provider - refreshable
final currentPincodeProvider = FutureProvider<String?>((ref) async {
  final repository = ref.watch(locationRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final isGoogleMapsInitialized = ref.watch(googleMapsInitializedProvider);
  
  try {
    final pincode = await repository.getPincodeFromCurrentLocation();
    logger.log('Retrieved pincode from location: $pincode (Google Maps initialized: $isGoogleMapsInitialized)');
    return pincode;
  } catch (e) {
    logger.error('Error getting pincode from location: $e');
    return null;
  }
});

// Provider to check if a pincode is serviceable
//
// Previously this swallowed every error and returned `false`, so a user with no
// connectivity was told "we do not deliver to your area" — indistinguishable
// from a genuine no. The use case now separates the two: an unserviceable
// pincode is `Ok(isServiceable: false)`, while a broken call is an `Err` and
// surfaces as AsyncValue.error so the UI can offer a retry.
final isPincodeServiceableProvider =
    FutureProvider.family<bool, String>((ref, pincode) async {
  final result = await ref.watch(checkPincodeServiceabilityUseCaseProvider)(
    CheckPincodeServiceabilityParams(pincode: pincode),
  );

  return switch (result) {
    Ok(:final value) => value.isServiceable,
    Err(:final failure) => throw Exception(failure.userMessage),
  };
});

// All available pincodes provider - refreshable
final allPincodesProvider = FutureProvider<List<PincodeModel>>((ref) async {
  final repository = ref.watch(locationRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  
  try {
    final pincodes = await repository.getAllPincodes();
    if (pincodes.isEmpty) {
      logger.log('No pincodes retrieved');
      return [];
    }
    logger.log('Retrieved ${pincodes.length} pincodes');
    return pincodes;
  } catch (e) {
    // TODO(phase-3b-followup): still returns [] on failure, so "no pincodes
    // configured" and "request failed" look identical to the picker. Fix when
    // the screen moves onto GetServiceablePincodes and can render an error.
    logger.error('Error getting all pincodes: $e');
    return [];
  }
});

// Selected pincode provider (cached)
final selectedPincodeProvider = StateNotifierProvider<SelectedPincodeNotifier, String?>((ref) {
  final repository = ref.watch(locationRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  return SelectedPincodeNotifier(repository, logger);
});

// Selected pincode notifier
class SelectedPincodeNotifier extends StateNotifier<String?> {
  final LocationRepository _repository;
  final Logger _logger;

  SelectedPincodeNotifier(this._repository, this._logger) : super(null) {
    _loadSavedPincode();
  }

  Future<void> _loadSavedPincode() async {
    try {
      final pincode = _repository.getSelectedPincode();
      _logger.log('Loaded saved pincode: $pincode');
      state = pincode;
    } catch (e) {
      _logger.error('Error loading saved pincode: $e');
    }
  }

  Future<bool> selectPincode(String pincode) async {
    try {
      _logger.log('Saving pincode: $pincode');
      final result = await _repository.saveSelectedPincode(pincode);
      if (result) {
        state = pincode;
        _logger.log('Pincode saved successfully');
      } else {
        _logger.error('Failed to save pincode');
      }
      return result;
    } catch (e) {
      _logger.error('Error selecting pincode: $e');
      return false;
    }
  }
  
  // Clear the selected pincode
  Future<bool> clearPincode() async {
    try {
      _logger.log('Clearing pincode');
      final result = await _repository.saveSelectedPincode('');
      if (result) {
        state = null;
        _logger.log('Pincode cleared successfully');
      } else {
        _logger.error('Failed to clear pincode');
      }
      return result;
    } catch (e) {
      _logger.error('Error clearing pincode: $e');
      return false;
    }
  }
}

// Filtered pincodes provider (for search functionality)
final filteredPincodesProvider = StateNotifierProvider<FilteredPincodesNotifier, AsyncValue<List<PincodeModel>>>((ref) {
  final allPincodes = ref.watch(allPincodesProvider);
  final logger = ref.watch(loggerProvider);
  return FilteredPincodesNotifier(allPincodes, logger);
});

// Filtered pincodes notifier
class FilteredPincodesNotifier extends StateNotifier<AsyncValue<List<PincodeModel>>> {
  final AsyncValue<List<PincodeModel>> _allPincodes;
  final Logger _logger;
  String _searchQuery = '';

  FilteredPincodesNotifier(this._allPincodes, this._logger) 
      : super(AsyncValue.loading()) {
    _updatePincodes();
  }

  void _updatePincodes() {
    _allPincodes.whenData((pincodes) {
      if (_searchQuery.isEmpty) {
        // Return all pincodes if no search query
        state = AsyncValue.data(pincodes);
        _logger.log('Filtered pincodes: showing all ${pincodes.length} pincodes');
      } else {
        // Filter by pincode containing the search query
        final filtered = pincodes.where((pincode) {
          return pincode.pincode.contains(_searchQuery);
        }).toList();
        
        state = AsyncValue.data(filtered);
        _logger.log('Filtered pincodes: ${filtered.length} results for query "$_searchQuery"');
      }
    });
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _logger.log('Setting search query: "$query"');
    _updatePincodes();
  }
}

// Model to store location serviceability info
class LocationInfo {
  final String? nonServiceablePincode;

  /// Why automatic detection failed, when it did.
  ///
  /// Was a bare `String?` holding one of five magic codes. Screens compared it
  /// with `==` and only three of the five were ever handled. Typed now; the
  /// legacy string is still exposed as [locationError] for screens that have
  /// not moved over yet.
  final LocationIssue? issue;

  LocationInfo({this.nonServiceablePincode, this.issue});

  /// Legacy string form of [issue]. Transitional — prefer [issue].
  String? get locationError => issue?.legacyCode;
}

// Provider to store location information for UI display
final locationInfoProvider = StateProvider<LocationInfo>((ref) {
  return LocationInfo();
});

