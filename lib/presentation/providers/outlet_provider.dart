// lib/presentation/providers/outlet_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../data/models/outlet_model.dart';
import '../../data/models/offer_model.dart';
import 'location_provider.dart';
import '../../di/repository_providers.dart';
import '../../di/infrastructure_providers.dart';
import '../../core/result/result.dart';
import '../../di/location_providers.dart';
import '../../domain/repositories/i_outlet_repository.dart';
import '../../domain/usecases/outlet/get_outlets_for_pincode.dart';

// Provider for the Outlet Repository

// Available outlets for a specific pincode provider - refreshable
final availableOutletsProvider =
    FutureProvider.family<List<OutletModel>, String>((ref, pincode) async {
  final logger = ref.watch(loggerProvider);

  final result = await ref.watch(getOutletsForPincodeUseCaseProvider)(
    GetOutletsForPincodeParams(pincode: pincode),
  );

  return switch (result) {
    Ok(:final value) =>
      value.map(OutletModel.fromEntity).toList(growable: false),
    // TODO(phase-3b): still swallows the failure to preserve the previous
    // behaviour — an empty list here means either "no outlets" or "the call
    // failed". Surfacing it changes what the outlet picker renders, so it is
    // done when that screen is migrated.
    Err(:final failure) => () {
        logger.error('Outlets for $pincode unavailable: ${failure.message}');
        return <OutletModel>[];
      }(),
  };
});

// Selected outlet provider
final selectedOutletProvider =
    StateNotifierProvider<SelectedOutletNotifier, AsyncValue<OutletModel?>>((ref) {
  return SelectedOutletNotifier(
    ref.watch(outletRepositoryDomainProvider),
    ref.watch(loggerProvider),
  );
});

// Selected outlet notifier
/// Holds the selected outlet.
///
/// Still exposes OutletModel because 12 features read this provider; the
/// repository underneath is the domain interface.
class SelectedOutletNotifier extends StateNotifier<AsyncValue<OutletModel?>> {
  final IOutletRepository _repository;
  final Logger _logger;

  /// Completes once the saved outlet has been read from storage.
  ///
  /// See the note on SelectedPincodeNotifier.ready — the launch flow inspected
  /// this notifier while it was still `AsyncValue.loading()`, whose `.value` is
  /// null, and concluded no store had ever been chosen.
  late final Future<void> _ready;

  Future<void> get ready => _ready;

  SelectedOutletNotifier(this._repository, this._logger)
      : super(const AsyncValue.loading()) {
    _ready = _loadSavedOutlet();
  }

  Future<void> _loadSavedOutlet() async {
    final result = await _repository.selectedOutlet();
    switch (result) {
      case Ok(:final value):
        _logger.log('Loaded saved outlet: ${value.name}');
        state = AsyncValue.data(OutletModel.fromEntity(value));
      case Err(:final failure):
        // No outlet selected yet is the normal first-run state, not an error.
        _logger.log('No saved outlet: ${failure.message}');
        state = const AsyncValue.data(null);
    }
  }

  Future<bool> selectOutlet(OutletModel outlet) async {
    try {
      _logger.log('Saving outlet: ${outlet.name}');
      state = const AsyncValue.loading();
      final result = await _repository.selectOutlet(outlet.toEntity());
      switch (result) {
        case Ok():
          state = AsyncValue.data(outlet);
          _logger.log('Outlet saved successfully');
          return true;
        case Err(:final failure):
          _logger.error('Failed to save outlet: ${failure.message}');
          state = const AsyncValue.data(null);
          return false;
      }
    } catch (e) {
      _logger.error('Error selecting outlet: $e');
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
  
  // Clear the selected outlet
  Future<bool> clearOutlet() async {
    _logger.log('Clearing outlet');
    state = const AsyncValue.loading();

    // Was implemented by saving a dummy OutletModel with empty fields, which
    // loaded back as a real outlet with an empty store code.
    final result = await _repository.clearSelection();
    switch (result) {
      case Ok():
        state = const AsyncValue.data(null);
        _logger.log('Outlet cleared successfully');
        return true;
      case Err(:final failure):
        _logger.error('Failed to clear outlet: ${failure.message}');
        await _loadSavedOutlet();
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