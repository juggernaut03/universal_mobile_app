// lib/data/repositories/outlet_repository_impl.dart
//
// Implements IOutletRepository by adapting the existing ApiService and
// StorageService (Strangler Fig — same approach as auth in Phase 3a).

import '../../core/error/exceptions.dart';
import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/outlet.dart';
import '../../domain/entities/pincode.dart';
import '../../domain/repositories/i_outlet_repository.dart';
import '../models/outlet_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

final class OutletRepositoryImpl implements IOutletRepository {
  final ApiService _apiService;
  final StorageService _storageService;
  final Logger _logger;

  OutletRepositoryImpl({
    required ApiService apiService,
    required StorageService storageService,
    required Logger logger,
  })  : _apiService = apiService,
        _storageService = storageService,
        _logger = logger;

  @override
  Future<Result<List<Outlet>>> outletsForPincode(Pincode pincode) {
    return guard(() async {
      final models = await _apiService.getPincodewiseOutlet(pincode.value);
      return models.map((m) => m.toEntity()).toList(growable: false);
    });
  }

  @override
  Future<Result<void>> selectOutlet(Outlet outlet) {
    return guard(() async {
      final saved = await _storageService
          .saveSelectedOutlet(OutletModel.fromEntity(outlet));
      if (!saved) {
        throw CacheException('Could not persist outlet ${outlet.storeCode}');
      }
      _logger.log('Selected outlet ${outlet.storeCode}');
    });
  }

  @override
  Future<Result<Outlet>> selectedOutlet() {
    return guard(() async {
      final model = _storageService.getSelectedOutlet();
      if (model == null) {
        throw const NotFoundException('No outlet selected');
      }
      return model.toEntity();
    });
  }

  @override
  Future<Result<Outlet>> refreshStatus(String storeCode) {
    return guard(() async {
      // The universal backend exposes no real-time outlet-status endpoint —
      // OutletStatusService.checkOutletStatus() unconditionally returns null,
      // so everything polling it received nothing. The store list does carry a
      // live `is_enabled` flag, so re-reading the list for the selected pincode
      // gives a genuine answer instead of a no-op.
      final pincodeValue = _storageService.getSelectedPincode();
      final pincode = Pincode.tryParse(pincodeValue);
      if (pincode == null) {
        throw const NotFoundException(
          'Cannot refresh outlet status without a selected pincode',
        );
      }

      final models = await _apiService.getPincodewiseOutlet(pincode.value);
      final match = models.where((m) => m.storeCode == storeCode);
      if (match.isEmpty) {
        throw NotFoundException(
          'Outlet $storeCode no longer serves ${pincode.value}',
        );
      }
      return match.first.toEntity();
    });
  }
}
