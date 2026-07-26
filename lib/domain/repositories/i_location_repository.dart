// lib/domain/repositories/i_location_repository.dart

import '../../core/result/result.dart';
import '../entities/outlet.dart';
import '../entities/pincode.dart';

/// Device location and delivery-area questions.
abstract interface class ILocationRepository {
  /// The device's current coordinates.
  ///
  /// Yields `Err(ValidationFailure)` when permission is denied and
  /// `Err(NetworkFailure)` when location services are off — the previous
  /// `Future<Position?>` collapsed both into null, so the UI could not tell the
  /// user which setting to change.
  Future<Result<GeoPoint>> currentPosition();

  /// Reverse-geocodes the device's position to a pincode.
  Future<Result<Pincode>> pincodeFromCurrentLocation();

  /// Whether the app delivers to [pincode].
  Future<Result<Serviceability>> checkServiceability(Pincode pincode);

  /// Every pincode the app serves.
  Future<Result<List<Pincode>>> serviceablePincodes();

  /// Persists the customer's chosen delivery pincode.
  Future<Result<void>> selectPincode(Pincode pincode);

  /// The currently selected pincode, or `Err(NotFoundFailure)` when unset.
  Future<Result<Pincode>> selectedPincode();

  /// Straight-line distance in kilometres between two points.
  Future<Result<double>> distanceBetween(GeoPoint from, GeoPoint to);
}
