// lib/data/models/notification_model.dart
//
// An in-app notification, as stored by the universal backend
// (models/Notification.js) — one document per (user, push sent), regardless
// of whether the push itself succeeded. See docs on
// GET /api/notifications and PUT /api/notifications/:id/read.

class AppNotification {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final String type;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.type,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      isRead: json['isRead'] == true,
      type: (json['type'] ?? 'general').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        data: data,
        isRead: isRead ?? this.isRead,
        type: type,
        createdAt: createdAt,
      );
}
