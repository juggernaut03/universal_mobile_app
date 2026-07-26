// lib/domain/usecases/location/select_pincode.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/pincode.dart';
import '../../repositories/i_location_repository.dart';

final class SelectPincodeParams extends UseCaseParams {
  final String pincode;

  const SelectPincodeParams({required this.pincode});

  @override
  List<Object?> get props => [pincode];
}

/// Sets the delivery pincode, refusing one we do not serve.
///
/// The serviceability check runs here rather than in the screen, so no caller
/// can persist an unserviceable pincode by forgetting to check first.
final class SelectPincode extends UseCase<Serviceability, SelectPincodeParams> {
  final ILocationRepository _repository;

  const SelectPincode(this._repository);

  @override
  Future<Result<Serviceability>> call(SelectPincodeParams params) async {
    final pincode = Pincode.tryParse(params.pincode);
    if (pincode == null) {
      return const Err(ValidationFailure('Please enter a valid 6-digit pincode.'));
    }

    final check = await _repository.checkServiceability(pincode);
    return switch (check) {
      Err(:final failure) => Err(failure),
      Ok(value: final serviceability) when !serviceability.isServiceable =>
        Err(ValidationFailure(serviceability.unavailableMessage)),
      Ok(value: final serviceability) =>
        (await _repository.selectPincode(pincode)).map((_) => serviceability),
    };
  }
}
