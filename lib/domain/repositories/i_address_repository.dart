// lib/domain/repositories/i_address_repository.dart

import '../../core/result/result.dart';
import '../entities/customer_address.dart';

/// Saved delivery addresses.
///
/// Every method returned `Future<bool>` before, so a validation rejection, an
/// expired session and a dropped connection were the same `false`.
abstract interface class IAddressRepository {
  Future<Result<List<CustomerAddress>>> list();

  Future<Result<void>> add(CustomerAddress address);

  Future<Result<void>> update(CustomerAddress address);

  Future<Result<void>> delete(String addressId);

  Future<Result<void>> setDefault(String addressId);
}
