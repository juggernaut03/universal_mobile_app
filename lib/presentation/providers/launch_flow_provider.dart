// lib/presentation/providers/launch_flow_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import '../../di/infrastructure_providers.dart';
import 'location_provider.dart';
import 'outlet_provider.dart';
import '../../di/service_providers.dart';
import '../../core/result/result.dart';
import '../../core/usecase/usecase.dart';
import '../../di/location_providers.dart';
import '../../domain/entities/delivery_location.dart';


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

// Service providers



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
  /// Detects the delivery area and moves the launch flow to the next step.
  ///
  /// Was 155 lines of interleaved I/O and state assignment. The workflow now
  /// lives in the ResolveDeliveryLocation use case; this method's only job is
  /// mapping its sealed outcome onto launch state and the UI's LocationInfo.
  Future<void> fetchLocationAndCheckPincode() async {
    _logger.log('Resolving delivery location');
    _ref.read(locationInfoProvider.notifier).state = LocationInfo();

    if (state != AppLaunchState.needLocationPermission &&
        state != AppLaunchState.subsequentLaunch) {
      state = AppLaunchState.needLocationPermission;
    }

    final result =
        await _ref.read(resolveDeliveryLocationUseCaseProvider)(const NoParams());

    switch (result) {
      case Err(:final failure):
        // The use case reports detection problems as Ok(DetectionFailed); an
        // Err here means something genuinely unexpected broke.
        _logger.error('Delivery location resolution failed: ${failure.message}');
        _ref.read(locationInfoProvider.notifier).state =
            LocationInfo(issue: LocationIssue.networkError);
        state = AppLaunchState.needPincodeSelection;

      case Ok(value: final outcome):
        await _applyOutcome(outcome);
    }
  }

  Future<void> _applyOutcome(DeliveryLocationOutcome outcome) async {
    switch (outcome) {
      case DeliveryAreaFound(:final pincode, :final outletCount):
        _logger.log('$outletCount outlet(s) serve ${pincode.value}');
        // Kept as the persistence path so selectedPincodeProvider — which the
        // rest of the UI watches — stays in sync.
        final saved = await _ref
            .read(selectedPincodeProvider.notifier)
            .selectPincode(pincode.value);
        state = saved
            ? AppLaunchState.needOutletSelection
            : AppLaunchState.needPincodeSelection;
        if (!saved) {
          _logger.error('Could not persist pincode ${pincode.value}');
        }

      case PincodeNotServiceable(:final pincode):
        _logger.log('${pincode.value} is not serviceable');
        _ref.read(locationInfoProvider.notifier).state =
            LocationInfo(nonServiceablePincode: pincode.value);
        state = AppLaunchState.needPincodeSelection;

      case DetectionFailed(:final issue):
        _logger.log('Detection failed: $issue');
        _ref.read(locationInfoProvider.notifier).state =
            LocationInfo(issue: issue);
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