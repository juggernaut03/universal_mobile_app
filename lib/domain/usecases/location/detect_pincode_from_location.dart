// lib/domain/usecases/location/detect_pincode_from_location.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/pincode.dart';
import '../../repositories/i_location_repository.dart';

/// Resolves the device's location to a pincode.
///
/// Permission-denied and location-services-off arrive as distinct failures, so
/// the UI can point the user at the right setting instead of showing one
/// generic message.
final class DetectPincodeFromLocation extends UseCase<Pincode, NoParams> {
  final ILocationRepository _repository;

  const DetectPincodeFromLocation(this._repository);

  @override
  Future<Result<Pincode>> call(NoParams params) =>
      _repository.pincodeFromCurrentLocation();
}
