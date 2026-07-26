// lib/data/repositories/location_repository_impl.dart
//
// Implements ILocationRepository by adapting LocationService, ApiService and
// StorageService.
//
// The main gain over the previous LocationRepository is that permission-denied,
// location-services-off and reverse-geocoding-failed stop collapsing into a
// single `null`. They were indistinguishable, so the UI could only ever show
// one generic message regardless of which setting the user needed to change.

import 'package:geolocator/geolocator.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/outlet.dart' show GeoPoint;
import '../../domain/entities/pincode.dart';
import '../../domain/repositories/i_location_repository.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

final class LocationRepositoryImpl implements ILocationRepository {
  final LocationService _locationService;
  final ApiService _apiService;
  final StorageService _storageService;
  final Logger _logger;

  LocationRepositoryImpl({
    required LocationService locationService,
    required ApiService apiService,
    required StorageService storageService,
    required Logger logger,
  })  : _locationService = locationService,
        _apiService = apiService,
        _storageService = storageService,
        _logger = logger;

  @override
  Future<Result<GeoPoint>> currentPosition() {
    return guard(() async {
      // Classify *why* the position is unavailable before asking for it, so the
      // failure names the setting the user has to change.
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ValidationException(
          'Location services are turned off. Please enable them to detect your area.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const ValidationException(
          'Location permission is needed to detect your delivery area.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const ValidationException(
          'Location permission is permanently denied. Please enable it in Settings.',
        );
      }

      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw const NetworkException('Could not obtain a location fix');
      }
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }

  @override
  Future<Result<Pincode>> pincodeFromCurrentLocation() {
    return guard(() async {
      final raw = await _locationService.getPincodeFromCurrentLocation();
      final pincode = Pincode.tryParse(raw);
      if (pincode == null) {
        throw NotFoundException(
          'Could not determine a pincode from your location (got "$raw")',
        );
      }
      return pincode;
    });
  }

  @override
  Future<Result<Serviceability>> checkServiceability(Pincode pincode) {
    return guard(() async {
      final response = await _apiService.checkIfPincodeExists(pincode.value);
      return response.toEntity(pincode);
    });
  }

  @override
  Future<Result<List<Pincode>>> serviceablePincodes() {
    return guard(() async {
      final models = await _apiService.getPincodeList();
      // Drop anything the backend sends that is not a valid pincode rather than
      // surfacing it into a picker the user can select and then fail on.
      return models
          .map((m) => m.toEntity())
          .whereType<Pincode>()
          .toList(growable: false);
    });
  }

  @override
  Future<Result<void>> selectPincode(Pincode pincode) {
    return guard(() async {
      final saved = await _storageService.saveSelectedPincode(pincode.value);
      if (!saved) {
        throw CacheException('Could not persist pincode ${pincode.value}');
      }
      _logger.log('Selected pincode ${pincode.value}');
    });
  }

  @override
  Future<Result<void>> clearSelectedPincode() => guard(() async {
        final cleared = await _storageService.clearSelectedPincode();
        if (!cleared) {
          throw const CacheException('Could not clear the selected pincode');
        }
        _logger.log('Cleared pincode selection');
      });

  @override
  Future<Result<Pincode>> selectedPincode() {
    return guard(() async {
      final pincode = Pincode.tryParse(_storageService.getSelectedPincode());
      if (pincode == null) {
        throw const NotFoundException('No pincode selected');
      }
      return pincode;
    });
  }

  @override
  Future<Result<double>> distanceBetween(GeoPoint from, GeoPoint to) {
    return guard(() async {
      final metres = Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      return metres / 1000;
    });
  }
}
