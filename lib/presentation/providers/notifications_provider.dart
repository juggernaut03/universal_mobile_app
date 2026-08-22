// lib/presentation/providers/notifications_provider.dart
//
// The user's in-app notification history and unread count.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../../di/repository_providers.dart';

/// Bumped to force a refetch of both providers below — mirrors
/// addressRefreshProvider in address_provider.dart.
final notificationsRefreshProvider = StateProvider<int>((ref) => 0);

/// Unread count, for the app bar badge. Cheap enough to watch from anywhere.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  ref.watch(notificationsRefreshProvider);
  return ref.read(notificationsRepositoryProvider).getUnreadCount();
});

/// The first page of notifications, newest first.
final notificationsListProvider = FutureProvider<List<AppNotification>>((ref) async {
  ref.watch(notificationsRefreshProvider);
  return ref.read(notificationsRepositoryProvider).getNotifications();
});

/// Marks one notification read, updating both the list and the badge.
final markNotificationReadProvider = Provider<Future<void> Function(String)>((ref) {
  return (String id) async {
    final ok = await ref.read(notificationsRepositoryProvider).markAsRead(id);
    if (ok) {
      ref.read(notificationsRefreshProvider.notifier).state++;
    }
  };
});

/// Marks every notification read.
final markAllNotificationsReadProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final ok = await ref.read(notificationsRepositoryProvider).markAllAsRead();
    if (ok) {
      ref.read(notificationsRefreshProvider.notifier).state++;
    }
  };
});
