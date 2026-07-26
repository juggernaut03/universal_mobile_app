// lib/presentation/providers/outlet_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/outlet_repository.dart';
import '../../data/models/outlet_model.dart';
import '../../data/models/offer_model.dart';
import 'location_provider.dart';
import '../../di/repository_providers.dart';
import '../../di/infrastructure_providers.dart';

// Provider for the Outlet Repository

// Available outlets for a specific pincode provider - refreshable
final availableOutletsProvider = FutureProvider.family<List<OutletModel>, String>((ref, pincode) async {
  final repository = ref.watch(outletRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  
  try {
    logger.log('Fetching outlets for pincode: $pincode');
    final outlets = await repository.getOutletsForPincode(pincode);
    logger.log('Retrieved ${outlets.length} outlets for pincode: $pincode');
    return outlets;
  } catch (e) {
    logger.error('Error fetching outlets for pincode $pincode: $e');
    return [];
  }
});

// Selected outlet provider
final selectedOutletProvider = StateNotifierProvider<SelectedOutletNotifier, AsyncValue<OutletModel?>>((ref) {
  final repository = ref.watch(outletRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  return SelectedOutletNotifier(repository, logger);
});

// Selected outlet notifier
class SelectedOutletNotifier extends StateNotifier<AsyncValue<OutletModel?>> {
  final OutletRepository _repository;
  final Logger _logger;

  SelectedOutletNotifier(this._repository, this._logger) 
      : super(const AsyncValue.loading()) {
    _loadSavedOutlet();
  }

  Future<void> _loadSavedOutlet() async {
    try {
      final outlet = _repository.getSelectedOutlet();
      _logger.log('Loaded saved outlet: ${outlet?.name}');
      state = AsyncValue.data(outlet);
    } catch (e) {
      _logger.error('Error loading saved outlet: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> selectOutlet(OutletModel outlet) async {
    try {
      _logger.log('Saving outlet: ${outlet.name}');
      state = const AsyncValue.loading();
      final result = await _repository.saveSelectedOutlet(outlet);
      if (result) {
        state = AsyncValue.data(outlet);
        _logger.log('Outlet saved successfully');
      } else {
        _logger.error('Failed to save outlet');
        state = const AsyncValue.data(null);
      }
      return result;
    } catch (e) {
      _logger.error('Error selecting outlet: $e');
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
  
  // Clear the selected outlet
  Future<bool> clearOutlet() async {
    try {
      _logger.log('Clearing outlet');
      state = const AsyncValue.loading();
      // The repository doesn't have a direct method to clear, so we need to save null
      // In a real app, you'd want to add a clearSelectedOutlet method to the repository
      final result = await _repository.saveSelectedOutlet(
        // This creates a dummy outlet with empty values that will be treated as "no outlet"
        OutletModel(
          id: '',
          name: '',
          storeCode: '',
          address: '',
          minOrderAmount: 0,
          openTime: '',
          deliveryTime: '',
          offerName: '',
          latitude: '',
          longitude: '',
        )
      );
      
      if (result) {
        state = const AsyncValue.data(null);
        _logger.log('Outlet cleared successfully');
      } else {
        _logger.error('Failed to clear outlet');
        // Reload the current outlet to restore state
        _loadSavedOutlet();
      }
      return result;
    } catch (e) {
      _logger.error('Error clearing outlet: $e');
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

// Offer banner provider - refreshable
final offerBannerProvider = FutureProvider<OfferModel?>((ref) async {
  final outletAsync = ref.watch(selectedOutletProvider);
  final repository = ref.watch(outletRepositoryProvider);
  final logger = ref.watch(loggerProvider);

  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null || outlet.storeCode.isEmpty) {
        logger.log('No outlet selected or store code is empty, cannot fetch offer banner');
        return null;
      }
      
      try {
        logger.log('Fetching offer banner for store: ${outlet.storeCode}');
        final offerModel = await repository.getOfferForOutlet(outlet.storeCode);
        logger.log('Retrieved offer banner: ${offerModel.imageUrl}');
        return offerModel;
      } catch (e) {
        logger.error('Error fetching offer banner: $e');
        return null;
      }
    },
    loading: () => null,
    error: (error, stack) {
      logger.error('Error in selectedOutletProvider: $error');
      return null;
    },
  );
});

// Provide a list of all available stores for the current pincode
final availableStoresProvider = FutureProvider<List<OutletModel>>((ref) async {
  final selectedPincode = ref.watch(selectedPincodeProvider);
  if (selectedPincode == null) return [];
  
  final repository = ref.watch(outletRepositoryProvider);
  try {
    final outlets = await repository.getOutletsForPincode(selectedPincode);
    return outlets;
  } catch (e) {
    ref.read(loggerProvider).error('Error fetching available stores: $e');
    return [];
  }
});