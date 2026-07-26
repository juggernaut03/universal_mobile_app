// lib/domain/usecases/address/save_address.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/customer_address.dart';
import '../../entities/pincode.dart';
import '../../repositories/i_address_repository.dart';

final class SaveAddressParams {
  final CustomerAddress address;

  /// True for a new address, false when editing an existing one.
  final bool isNew;

  const SaveAddressParams({required this.address, required this.isNew});
}

/// Adds or updates a delivery address.
///
/// Validation runs here, once, rather than being re-implemented in
/// add_address_screen and edit_address_screen — two 700-line files that each
/// had their own field checks.
final class SaveAddress extends UseCase<void, SaveAddressParams> {
  final IAddressRepository _repository;

  const SaveAddress(this._repository);

  @override
  Future<Result<void>> call(SaveAddressParams params) async {
    final address = params.address;
    final fieldErrors = <String, String>{};

    if (address.fullName.trim().isEmpty) {
      fieldErrors['fullName'] = 'Please enter a name';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(address.mobileNumber.trim())) {
      fieldErrors['mobileNumber'] = 'Enter a valid 10-digit mobile number';
    }
    if (address.line1.trim().isEmpty) {
      fieldErrors['line1'] = 'Please enter the address';
    }
    if (!Pincode.isValid(address.pincode)) {
      fieldErrors['pincode'] = 'Enter a valid 6-digit pincode';
    }

    if (fieldErrors.isNotEmpty) {
      return Err(ValidationFailure(
        'Please correct the highlighted fields.',
        fieldErrors: fieldErrors,
      ));
    }

    return params.isNew
        ? _repository.add(address)
        : _repository.update(address);
  }
}
