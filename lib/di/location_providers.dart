// lib/di/location_providers.dart
//
// Composition root — the location/pincode/outlet slice (Phase 3b).
//
// Both repositories are exposed only through their domain interfaces, so a
// screen cannot reach OutletRepositoryImpl or the services underneath it.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/location_repository_impl.dart';
import '../data/repositories/outlet_repository_impl.dart';
import '../domain/repositories/i_location_repository.dart';
import '../domain/repositories/i_outlet_repository.dart';
import '../domain/usecases/launch/resolve_delivery_location.dart';
import '../domain/usecases/location/check_pincode_serviceability.dart';
import '../domain/usecases/location/detect_pincode_from_location.dart';
import '../domain/usecases/location/get_serviceable_pincodes.dart';
import '../domain/usecases/location/select_pincode.dart';
import '../domain/usecases/outlet/get_outlets_for_pincode.dart';
import '../domain/usecases/outlet/get_selected_outlet.dart';
import '../domain/usecases/outlet/refresh_outlet_status.dart';
import '../domain/usecases/outlet/select_outlet.dart';
import 'infrastructure_providers.dart';
import 'service_providers.dart';

// ---- repositories (domain-typed) ----

final outletRepositoryDomainProvider = Provider<IOutletRepository>((ref) {
  return OutletRepositoryImpl(
    apiService: ref.watch(apiServiceProvider),
    storageService: ref.watch(storageServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});

final locationRepositoryDomainProvider = Provider<ILocationRepository>((ref) {
  return LocationRepositoryImpl(
    locationService: ref.watch(locationServiceProvider),
    apiService: ref.watch(apiServiceProvider),
    storageService: ref.watch(storageServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ---- outlet use cases ----

final getOutletsForPincodeUseCaseProvider = Provider<GetOutletsForPincode>(
  (ref) => GetOutletsForPincode(ref.watch(outletRepositoryDomainProvider)),
);

final selectOutletUseCaseProvider = Provider<SelectOutlet>(
  (ref) => SelectOutlet(ref.watch(outletRepositoryDomainProvider)),
);

final getSelectedOutletUseCaseProvider = Provider<GetSelectedOutlet>(
  (ref) => GetSelectedOutlet(ref.watch(outletRepositoryDomainProvider)),
);

final refreshOutletStatusUseCaseProvider = Provider<RefreshOutletStatus>(
  (ref) => RefreshOutletStatus(ref.watch(outletRepositoryDomainProvider)),
);

// ---- location use cases ----

final checkPincodeServiceabilityUseCaseProvider =
    Provider<CheckPincodeServiceability>(
  (ref) =>
      CheckPincodeServiceability(ref.watch(locationRepositoryDomainProvider)),
);

final detectPincodeFromLocationUseCaseProvider =
    Provider<DetectPincodeFromLocation>(
  (ref) =>
      DetectPincodeFromLocation(ref.watch(locationRepositoryDomainProvider)),
);

final selectPincodeUseCaseProvider = Provider<SelectPincode>(
  (ref) => SelectPincode(ref.watch(locationRepositoryDomainProvider)),
);

final getServiceablePincodesUseCaseProvider = Provider<GetServiceablePincodes>(
  (ref) => GetServiceablePincodes(ref.watch(locationRepositoryDomainProvider)),
);

// ---- launch flow ----

/// The delivery-area detection workflow, extracted from
/// LaunchFlowNotifier.fetchLocationAndCheckPincode.
final resolveDeliveryLocationUseCaseProvider = Provider<ResolveDeliveryLocation>(
  (ref) => ResolveDeliveryLocation(
    locationRepository: ref.watch(locationRepositoryDomainProvider),
    outletRepository: ref.watch(outletRepositoryDomainProvider),
  ),
);
