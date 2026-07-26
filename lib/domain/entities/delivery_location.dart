// lib/domain/entities/delivery_location.dart
//
// Outcomes of trying to work out where to deliver, at app launch.
//
// Replaces the magic strings LaunchFlowNotifier wrote into
// `LocationInfo.locationError`: 'location_disabled', 'permission_denied',
// 'pincode_not_found', 'no_outlets', 'network_error'. Only three of those five
// were ever handled — pincode_selection_screen compared them by string and let
// the other two fall through to a generic message.

import 'package:meta/meta.dart';

import 'pincode.dart';

/// Why automatic delivery-area detection could not complete.
///
/// An enum rather than a string, so adding a case forces every `switch` to be
/// updated instead of silently taking the default branch.
enum LocationIssue {
  /// Device location services are switched off system-wide.
  locationServicesDisabled,

  /// The user declined the permission prompt this time.
  permissionDenied,

  /// The user declined permanently; only Settings can restore it.
  permissionPermanentlyDenied,

  /// A fix was obtained but could not be resolved to a pincode.
  pincodeNotDetected,

  /// A valid, serviceable pincode with no stores attached to it.
  noOutletsForPincode,

  /// The lookup failed for network or server reasons.
  networkError;

  /// Whether the user can fix this themselves in device settings.
  bool get isUserFixable =>
      this == locationServicesDisabled ||
      this == permissionDenied ||
      this == permissionPermanentlyDenied;

  /// Message shown above the manual pincode picker.
  String get userMessage => switch (this) {
        LocationIssue.locationServicesDisabled =>
          'Location services are turned off. Enable them or enter your pincode below.',
        LocationIssue.permissionDenied =>
          'Location permission is needed to detect your area. You can enter your pincode instead.',
        LocationIssue.permissionPermanentlyDenied =>
          'Location permission is blocked. Enable it in Settings, or enter your pincode below.',
        LocationIssue.pincodeNotDetected =>
          'We could not determine your pincode. Please enter it below.',
        LocationIssue.noOutletsForPincode =>
          'No stores currently deliver to that pincode. Try another one.',
        LocationIssue.networkError =>
          'We could not reach our servers. Check your connection, or enter your pincode below.',
      };

  /// The legacy string this issue used to be represented by.
  ///
  /// Kept only so screens still comparing strings keep working during the
  /// migration; delete once they switch to the enum.
  String get legacyCode => switch (this) {
        LocationIssue.locationServicesDisabled => 'location_disabled',
        LocationIssue.permissionDenied => 'permission_denied',
        LocationIssue.permissionPermanentlyDenied => 'permission_denied',
        LocationIssue.pincodeNotDetected => 'pincode_not_found',
        LocationIssue.noOutletsForPincode => 'no_outlets',
        LocationIssue.networkError => 'network_error',
      };
}

/// The result of automatic delivery-area detection.
///
/// Sealed, so the launch flow must handle every case. The previous code
/// expressed these outcomes as ten scattered assignments to `state` and
/// `locationInfoProvider` inside one 155-line method.
@immutable
sealed class DeliveryLocationOutcome {
  const DeliveryLocationOutcome();
}

/// A serviceable pincode was detected and stores are available for it.
final class DeliveryAreaFound extends DeliveryLocationOutcome {
  final Pincode pincode;

  /// How many outlets serve it. Always at least one.
  final int outletCount;

  const DeliveryAreaFound({required this.pincode, required this.outletCount});
}

/// A pincode was detected but we do not deliver there.
///
/// Distinct from [DetectionFailed] because we know exactly which pincode was
/// rejected, and the UI shows it back to the user.
final class PincodeNotServiceable extends DeliveryLocationOutcome {
  final Pincode pincode;
  final String message;

  const PincodeNotServiceable({required this.pincode, this.message = ''});
}

/// Detection could not complete; the user must pick a pincode manually.
final class DetectionFailed extends DeliveryLocationOutcome {
  final LocationIssue issue;

  const DetectionFailed(this.issue);
}
