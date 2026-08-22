// lib/presentation/features/notifications/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/notifications_provider.dart';

/// "3h ago" / "2d ago" — no relative-time package is a dependency of this
/// project, and one tile's worth of formatting doesn't justify adding one.
String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(markAllNotificationsReadProvider)();
            },
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => _buildList(context, ref, notifications),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorWidget(
          errorType: ErrorType.network,
          message: 'Failed to load notifications: $error',
          onRetry: () => ref.read(notificationsRefreshProvider.notifier).state++,
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> notifications,
  ) {
    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none,
                size: 96,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 24),
              Text(
                'No notifications yet',
                style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Updates about your orders and offers will show up here.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(notificationsRefreshProvider.notifier).state++;
        await ref.read(notificationsListProvider.future);
      },
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) => _NotificationTile(notification: notifications[index]),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        if (!notification.isRead) {
          await ref.read(markNotificationReadProvider)(notification.id);
        }

        // Matches the deep-link convention firebase_notification_service.dart
        // already uses for a tapped push: data.url is an in-app route.
        final url = notification.data['url']?.toString();
        if (url != null && url.startsWith('/') && context.mounted) {
          context.push(url);
        }
      },
      child: Container(
        color: notification.isRead ? Colors.white : AppColors.primary.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6, right: 12),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notification.isRead ? Colors.transparent : AppColors.primary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
