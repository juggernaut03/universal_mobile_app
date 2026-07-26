// test/domain/resolve_delivery_location_test.dart
//
// The launch-time delivery-area workflow.
//
// This logic previously lived inside LaunchFlowNotifier as a 155-line method
// that read seven providers and mutated state ten times. Testing it required a
// device, a network and a real GPS fix — so it was never tested. Every branch
// is covered here in milliseconds.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/core/usecase/usecase.dart';
import 'package:patelmart/domain/entities/delivery_location.dart';
import 'package:patelmart/domain/entities/outlet.dart';
import 'package:patelmart/domain/entities/pincode.dart';
import 'package:patelmart/domain/repositories/i_location_repository.dart';
import 'package:patelmart/domain/repositories/i_outlet_repository.dart';
import 'package:patelmart/domain/usecases/launch/resolve_delivery_location.dart';

final class _FakeLocationRepo implements ILocationRepository {
  Result<GeoPoint> position =
      const Ok(GeoPoint(latitude: 19.0, longitude: 72.0));
  Result<Pincode> detected = Ok(Pincode.tryParse('400001')!);
  Result<Serviceability>? serviceability;

  @override
  Future<Result<GeoPoint>> currentPosition() async => position;

  @override
  Future<Result<Pincode>> pincodeFromCurrentLocation() async => detected;

  @override
  Future<Result<Serviceability>> checkServiceability(Pincode pincode) async =>
      serviceability ??
      Ok(Serviceability(pincode: pincode, isServiceable: true));

  @override
  Future<Result<List<Pincode>>> serviceablePincodes() async => const Ok([]);

  @override
  Future<Result<void>> selectPincode(Pincode pincode) async => const Ok(null);

  @override
  Future<Result<void>> clearSelectedPincode() async => const Ok(null);

  @override
  Future<Result<Pincode>> selectedPincode() async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<double>> distanceBetween(GeoPoint from, GeoPoint to) async =>
      const Ok(0);
}

final class _FakeOutletRepo implements IOutletRepository {
  Result<List<Outlet>> outlets = Ok([_outlet()]);

  @override
  Future<Result<List<Outlet>>> outletsForPincode(Pincode pincode) async =>
      outlets;

  @override
  Future<Result<void>> selectOutlet(Outlet outlet) async => const Ok(null);

  @override
  Future<Result<Outlet>> selectedOutlet() async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<void>> clearSelection() async => const Ok(null);

  @override
  Future<Result<Outlet>> refreshStatus(String storeCode) async =>
      const Err(NotFoundFailure('none'));
}

Outlet _outlet([String storeCode = 'KLK']) => Outlet(
      id: 'id',
      storeCode: storeCode,
      name: 'Store',
      address: '',
      minOrderAmount: 0,
    );

void main() {
  late _FakeLocationRepo location;
  late _FakeOutletRepo outlets;

  setUp(() {
    location = _FakeLocationRepo();
    outlets = _FakeOutletRepo();
  });

  Future<DeliveryLocationOutcome> run() async {
    final result = await ResolveDeliveryLocation(
      locationRepository: location,
      outletRepository: outlets,
    )(const NoParams());
    return result.valueOrNull!;
  }

  group('happy path', () {
    test('reports the area found with its outlet count', () async {
      outlets.outlets = Ok([_outlet('KLK'), _outlet('AND')]);

      final outcome = await run();

      expect(outcome, isA<DeliveryAreaFound>());
      final found = outcome as DeliveryAreaFound;
      expect(found.pincode.value, '400001');
      expect(found.outletCount, 2);
    });
  });

  group('position failures map to the right issue', () {
    test('location services off', () async {
      location.position = const Err(
        ValidationFailure('Location services are turned off. Please enable them.'),
      );

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.locationServicesDisabled,
      );
    });

    test('permission denied', () async {
      location.position =
          const Err(ValidationFailure('Location permission is needed.'));

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.permissionDenied,
      );
    });

    test('permission permanently denied is distinct from denied', () async {
      // Different recovery: one re-prompts, the other must go to Settings.
      location.position = const Err(
        ValidationFailure('Location permission is permanently denied.'),
      );

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.permissionPermanentlyDenied,
      );
    });

    test('a network failure is not reported as a permission problem', () async {
      location.position = const Err(NetworkFailure('offline'));

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.networkError,
      );
    });
  });

  group('pincode detection', () {
    test('not-found becomes pincodeNotDetected', () async {
      location.detected = const Err(NotFoundFailure('no pincode'));

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.pincodeNotDetected,
      );
    });

    test('a transport failure becomes networkError', () async {
      location.detected = const Err(NetworkFailure('offline'));

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.networkError,
      );
    });
  });

  group('serviceability', () {
    test('an unserviceable pincode is reported with the pincode itself',
        () async {
      final pincode = Pincode.tryParse('400001')!;
      location.serviceability = Ok(Serviceability(
        pincode: pincode,
        isServiceable: false,
        message: 'Coming soon',
      ));

      final outcome = await run();

      expect(outcome, isA<PincodeNotServiceable>());
      expect((outcome as PincodeNotServiceable).pincode.value, '400001');
      expect(outcome.message, 'Coming soon');
    });

    test('a failed check is a network issue, not "not serviceable"', () async {
      // The distinction the old code lost: it returned false either way, so an
      // offline user was told we do not deliver to their area.
      location.serviceability = const Err(NetworkFailure('offline'));

      final outcome = await run();

      expect(outcome, isA<DetectionFailed>());
      expect((outcome as DetectionFailed).issue, LocationIssue.networkError);
    });
  });

  group('outlets', () {
    test('serviceable pincode with no stores is its own outcome', () async {
      outlets.outlets = const Ok([]);

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.noOutletsForPincode,
      );
    });

    test('a failed outlet lookup becomes networkError', () async {
      outlets.outlets = const Err(ServerFailure('boom', statusCode: 500));

      expect(
        (await run() as DetectionFailed).issue,
        LocationIssue.networkError,
      );
    });
  });

  group('LocationIssue', () {
    test('every issue has a non-empty user message', () {
      for (final issue in LocationIssue.values) {
        expect(issue.userMessage, isNotEmpty, reason: '$issue');
      }
    });

    test('settings-fixable issues are flagged as such', () {
      expect(LocationIssue.locationServicesDisabled.isUserFixable, isTrue);
      expect(LocationIssue.permissionDenied.isUserFixable, isTrue);
      expect(LocationIssue.networkError.isUserFixable, isFalse);
      expect(LocationIssue.noOutletsForPincode.isUserFixable, isFalse);
    });

    test('legacy codes still map for screens mid-migration', () {
      expect(LocationIssue.locationServicesDisabled.legacyCode,
          'location_disabled');
      expect(LocationIssue.noOutletsForPincode.legacyCode, 'no_outlets');
    });
  });
}
