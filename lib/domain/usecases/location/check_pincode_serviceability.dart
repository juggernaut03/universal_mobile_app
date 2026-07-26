// lib/domain/usecases/location/check_pincode_serviceability.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/pincode.dart';
import '../../repositories/i_location_repository.dart';

final class CheckPincodeServiceabilityParams extends UseCaseParams {
  final String pincode;

  const CheckPincodeServiceabilityParams({required this.pincode});

  @override
  List<Object?> get props => [pincode];
}

/// Asks whether the app delivers to a pincode.
///
/// A non-serviceable pincode is a successful answer carrying
/// `isServiceable: false` — not a failure. Only a malformed pincode or a
/// broken call is an `Err`.
final class CheckPincodeServiceability
    extends UseCase<Serviceability, CheckPincodeServiceabilityParams> {
  final ILocationRepository _repository;

  const CheckPincodeServiceability(this._repository);

  @override
  Future<Result<Serviceability>> call(
      CheckPincodeServiceabilityParams params) async {
    final pincode = Pincode.tryParse(params.pincode);
    if (pincode == null) {
      return const Err(ValidationFailure('Please enter a valid 6-digit pincode.'));
    }
    return _repository.checkServiceability(pincode);
  }
}
