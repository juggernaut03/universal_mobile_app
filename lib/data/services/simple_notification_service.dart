// import 'dart:convert';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import '../../core/utils/logger.dart';

// // Background message handler (must be top-level function)
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   final logger = Logger();
//   logger.log('Background notification received: ${message.notification?.title}');
// }

// class SimpleNotificationService {
//   static final SimpleNotificationService _instance = SimpleNotificationService._internal();
//   factory SimpleNotificationService() => _instance;
//   SimpleNotificationService._internal();

//   final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
//   final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
//   final Logger _logger = Logger();

//   // Initialize notifications
//   Future<void> initialize() async {
//     try {
//       _logger.log('Initializing simple notifications');
      
//       // Request permission
//       await _requestPermission();
      
//       // Initialize local notifications
//       await _initializeLocalNotifications();
      
//       // Set background handler
//       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
//       // Handle foreground notifications
//       FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
//       // Handle notification taps
//       FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
//       // Handle app opened from terminated state
//       final initialMessage = await _firebaseMessaging.getInitialMessage();
//       if (initialMessage != null) {
//         _handleNotificationTap(initialMessage);
//       }
      
//       // Get FCM token
//       final token = await _firebaseMessaging.getToken();
//       _logger.log('FCM Token: $token');
      
//       _logger.log('Simple notifications initialized successfully');
//     } catch (e) {
//       _logger.error('Error initializing notifications: $e');
//     }
//   }

//   // Request notification permission
//   Future<void> _requestPermission() async {
//     final settings = await _firebaseMessaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//     _logger.log('Permission granted: ${settings.authorizationStatus}');
//   }

//   // Initialize local notifications for foreground
//   Future<void> _initializeLocalNotifications() async {
//     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosSettings = DarwinInitializationSettings();
    
//     const initSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     await _localNotifications.initialize(initSettings);
    
//     // Create notification channel for Android
//     const channel = AndroidNotificationChannel(
//       'default_channel',
//       'Default Notifications',
//       importance: Importance.high,
//     );
    
//     await _localNotifications
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);
//   }

//   // Handle foreground notifications
//   void _handleForegroundMessage(RemoteMessage message) {
//     _logger.log('Foreground notification: ${message.notification?.title}');
    
//     final notification = message.notification;
//     if (notification != null) {
//       _showLocalNotification(notification);
//     }
//   }

//   // Show local notification when app is in foreground
//   Future<void> _showLocalNotification(RemoteNotification notification) async {
//     await _localNotifications.show(
//       0,
//       notification.title,
//       notification.body,
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'default_channel',
//           'Default Notifications',
//           importance: Importance.high,
//           priority: Priority.high,
//         ),
//         iOS: DarwinNotificationDetails(),
//       ),
//     );
//   }

//   // Handle notification tap - just log for now
//   void _handleNotificationTap(RemoteMessage message) {
//     _logger.log('Notification tapped - App opened');
//     _logger.log('Title: ${message.notification?.title}');
//     _logger.log('Body: ${message.notification?.body}');
//     // App will automatically open, no additional navigation needed
//   }

//   // Get FCM token
//   Future<String?> getToken() async {
//     return await _firebaseMessaging.getToken();
//   }
// }