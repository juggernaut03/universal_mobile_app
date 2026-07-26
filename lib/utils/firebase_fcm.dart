import 'dart:convert';


import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/features/home/home_screen.dart';
import 'package:patelmart/presentation/routes/route_names.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FirebaseApi {
  final firebaseMessaging = FirebaseMessaging.instance;

  final androidChannel = const AndroidNotificationChannel(
    "high_importance_channel",
    "High Importance Notifications",
    description: "This channel is used for important notifications",
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> handleMessage(RemoteMessage? message) async {
    if (message == null) {
     if (kDebugMode) print("No message data received");
      return;
    }

   if (kDebugMode) print("Handling message with data: ${message.data}");

    // Extract URL from message data
    final String? url = message.data["url"];
    if (url == null) {
     if (kDebugMode) print("No URL in message data");
      return;
    }

    // Use the NotificationRouter to handle navigation
    await GoRoute(
        path: '/home',
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      );
  }

  static Future<void> handleBgMsg(RemoteMessage message) async {
   if (kDebugMode) print("Handling a background message: ${message.messageId}");
   if (kDebugMode) print("Message title: ${message.notification?.title}");
   if (kDebugMode) print("Message body: ${message.notification?.body}");
   if (kDebugMode) print("Message data: ${message.data}");
  }

  Future<void> initPushNotification() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.onBackgroundMessage(handleBgMsg);
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) {
        return;
      }
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            icon: '@drawable/ic_notification',
          ),
          iOS: const DarwinNotificationDetails(
            // Add iOS notification details if needed
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.toMap()),
      );
    });
  }

  Future<void> initLocalNotifications() async {
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          // Add iOS settings
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    final platform =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!;
    await platform.createNotificationChannel(androidChannel);
  }

  Future<void> initializeFirebaseNotifications() async {
    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
   if (kDebugMode) print(
      'User granted permission: ${settings.authorizationStatus}',
    );
    final fcmToken = await firebaseMessaging.getToken();
  if (kDebugMode) print("Token $fcmToken");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("fcmToken", fcmToken!);
    initPushNotification();
    initLocalNotifications();
  }
}

// Top-level functions for notification responses
void onDidReceiveNotificationResponse(NotificationResponse details) {
  if (details.payload != null) {
    try {
      FirebaseApi.handleMessage(
        RemoteMessage.fromMap(jsonDecode(details.payload!)),
      );
    } catch (e) {
print
("Error processing notification response: $e");
    }
  }
}

void onDidReceiveBackgroundNotificationResponse(NotificationResponse details) {
  if (details.payload != null) {
    try {
      FirebaseApi.handleMessage(
        RemoteMessage.fromMap(jsonDecode(details.payload!)),
      );
    } catch (e) {
      if (kDebugMode) print(
        "Error processing background notification response: $e",
      );
    }
  }
}
