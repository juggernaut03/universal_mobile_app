// test/presentation/launch_flow_test.dart
//
// The first-run journey: onboarding -> pincode -> store -> home, and the
// returning-user path that is supposed to skip straight to home.
//
// LaunchFlowNotifier decides which screen a user lands on, and had no tests. It
// reads two providers that load asynchronously, so what it sees depends on
// timing — which is exactly the kind of thing that cannot be reasoned about by
// reading it, and exactly what a returning user experiences as "why is it
// asking me for my pincode again?".

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/di/infrastructure_providers.dart';
import 'package:patelmart/di/location_providers.dart';
import 'package:patelmart/domain/entities/delivery_location.dart';
import 'package:patelmart/domain/entities/outlet.dart';
import 'package:patelmart/domain/entities/pincode.dart';
import 'package:patelmart/domain/repositories/i_location_repository.dart';
import 'package:patelmart/domain/repositories/i_outlet_repository.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Outlet _outlet([String storeCode = 'KLK']) => Outlet(
      id: 'id',
      storeCode: storeCode,
      name: 'Kalyan Store',
      address: '',
      minOrderAmount: 0,
    );

final class _FakeLocationRepo implements ILocationRepository {
  /// What a returning user has saved. Err = nothing chosen yet.
  Result<Pincode> saved = const Err(NotFoundFailure('none'));

  /// Delay before [selectedPincode] answers, to model real storage latency.
  Duration readDelay = Duration.zero;

  Result<Pincode> detected = Ok(Pincode.tryParse('400001')!);
  Result<Serviceability>? serviceability;
  bool selectSucceeds = true;

  @override
  Future<Result<GeoPoint>> currentPosition() async =>
      const Ok(GeoPoint(latitude: 19.0, longitude: 72.0));

  @override
  Future<Result<Pincode>> pincodeFromCurrentLocation() async => detected;

  @override
  Future<Result<Serviceability>> checkServiceability(Pincode pincode) async =>
      serviceability ?? Ok(Serviceability(pincode: pincode, isServiceable: true));

  @override
  Future<Result<List<Pincode>>> serviceablePincodes() async => const Ok([]);

  @override
  Future<Result<void>> selectPincode(Pincode pincode) async {
    if (!selectSucceeds) return const Err(CacheFailure('disk full'));
    saved = Ok(pincode);
    return const Ok(null);
  }

  @override
  Future<Result<void>> clearSelectedPincode() async {
    saved = const Err(NotFoundFailure('none'));
    return const Ok(null);
  }

  @override
  Future<Result<Pincode>> selectedPincode() async {
    if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
    return saved;
  }

  @override
  Future<Result<double>> distanceBetween(GeoPoint from, GeoPoint to) async =>
      const Ok(0);
}

final class _FakeOutletRepo implements IOutletRepository {
  Result<Outlet> saved = const Err(NotFoundFailure('none'));
  Duration readDelay = Duration.zero;

  @override
  Future<Result<List<Outlet>>> outletsForPincode(Pincode pincode) async =>
      Ok([_outlet()]);

  @override
  Future<Result<void>> selectOutlet(Outlet outlet) async {
    saved = Ok(outlet);
    return const Ok(null);
  }

  @override
  Future<Result<Outlet>> selectedOutlet() async {
    if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
    return saved;
  }

  @override
  Future<Result<void>> clearSelection() async {
    saved = const Err(NotFoundFailure('none'));
    return const Ok(null);
  }

  @override
  Future<Result<Outlet>> refreshStatus(String storeCode) async => saved;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeLocationRepo location;
  late _FakeOutletRepo outlets;

  setUp(() {
    location = _FakeLocationRepo();
    outlets = _FakeOutletRepo();
  });

  /// A container wired to the fakes, with [prefs] as the stored launch history.
  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      locationRepositoryDomainProvider.overrideWithValue(location),
      outletRepositoryDomainProvider.overrideWithValue(outlets),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  /// Builds the notifier and lets its constructor-launched async work settle.
  Future<AppLaunchState> launch(ProviderContainer c) async {
    c.read(launchFlowProvider);
    await Future<void>.delayed(Duration.zero);
    return c.read(launchFlowProvider);
  }

  group('first run', () {
    test('a brand-new install starts at onboarding', () async {
      final c = await containerWith({});
      expect(await launch(c), AppLaunchState.firstLaunch);
    });

    test('an install that saw onboarding but never finished it repeats it',
        () async {
      // has_launched_before is written the moment onboarding is *shown*, so it
      // cannot be the whole test — a user who killed the app mid-onboarding
      // must see it again rather than land somewhere undefined.
      final c = await containerWith({
        'has_launched_before': true,
        'hasCompletedOnboarding': false,
      });
      expect(await launch(c), AppLaunchState.firstLaunch);
    });

    test('the full first-run journey reaches home', () async {
      final c = await containerWith({});
      expect(await launch(c), AppLaunchState.firstLaunch);

      final flow = c.read(launchFlowProvider.notifier);

      flow.onboardingCompleted();
      expect(c.read(launchFlowProvider), AppLaunchState.needLocationPermission);

      flow.pincodeSelected();
      expect(c.read(launchFlowProvider), AppLaunchState.needOutletSelection);

      flow.outletSelected();
      expect(c.read(launchFlowProvider), AppLaunchState.readyToLaunch);
    });
  });

  group('location resolution', () {
    test('a serviceable area moves on to store selection', () async {
      final c = await containerWith({});
      final flow = c.read(launchFlowProvider.notifier);

      await flow.fetchLocationAndCheckPincode();

      expect(c.read(launchFlowProvider), AppLaunchState.needOutletSelection);
      expect(c.read(selectedPincodeProvider), '400001');
    });

    test('an unserviceable area asks the user to pick a pincode', () async {
      location.serviceability = Ok(Serviceability(
        pincode: Pincode.tryParse('400001')!,
        isServiceable: false,
      ));
      final c = await containerWith({});

      await c.read(launchFlowProvider.notifier).fetchLocationAndCheckPincode();

      expect(c.read(launchFlowProvider), AppLaunchState.needPincodeSelection);
      expect(c.read(locationInfoProvider).nonServiceablePincode, '400001');
    });

    test('a failed detection asks the user rather than dead-ending', () async {
      location.detected = const Err(NotFoundFailure('no fix'));
      final c = await containerWith({});

      await c.read(launchFlowProvider.notifier).fetchLocationAndCheckPincode();

      expect(c.read(launchFlowProvider), AppLaunchState.needPincodeSelection);
    });

    test('a pincode that cannot be persisted does not advance', () async {
      // Advancing to store selection on a pincode that was never saved leaves
      // the next launch with an outlet and no area.
      location.selectSucceeds = false;
      final c = await containerWith({});

      await c.read(launchFlowProvider.notifier).fetchLocationAndCheckPincode();

      expect(c.read(launchFlowProvider), AppLaunchState.needPincodeSelection);
    });
  });

  group('returning user', () {
    test('with pincode and store already loaded, goes straight to home',
        () async {
      location.saved = Ok(Pincode.tryParse('421301')!);
      outlets.saved = Ok(_outlet());

      final c = await containerWith({
        'has_launched_before': true,
        'hasCompletedOnboarding': true,
      });

      // Warm the two providers first, the way a splash screen that reads them
      // would, so the launch check sees settled values.
      c.read(selectedPincodeProvider);
      c.read(selectedOutletProvider);
      await Future<void>.delayed(Duration.zero);

      expect(await launch(c), AppLaunchState.readyToLaunch);
    });

    test('with a pincode but no store, resumes at store selection', () async {
      location.saved = Ok(Pincode.tryParse('421301')!);

      final c = await containerWith({
        'has_launched_before': true,
        'hasCompletedOnboarding': true,
      });
      c.read(selectedPincodeProvider);
      c.read(selectedOutletProvider);
      await Future<void>.delayed(Duration.zero);

      expect(await launch(c), AppLaunchState.needOutletSelection);
    });

    test('slow storage still lands on home, not the pincode picker', () async {
      // The bug this pins: _checkCachedData() read the two providers
      // synchronously, and that read is what *creates* them — so their loads
      // had not finished and it saw null / AsyncValue.loading(). A returning
      // user with both saved was sent back to pincode selection.
      //
      // Any real read latency reproduces it; the delay here just makes the
      // window deterministic instead of leaving it to scheduler luck.
      location.saved = Ok(Pincode.tryParse('421301')!);
      outlets.saved = Ok(_outlet());
      location.readDelay = const Duration(milliseconds: 20);
      outlets.readDelay = const Duration(milliseconds: 20);

      final c = await containerWith({
        'has_launched_before': true,
        'hasCompletedOnboarding': true,
      });

      c.read(launchFlowProvider);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(c.read(launchFlowProvider), AppLaunchState.readyToLaunch);
      expect(c.read(selectedPincodeProvider), '421301');
      expect(c.read(selectedOutletProvider).value?.storeCode, 'KLK');
    });

    test('never reports subsequentLaunch before storage has answered', () async {
      // subsequentLaunch routes to /home. Publishing it while the area is
      // still loading is what produced the home -> pincode-selection bounce;
      // the state must stay `initializing` so the splash holds instead.
      location.saved = Ok(Pincode.tryParse('421301')!);
      outlets.saved = Ok(_outlet());
      location.readDelay = const Duration(milliseconds: 30);
      outlets.readDelay = const Duration(milliseconds: 30);

      final c = await containerWith({
        'has_launched_before': true,
        'hasCompletedOnboarding': true,
      });

      final seen = <AppLaunchState>[];
      c.listen(launchFlowProvider, (_, next) => seen.add(next), fireImmediately: true);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(seen.first, AppLaunchState.initializing);
      expect(seen.last, AppLaunchState.readyToLaunch);
      expect(seen, isNot(contains(AppLaunchState.needPincodeSelection)),
          reason: 'no intermediate bounce to the pincode picker');
    });

    test('a returning user with nothing saved still gets the pincode picker',
        () async {
      // The wait must not turn "no area chosen" into "go home".
      final c = await containerWith({
        'has_launched_before': true,
        'hasCompletedOnboarding': true,
      });

      expect(await launch(c), AppLaunchState.needPincodeSelection);
    });
  });

  group('reset', () {
    test('resetToFirstLaunch sends the next launch back to onboarding',
        () async {
      final c = await containerWith({
        'has_launched_before': true,
        'hasCompletedOnboarding': true,
      });
      await launch(c);

      await c.read(launchFlowProvider.notifier).resetToFirstLaunch();

      expect(c.read(launchFlowProvider), AppLaunchState.firstLaunch);
      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('has_launched_before'), isFalse);
      expect(sp.getBool('hasCompletedOnboarding'), isFalse);
    });
  });
}
