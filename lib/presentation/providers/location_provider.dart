// lib/presentation/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/models/pincode_model.dart';
import 'launch_flow_provider.dart';
import 'splash_provider.dart';

// Provider for the Location Repository
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  final locationService = ref.watch(locationServiceProvider);
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  
  return LocationRepository(
    locationService: locationService,
    apiService: apiService,
    storageService: storageService,
    logger: logger,
  );
});

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
final isPincodeServiceableProvider = FutureProvider.family<bool, String>((ref, pincode) async {
  final repository = ref.watch(locationRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  
  try {
    final isServiceable = await repository.isPincodeServiceable(pincode);
    logger.log('Pincode $pincode serviceable: $isServiceable');
    return isServiceable;
  } catch (e) {
    logger.error('Error checking if pincode $pincode is serviceable: $e');
    return false;
  }
});

// All available pincodes provider - refreshable
final allPincodesProvider = FutureProvider<List<PincodeModel>>((ref) async {
  final repository = ref.watch(locationRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  
  try {
    final pincodes = await repository.getAllPincodes();
    logger.log('Retrieved ${pincodes.length} pincodes');
    return pincodes;
  } catch (e) {
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
  final String? locationError;
  
  LocationInfo({this.nonServiceablePincode, this.locationError});
}

// Provider to store location information for UI display
final locationInfoProvider = StateProvider<LocationInfo>((ref) {
  return LocationInfo();
});

