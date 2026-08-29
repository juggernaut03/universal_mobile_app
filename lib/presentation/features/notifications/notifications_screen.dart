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

/// Icon + color per notification type, so the rail reads at a glance before
/// the text is even parsed — matches the badge-per-type convention already
/// used on order status chips elsewhere in the app.
class _TypeStyle {
  final IconData icon;
  final Color color;
  const _TypeStyle(this.icon, this.color);

  factory _TypeStyle.forType(String type) => switch (type) {
        'order' => _TypeStyle(Icons.local_shipping_outlined, AppColors.info),
        'promotion' => _TypeStyle(Icons.local_offer_outlined, AppColors.warning),
        // 'system' is every admin-sent push (controllers/notifications.js's
        // sendNotificationToUser hardcodes type: 'system' regardless of what
        // the admin is actually announcing — an offer, a general update,
        // whatever they typed into Send Push Notifications) — so a gear icon
        // read as "system settings", not what these actually are: broadcast
        // announcements. Falls through to the announcement icon below.
        _ => _TypeStyle(Icons.campaign_outlined, AppColors.primary),
      };
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening this screen is itself the "seen" signal — clear the bell badge
    // automatically instead of requiring the user to tap "Mark all read"
    // every time. markAllNotificationsReadProvider already bumps
    // notificationsRefreshProvider on success, which both this screen's list
    // and the home-screen badge (unreadNotificationCountProvider) watch, so
    // no separate refresh/invalidate is needed here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(markAllNotificationsReadProvider)();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                await ref.read(markAllNotificationsReadProvider)();
              },
              icon: const Icon(Icons.done_all, size: 18, color: Colors.white),
              label: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => _buildList(context, ref, notifications),
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
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
      return _EmptyState(
        onRefresh: () => ref.read(notificationsRefreshProvider.notifier).state++,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(notificationsRefreshProvider.notifier).state++;
        await ref.read(notificationsListProvider.future);
      },
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: notifications.length,
        itemBuilder: (context, index) => _NotificationCard(notification: notifications[index]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: AppColors.primary.withOpacity(0.6),
                    ),
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
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: Icon(Icons.refresh, size: 18, color: AppColors.primary),
                    label: Text(
                      'Refresh',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = !notification.isRead;
    final typeStyle = _TypeStyle.forType(notification.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread ? AppColors.primary.withOpacity(0.25) : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: isUnread ? AppColors.primary.withOpacity(0.04) : Colors.white,
        child: InkWell(
          onTap: () async {
            if (isUnread) {
              await ref.read(markNotificationReadProvider)(notification.id);
            }

            // Matches the deep-link convention firebase_notification_service.dart
            // already uses for a tapped push: data.url is an in-app route.
            final url = notification.data['url']?.toString();
            if (url != null && url.startsWith('/') && context.mounted) {
              context.push(url);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: typeStyle.color.withOpacity(0.12),
                  ),
                  child: Icon(typeStyle.icon, color: typeStyle.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8, top: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
