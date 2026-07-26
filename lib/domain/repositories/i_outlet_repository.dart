// lib/domain/repositories/i_outlet_repository.dart

import '../../core/result/result.dart';
import '../entities/outlet.dart';
import '../entities/pincode.dart';

/// Store selection and store availability.
///
/// Absorbs what `outlet_status_provider` handled separately: an outlet's
/// trading state is a property of the outlet, not a parallel object fetched
/// down a different path.
abstract interface class IOutletRepository {
  /// Outlets that serve [pincode]. An empty list is a success.
  Future<Result<List<Outlet>>> outletsForPincode(Pincode pincode);

  /// Persists the customer's chosen outlet.
  Future<Result<void>> selectOutlet(Outlet outlet);

  /// The currently selected outlet, or `Err(NotFoundFailure)` when none is set.
  Future<Result<Outlet>> selectedOutlet();

  /// Re-reads an outlet's live trading state.
  ///
  /// Separate from [outletsForPincode] because it is polled while the user
  /// shops, to catch a store closing mid-session.
  Future<Result<Outlet>> refreshStatus(String storeCode);
}
