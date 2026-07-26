// lib/domain/usecases/location/get_serviceable_pincodes.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/pincode.dart';
import '../../repositories/i_location_repository.dart';

/// Lists every pincode the app serves, for the manual picker.
final class GetServiceablePincodes extends UseCase<List<Pincode>, NoParams> {
  final ILocationRepository _repository;

  const GetServiceablePincodes(this._repository);

  @override
  Future<Result<List<Pincode>>> call(NoParams params) =>
      _repository.serviceablePincodes();
}
