// lib/di/service_providers.dart
//
// Composition root — services.
//
// Two defects were fixed while consolidating these declarations:
//
//   1. Five providers constructed `ApiClient(logger: ...)` inline. That client
//      has no CentralizedAuthManager, so `_getToken()` returns null and every
//      `*WithAuth` call goes out with no Authorization header and ignores 401s
//      — the same defect Phase 1 fixed for `apiClientProvider`. They now all
//      resolve the one configured client.
//
//   2. Four services constructed `http.Client()` inline, so each held its own
//      connection pool. They now share [httpClientProvider].

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/advanced_notification_service.dart';
import '../data/services/api_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/firebase_notification_service.dart';
import '../data/services/order_payment_processing_service.dart';
import '../data/services/banner_service.dart';
import '../data/services/cart_session_manager.dart';
import '../data/services/cart_storage_service.dart';
import '../data/services/content_service.dart';
import '../data/services/delivery_charges_service.dart';
import '../data/services/delivery_slot_service.dart';
import '../data/services/fcm_token_service.dart';
import '../data/services/force_update_service.dart';
import '../data/services/google_maps_service.dart';
import '../data/services/location_service.dart';
import '../data/services/order_service.dart';
import '../data/services/outlet_status_service.dart';
import '../data/services/payment_method_service.dart';
import '../data/services/payment_service.dart';
import '../data/services/popup_service.dart';
import '../data/services/storage_service.dart';
import '../core/constants/app_constants.dart';
import '../presentation/providers/cart_validator_provider.dart'
    show cartValidatorProvider;
import '../presentation/providers/splash_provider.dart'
    show googleMapsInitializedProvider;
import 'infrastructure_providers.dart';

// ---- storage & session ----

/// Owns cart session lifecycle: order-processing state, temp order ids, the
/// cart key and device id.
///
/// Was declared identically in three files — cart_provider,
/// cart_validator_provider and enhanced_cart_validator_provider — producing
/// three independent instances.
final cartSessionManagerProvider = Provider<CartSessionManager>((ref) {
  return CartSessionManager(logger: ref.watch(loggerProvider));
});

final cartStorageServiceProvider = Provider<CartStorageService>((ref) {
  return CartStorageService(
    prefs: ref.watch(sharedPreferencesProvider),
    logger: ref.watch(loggerProvider),
  );
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(
    prefs: ref.watch(sharedPreferencesProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ---- network-facing ----

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    apiClient: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

final bannerServiceProvider = Provider<BannerService>((ref) {
  return BannerService(
    apiClient: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
    cacheManager: ref.watch(cacheManagerProvider),
  );
});

final deliveryChargesServiceProvider = Provider<DeliveryChargesService>((ref) {
  return DeliveryChargesService(
    client: ref.watch(httpClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

final deliverySlotServiceProvider = Provider<DeliverySlotService>((ref) {
  return DeliverySlotService(
    client: ref.watch(httpClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

final outletStatusServiceProvider = Provider<OutletStatusService>((ref) {
  return OutletStatusService(
    client: ref.watch(httpClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

final paymentMethodServiceProvider = Provider<PaymentMethodService>((ref) {
  return PaymentMethodService(
    client: ref.watch(httpClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(
    logger: ref.watch(loggerProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(
    logger: ref.watch(loggerProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

final popupServiceProvider = Provider<PopupService>((ref) {
  return PopupService(logger: ref.watch(loggerProvider));
});

final forceUpdateServiceProvider =
    Provider<ForceUpdateService>((ref) => ForceUpdateService());

final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  return FcmTokenService(
    authManager: ref.watch(centralizedAuthManagerProvider),
    apiClient: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ---- location ----

final googleMapsServiceProvider = Provider<GoogleMapsService>((ref) {
  return GoogleMapsService(
    apiKey: ApiConstants.googleApiKey,
    logger: ref.watch(loggerProvider),
  );
});

/// Falls back to a Maps-free implementation until Google Maps has initialised.
final locationServiceProvider = Provider<LocationService>((ref) {
  final logger = ref.watch(loggerProvider);

  if (ref.watch(googleMapsInitializedProvider)) {
    return LocationService(
      googleMapsService: ref.watch(googleMapsServiceProvider),
      logger: logger,
    );
  }
  return LocationService(logger: logger);
});

// ---- auth ----

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
    logger: ref.watch(loggerProvider),
    httpClient: ref.watch(httpClientProvider),
    firebaseMessaging: ref.watch(firebaseMessagingProvider),
  );
});

// ---- notifications ----
//
// TODO(phase-8): four notification services survive. Phase 8 collapses them
// behind a single INotificationService with platform strategies.

final firebaseNotificationServiceProvider =
    Provider<FirebaseNotificationService>((ref) => FirebaseNotificationService());

final advancedNotificationServiceProvider =
    Provider<AdvancedNotificationService>(
        (ref) => AdvancedNotificationService(ref: ref));

// ---- orders ----

final orderPaymentProcessingServiceProvider =
    Provider<OrderPaymentProcessingService>((ref) {
  return OrderPaymentProcessingService(
    logger: ref.watch(loggerProvider),
    cartValidator: ref.watch(cartValidatorProvider),
  );
});

/// Static content pages. Was constructed inline as `ContentService()` in four
/// separate screen-level providers.
final contentServiceProvider = Provider<ContentService>((ref) => ContentService());
