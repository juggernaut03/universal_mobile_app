// lib/domain/repositories/i_notification_service.dart

/// Push notification setup and token access.
///
/// Four services previously shared this responsibility:
/// firebase_notification_service, ios_notification_service (an identical public
/// API for the same job), simple_notification_service and
/// advanced_notification_service. Three had no live callers at all — they were
/// left behind by successive rewrites that shipped alongside what they replaced
/// instead of removing it.
///
/// Whatever replaces or supplements FirebaseNotificationService in future
/// implements this, so a platform-specific variant cannot become a parallel
/// service with its own duplicate API again.
abstract interface class INotificationService {
  /// Requests permission and registers for push, once the app is ready.
  ///
  /// Safe to call more than once; later calls are no-ops.
  Future<void> initializeWhenReady();

  /// Current FCM registration token, or null when unavailable.
  Future<String?> getCurrentToken();

  /// Whether the user has granted notification permission.
  Future<bool> areNotificationsEnabled();

  /// iOS APNS token. Null on Android, and null on iOS until APNS responds.
  Future<String?> getAPNSToken();

  /// Forces a token refresh, for recovery when registration goes stale.
  Future<String?> forceTokenRefresh();
}
