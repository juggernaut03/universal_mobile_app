// lib/domain/usecases/outlet/get_outlets_for_pincode.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/outlet.dart';
import '../../entities/pincode.dart';
import '../../repositories/i_outlet_repository.dart';

final class GetOutletsForPincodeParams extends UseCaseParams {
  final String pincode;

  const GetOutletsForPincodeParams({required this.pincode});

  @override
  List<Object?> get props => [pincode];
}

/// Lists the outlets that serve a pincode.
///
/// Takes a raw string and validates it here, so the 6-digit rule is enforced
/// once rather than re-checked by each screen.
final class GetOutletsForPincode
    extends UseCase<List<Outlet>, GetOutletsForPincodeParams> {
  final IOutletRepository _repository;

  const GetOutletsForPincode(this._repository);

  @override
  Future<Result<List<Outlet>>> call(GetOutletsForPincodeParams params) async {
    final pincode = Pincode.tryParse(params.pincode);
    if (pincode == null) {
      return const Err(ValidationFailure('Please enter a valid 6-digit pincode.'));
    }
    return _repository.outletsForPincode(pincode);
  }
}
