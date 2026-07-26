// lib/domain/usecases/launch/resolve_delivery_location.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/delivery_location.dart';
import '../../entities/pincode.dart';
import '../../repositories/i_location_repository.dart';
import '../../repositories/i_outlet_repository.dart';

/// Works out where to deliver at app launch: detect position, resolve it to a
/// pincode, confirm we serve it, and confirm stores exist for it.
///
/// This was the body of `LaunchFlowNotifier.fetchLocationAndCheckPincode` — 155
/// lines inside a StateNotifier, reading seven providers through `_ref`, with
/// ten separate assignments to `state` interleaved with the I/O. None of it
/// could be tested without a device, a network and a real GPS fix.
///
/// The workflow is unchanged; it now returns one sealed outcome and performs no
/// state mutation, so the notifier's job reduces to mapping outcome to state.
final class ResolveDeliveryLocation
    extends UseCase<DeliveryLocationOutcome, NoParams> {
  final ILocationRepository _locationRepository;
  final IOutletRepository _outletRepository;

  const ResolveDeliveryLocation({
    required ILocationRepository locationRepository,
    required IOutletRepository outletRepository,
  })  : _locationRepository = locationRepository,
        _outletRepository = outletRepository;

  @override
  Future<Result<DeliveryLocationOutcome>> call(NoParams params) async {
    // 1. Position. Permission and location-services problems arrive as
    //    ValidationFailure from the repository, which is what distinguishes
    //    "user must change a setting" from "the network is down".
    final position = await _locationRepository.currentPosition();
    if (position case Err(:final failure)) {
      return Ok(DetectionFailed(_classify(failure)));
    }

    // 2. Reverse-geocode to a pincode.
    final detected = await _locationRepository.pincodeFromCurrentLocation();
    final Pincode pincode;
    switch (detected) {
      case Ok(:final value):
        pincode = value;
      case Err(:final failure):
        return Ok(DetectionFailed(
          failure is NotFoundFailure
              ? LocationIssue.pincodeNotDetected
              : _classify(failure),
        ));
    }

    // 3. Do we deliver there?
    final serviceability =
        await _locationRepository.checkServiceability(pincode);
    switch (serviceability) {
      case Err(:final failure):
        return Ok(DetectionFailed(_classify(failure)));
      case Ok(value: final result) when !result.isServiceable:
        return Ok(PincodeNotServiceable(
          pincode: pincode,
          message: result.unavailableMessage,
        ));
      case Ok():
        break;
    }

    // 4. Are there actually stores for it?
    //
    // A serviceable pincode with no outlets is a real configuration state, and
    // the original code handled it — it is not folded into "not serviceable".
    final outlets = await _outletRepository.outletsForPincode(pincode);
    return switch (outlets) {
      Err(:final failure) => Ok(DetectionFailed(_classify(failure))),
      Ok(value: final list) when list.isEmpty =>
        const Ok(DetectionFailed(LocationIssue.noOutletsForPincode)),
      Ok(value: final list) =>
        Ok(DeliveryAreaFound(pincode: pincode, outletCount: list.length)),
    };
  }

  /// Maps a transport-level failure onto the reason shown to the user.
  ///
  /// The location repository reports permission and location-services problems
  /// as ValidationFailure, carrying a message that names the exact setting.
  LocationIssue _classify(Failure failure) {
    if (failure is! ValidationFailure) return LocationIssue.networkError;

    final message = failure.message.toLowerCase();
    if (message.contains('permanently')) {
      return LocationIssue.permissionPermanentlyDenied;
    }
    if (message.contains('permission')) return LocationIssue.permissionDenied;
    if (message.contains('services are turned off')) {
      return LocationIssue.locationServicesDisabled;
    }
    return LocationIssue.networkError;
  }
}
