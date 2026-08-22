// lib/data/repositories/notifications_repository.dart

import '../../core/constants/app_constants.dart';
import '../models/notification_model.dart';
import 'base_repository.dart';

/// In-app notification history against the universal backend
/// (/api/notifications/*). Distinct from push delivery (see
/// firebase_notification_service.dart) — this is the persisted record a
/// notification leaves behind regardless of whether the push itself reached
/// the device.
class NotificationsRepository extends BaseRepository {
  NotificationsRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });

  /// Fetch a page of the current user's notifications, newest first.
  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    return await makeAuthenticatedRequest<List<AppNotification>>(
      () async {
        logActivity('Fetching notifications page $page');

        final response = await getWithAuth(
          ApiConstants.notifications,
          additionalParams: {'page': '$page', 'limit': '$limit'},
        );

        if (response is! Map<String, dynamic> || response['data'] is! List) {
          logActivity('Unexpected notifications response format');
          return <AppNotification>[];
        }

        return (response['data'] as List)
            .whereType<Map>()
            .map((json) => AppNotification.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      },
      onAuthError: () => <AppNotification>[],
    ) ?? <AppNotification>[];
  }

  /// Unread count only — cheap enough to poll for the app bar badge.
  Future<int> getUnreadCount() async {
    return await makeAuthenticatedRequest<int>(
      () async {
        final response = await getWithAuth(ApiConstants.notificationsUnreadCount);

        if (response is Map<String, dynamic> && response['count'] is int) {
          return response['count'] as int;
        }
        return 0;
      },
      onAuthError: () => 0,
    ) ?? 0;
  }

  /// Marks one notification read. True on success.
  Future<bool> markAsRead(String id) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        final response = await putWithAuth(ApiConstants.notificationRead(id));
        return response is Map<String, dynamic> && response['success'] == true;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Marks every notification read. True on success.
  Future<bool> markAllAsRead() async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        final response = await putWithAuth(ApiConstants.notificationsReadAll);
        return response is Map<String, dynamic> && response['success'] == true;
      },
      onAuthError: () => false,
    ) ?? false;
  }
}
