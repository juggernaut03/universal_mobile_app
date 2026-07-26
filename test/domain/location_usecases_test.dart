// test/domain/location_usecases_test.dart
//
// Use-case rules for outlet and pincode selection, against fake repositories.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/core/usecase/usecase.dart';
import 'package:patelmart/domain/entities/outlet.dart';
import 'package:patelmart/domain/entities/pincode.dart';
import 'package:patelmart/domain/repositories/i_location_repository.dart';
import 'package:patelmart/domain/repositories/i_outlet_repository.dart';
import 'package:patelmart/domain/usecases/location/check_pincode_serviceability.dart';
import 'package:patelmart/domain/usecases/location/select_pincode.dart';
import 'package:patelmart/domain/usecases/outlet/get_outlets_for_pincode.dart';
import 'package:patelmart/domain/usecases/outlet/select_outlet.dart';

final class _FakeOutletRepo implements IOutletRepository {
  Pincode? lastQueried;
  Outlet? persisted;
  List<Outlet> outlets = const [];

  @override
  Future<Result<List<Outlet>>> outletsForPincode(Pincode pincode) async {
    lastQueried = pincode;
    return Ok(outlets);
  }

  @override
  Future<Result<void>> selectOutlet(Outlet outlet) async {
    persisted = outlet;
    return const Ok(null);
  }

  @override
  Future<Result<Outlet>> selectedOutlet() async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<void>> clearSelection() async => const Ok(null);

  @override
  Future<Result<Outlet>> refreshStatus(String storeCode) async =>
      const Err(NotFoundFailure('none'));
}

final class _FakeLocationRepo implements ILocationRepository {
  Serviceability? serviceability;
  Pincode? persisted;
  Failure? checkFailure;

  @override
  Future<Result<Serviceability>> checkServiceability(Pincode pincode) async {
    if (checkFailure != null) return Err(checkFailure!);
    return Ok(serviceability ??
        Serviceability(pincode: pincode, isServiceable: true));
  }

  @override
  Future<Result<void>> selectPincode(Pincode pincode) async {
    persisted = pincode;
    return const Ok(null);
  }

  @override
  Future<Result<GeoPoint>> currentPosition() async =>
      const Err(NetworkFailure('n/a'));

  @override
  Future<Result<Pincode>> pincodeFromCurrentLocation() async =>
      const Err(NetworkFailure('n/a'));

  @override
  Future<Result<List<Pincode>>> serviceablePincodes() async => const Ok([]);

  @override
  Future<Result<void>> clearSelectedPincode() async => const Ok(null);

  @override
  Future<Result<Pincode>> selectedPincode() async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<double>> distanceBetween(GeoPoint from, GeoPoint to) async =>
      const Ok(0);
}

Outlet outlet({
  String storeCode = 'KLK',
  bool isEnabled = true,
  Set<FulfilmentMethod> methods = const {FulfilmentMethod.homeDelivery},
  String storeMessage = '',
}) =>
    Outlet(
      id: 'id',
      storeCode: storeCode,
      name: 'Store',
      address: '',
      minOrderAmount: 0,
      isEnabled: isEnabled,
      fulfilmentMethods: methods,
      storeMessage: storeMessage,
    );

void main() {
  group('GetOutletsForPincode', () {
    late _FakeOutletRepo repo;
    setUp(() => repo = _FakeOutletRepo());

    test('rejects a malformed pincode without calling the repository', () async {
      final result = await GetOutletsForPincode(repo)(
        const GetOutletsForPincodeParams(pincode: '123'),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.lastQueried, isNull);
    });

    test('passes a valid pincode through', () async {
      final result = await GetOutletsForPincode(repo)(
        const GetOutletsForPincodeParams(pincode: '400001'),
      );

      expect(result.isOk, isTrue);
      expect(repo.lastQueried?.value, '400001');
    });

    test('an empty outlet list is a success, not a failure', () async {
      final result = await GetOutletsForPincode(repo)(
        const GetOutletsForPincodeParams(pincode: '400001'),
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('SelectOutlet', () {
    late _FakeOutletRepo repo;
    setUp(() => repo = _FakeOutletRepo());

    test('persists an outlet that can take orders', () async {
      final result =
          await SelectOutlet(repo)(SelectOutletParams(outlet: outlet()));

      expect(result.isOk, isTrue);
      expect(repo.persisted?.storeCode, 'KLK');
    });

    test('refuses a closed outlet and never persists it', () async {
      // Previously nothing stopped a closed store becoming the active one; the
      // failure only surfaced later, at checkout.
      final result = await SelectOutlet(repo)(
        SelectOutletParams(
          outlet: outlet(isEnabled: false, storeMessage: 'Closed for stocktake'),
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull!.userMessage, 'Closed for stocktake');
      expect(repo.persisted, isNull);
    });

    test('refuses an outlet offering no fulfilment method', () async {
      final result = await SelectOutlet(repo)(
        SelectOutletParams(outlet: outlet(methods: const {})),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.persisted, isNull);
    });
  });

  group('CheckPincodeServiceability', () {
    late _FakeLocationRepo repo;
    setUp(() => repo = _FakeLocationRepo());

    test('an unserviceable pincode is a successful answer, not a failure',
        () async {
      repo.serviceability = Serviceability(
        pincode: Pincode.tryParse('400001')!,
        isServiceable: false,
      );

      final result = await CheckPincodeServiceability(repo)(
        const CheckPincodeServiceabilityParams(pincode: '400001'),
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.isServiceable, isFalse);
    });

    test('rejects a malformed pincode', () async {
      final result = await CheckPincodeServiceability(repo)(
        const CheckPincodeServiceabilityParams(pincode: 'abc'),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('SelectPincode', () {
    late _FakeLocationRepo repo;
    setUp(() => repo = _FakeLocationRepo());

    test('persists a serviceable pincode', () async {
      final result = await SelectPincode(repo)(
        const SelectPincodeParams(pincode: '400001'),
      );

      expect(result.isOk, isTrue);
      expect(repo.persisted?.value, '400001');
    });

    test('refuses to persist an unserviceable pincode', () async {
      // The check lives in the use case, so no caller can skip it.
      repo.serviceability = Serviceability(
        pincode: Pincode.tryParse('400001')!,
        isServiceable: false,
        message: 'Not in our delivery area yet',
      );

      final result = await SelectPincode(repo)(
        const SelectPincodeParams(pincode: '400001'),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull!.userMessage, 'Not in our delivery area yet');
      expect(repo.persisted, isNull);
    });

    test('propagates a check failure without persisting', () async {
      repo.checkFailure = const NetworkFailure('offline');

      final result = await SelectPincode(repo)(
        const SelectPincodeParams(pincode: '400001'),
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(repo.persisted, isNull);
    });

    test('rejects a malformed pincode before any call', () async {
      final result =
          await SelectPincode(repo)(const SelectPincodeParams(pincode: '1'));

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.persisted, isNull);
    });
  });

  group('NoParams', () {
    test('is a value type so family providers cache correctly', () {
      expect(const NoParams(), const NoParams());
    });
  });
}
