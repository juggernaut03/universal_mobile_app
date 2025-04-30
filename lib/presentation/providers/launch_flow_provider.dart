// lib/presentation/providers/launch_flow_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show atan2, cos, sin, sqrt, pi;
import '../../core/utils/logger.dart';
import '../../data/services/api_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/google_maps_service.dart';
import 'location_provider.dart';
import 'outlet_provider.dart';
import 'splash_provider.dart';

// Launch flow state
enum AppLaunchState {
  initializing,
  firstLaunch,
  subsequentLaunch,
  needLocationPermission,
  needPincodeSelection,
  needOutletSelection,
  readyToLaunch,
}

// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'SharedPreferences must be initialized and overridden at the root widget');
});

// Logger provider
final loggerProvider = Provider((ref) => Logger());

// Service providers
final locationServiceProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  
  // Check if Google Maps is initialized
  final isGoogleMapsInitialized = ref.watch(googleMapsInitializedProvider);
  
  if (isGoogleMapsInitialized) {
    // Use Google Maps service
    final googleMapsService = ref.watch(googleMapsServiceProvider);
    return LocationService(
      googleMapsService: googleMapsService,
      logger: logger
    );
  }
  
  // Use basic location service without Google Maps
  return LocationService(logger: logger);
});

final apiServiceProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  final apiClient = ApiClient(logger: logger);
  return ApiService(apiClient: apiClient, logger: logger);
});

final storageServiceProvider = Provider((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final logger = ref.watch(loggerProvider);
  return StorageService(prefs: prefs, logger: logger);
});

// Key to track if app has been launched before
const String _hasLaunchedBeforeKey = 'has_launched_before';

// Launch flow state notifier
final launchFlowProvider = StateNotifierProvider<LaunchFlowNotifier, AppLaunchState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final logger = ref.watch(loggerProvider);
  return LaunchFlowNotifier(ref, prefs, logger);
});

class LaunchFlowNotifier extends StateNotifier<AppLaunchState> {
  final Ref _ref;
  final SharedPreferences _prefs;
  final Logger _logger;

  LaunchFlowNotifier(this._ref, this._prefs, this._logger) 
      : super(AppLaunchState.initializing) {
    _initializeLaunchFlow();
  }

  Future<void> _initializeLaunchFlow() async {
    try {
      // Check if app has been launched before
      final hasLaunchedBefore = _prefs.getBool(_hasLaunchedBeforeKey) ?? false;
      final hasCompletedOnboarding = _prefs.getBool('hasCompletedOnboarding') ?? false;
      
      // If it's the first launch, update the state and save the flag
      if (!hasLaunchedBefore || !hasCompletedOnboarding) {
        await _prefs.setBool(_hasLaunchedBeforeKey, true);
        state = AppLaunchState.firstLaunch;
        _logger.log('First launch detected');
      } else {
        state = AppLaunchState.subsequentLaunch;
        _logger.log('Subsequent launch detected');
        _checkCachedData();
      }
    } catch (e) {
      _logger.error('Error initializing launch flow: $e');
      state = AppLaunchState.firstLaunch; // Default to first launch on error
    }
  }

  // Method called after onboarding completion
  void onboardingCompleted() {
    _logger.log('Onboarding completed, determining next step');
    // After onboarding, we need to check for location permission/pincode
    // Start with location permission check
    state = AppLaunchState.needLocationPermission;
  }

  // Check if we have cached data for subsequent launch
  void _checkCachedData() {
    try {
      final selectedPincode = _ref.read(selectedPincodeProvider);
      final selectedOutlet = _ref.read(selectedOutletProvider).value;
      
      _logger.log('Checking cached data - Pincode: $selectedPincode, Outlet: ${selectedOutlet?.name}');
      
      if (selectedPincode == null) {
        _logger.log('No pincode found, setting state to needPincodeSelection');
        state = AppLaunchState.needPincodeSelection;
      } else if (selectedOutlet == null) {
        _logger.log('Pincode found but no outlet, setting state to needOutletSelection');
        state = AppLaunchState.needOutletSelection;
      } else {
        _logger.log('Both pincode and outlet found, setting state to readyToLaunch');
        state = AppLaunchState.readyToLaunch;
      }
    } catch (e) {
      _logger.error('Error checking cached data: $e');
      state = AppLaunchState.needPincodeSelection;
    }
  }

  // Method to fetch user's location and check if pincode is serviceable
  Future<void> fetchLocationAndCheckPincode() async {
    try {
      _logger.log('Attempting to fetch location and check pincode');
      
      // Clear previous location info at the beginning to avoid state conflicts
      _ref.read(locationInfoProvider.notifier).state = LocationInfo();
      
      // Use a local variable to decide state changes
      AppLaunchState newState = state;
      
      // Determine correct state if needed
      if (state != AppLaunchState.needLocationPermission && 
          state != AppLaunchState.subsequentLaunch) {
        _logger.log('Setting state to needLocationPermission before fetching location');
        newState = AppLaunchState.needLocationPermission;
        state = newState;
      }
      
      // Check if location services are enabled in a safe way
      bool serviceEnabled;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _logger.log('Location services are disabled');
          _ref.read(locationInfoProvider.notifier).state = 
              LocationInfo(locationError: 'location_disabled');
          state = AppLaunchState.needPincodeSelection;
          return;
        }
      } catch (e) {
        _logger.error('Error checking location services: $e');
        _ref.read(locationInfoProvider.notifier).state = 
            LocationInfo(locationError: 'location_disabled');
        state = AppLaunchState.needPincodeSelection;
        return;
      }
      
      // Check location permission
      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _logger.log('Location permission denied');
            _ref.read(locationInfoProvider.notifier).state = 
                LocationInfo(locationError: 'permission_denied');
            state = AppLaunchState.needPincodeSelection;
            return;
          }
        }
        
        if (permission == LocationPermission.deniedForever) {
          _logger.log('Location permission permanently denied');
          _ref.read(locationInfoProvider.notifier).state = 
              LocationInfo(locationError: 'permission_denied');
          state = AppLaunchState.needPincodeSelection;
          return;
        }
      } catch (e) {
        _logger.error('Error checking location permission: $e');
        _ref.read(locationInfoProvider.notifier).state = 
            LocationInfo(locationError: 'permission_denied');
        state = AppLaunchState.needPincodeSelection;
        return;
      }
      
      // Get user's current location
      final locationService = _ref.read(locationServiceProvider);
      try {
        final position = await locationService.getCurrentPosition();
        
        if (position == null) {
          _logger.log('Could not get user position, setting state to needPincodeSelection');
          state = AppLaunchState.needPincodeSelection;
          return;
        }
        
        // Save the user's location regardless of serviceable status
        await _ref.read(storageServiceProvider).saveUserLocation(
          position.latitude,
          position.longitude,
        );
        
        // Get pincode from position
        final isGoogleMapsInitialized = _ref.read(googleMapsInitializedProvider);
        String? pincode;
        
        if (isGoogleMapsInitialized) {
          // Use Google Maps for more accurate pincode detection
          final googleMapsService = _ref.read(googleMapsServiceProvider);
          final coordinates = LatLng(position.latitude, position.longitude);
          pincode = await googleMapsService.getPincodeFromCoordinates(coordinates);
        } else {
          // Use basic location service as fallback
          pincode = await locationService.getPincodeFromCurrentLocation();
        }
        
        if (pincode == null) {
          _logger.log('Could not determine pincode, setting state to needPincodeSelection');
          state = AppLaunchState.needPincodeSelection;
          return;
        }
        
        _logger.log('Pincode detected: $pincode, checking if serviceable');
        
        // Check if the pincode is serviceable
        final isServiceable = await _ref.read(isPincodeServiceableProvider(pincode).future);
        
        if (isServiceable) {
          _logger.log('Pincode is serviceable, saving and moving to outlet selection');
          // Save the pincode and move to outlet selection
          await _ref.read(selectedPincodeProvider.notifier).selectPincode(pincode);
          state = AppLaunchState.needOutletSelection;
        } else {
          _logger.log('Pincode is not serviceable, setting state to needPincodeSelection');
          // Store the non-serviceable pincode for display
          _ref.read(locationInfoProvider.notifier).state = 
              LocationInfo(nonServiceablePincode: pincode);
          // If not serviceable, move to pincode selection
          state = AppLaunchState.needPincodeSelection;
        }
      } catch (e) {
        _logger.error('Error getting position: $e');
        _ref.read(locationInfoProvider.notifier).state = 
            LocationInfo(locationError: 'network_error');
        state = AppLaunchState.needPincodeSelection;
      }
    } catch (e) {
      _logger.error('Error fetching location and checking pincode: $e');
      state = AppLaunchState.needPincodeSelection;
    }
  }

  // Method called after pincode selection
  void pincodeSelected() {
    _logger.log('Pincode selected, moving to outlet selection');
    state = AppLaunchState.needOutletSelection;
  }

  // Method called after outlet selection
  void outletSelected() {
    _logger.log('Outlet selected, app is ready to launch');
    state = AppLaunchState.readyToLaunch;
  }

  // Reset to first launch (for testing)
  Future<void> resetToFirstLaunch() async {
    _logger.log('Resetting to first launch');
    await _prefs.setBool(_hasLaunchedBeforeKey, false);
    await _prefs.setBool('hasCompletedOnboarding', false);
    // Clear all stored data
    await _ref.read(storageServiceProvider).clearAllData();
    state = AppLaunchState.firstLaunch;
  }
}