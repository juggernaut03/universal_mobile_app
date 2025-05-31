import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // For navigatorKey

// Provider for the notification service
final firebaseNotificationServiceProvider = Provider<FirebaseNotificationService>((ref) {
  throw UnimplementedError('FirebaseNotificationService must be overridden in main.dart');
});

class FirebaseNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications',
    importance: Importance.high,
    playSound: true,
  );
  
  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      debugPrint('FirebaseNotificationService: Starting initialization...');
      
      // Request permissions
      await _requestPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Setup message handlers
      await _setupMessageHandlers();
      
      // Get and save FCM token
      await _setupFCMToken();
      
      // Subscribe to default topic
      await _subscribeToTopics();
      
      debugPrint('FirebaseNotificationService: ✅ Initialization completed');
      
    } catch (e, stackTrace) {
      debugPrint('FirebaseNotificationService: ❌ Initialization failed: $e');
      debugPrint('FirebaseNotificationService: Stack trace: $stackTrace');
    }
  }
  
  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    debugPrint('FirebaseNotificationService: Permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FirebaseNotificationService: ❌ Notifications denied by user');
      throw Exception('Notification permissions denied');
    }
    
    // For Android 13+, request additional permission
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('FirebaseNotificationService: Android notification permission: $granted');
      }
    }
  }
  
  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested above
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );
    
    debugPrint('FirebaseNotificationService: Local notifications initialized: $initialized');
    
    // Create notification channel for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_androidChannel);
        debugPrint('FirebaseNotificationService: Android notification channel created');
      }
    }
  }
  
  /// Setup FCM message handlers
  Future<void> _setupMessageHandlers() async {
    // Configure foreground notification presentation
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FirebaseNotificationService: 📱 Foreground message received');
      debugPrint('FirebaseNotificationService: Message ID: ${message.messageId}');
      debugPrint('FirebaseNotificationService: Title: ${message.notification?.title}');
      debugPrint('FirebaseNotificationService: Body: ${message.notification?.body}');
      debugPrint('FirebaseNotificationService: Data: ${message.data}');
      
      // Show local notification for foreground messages
      _showLocalNotification(message);
    });
    
    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FirebaseNotificationService: 🚀 Message opened app from background');
      _handleMessageNavigation(message);
    });
    
    // Check for initial message (app opened from terminated state)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FirebaseNotificationService: 🚀 Initial message found');
      // Delay navigation to allow app to fully initialize
      Future.delayed(const Duration(seconds: 1), () {
        _handleMessageNavigation(initialMessage);
      });
    }
  }
  
  /// Setup FCM token
  Future<void> _setupFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      debugPrint('FirebaseNotificationService: FCM Token: $token');
      
      if (token != null) {
        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        debugPrint('FirebaseNotificationService: ✅ Token saved to SharedPreferences');
        
        // TODO: Send token to your backend server
        // await _sendTokenToServer(token);
      } else {
        debugPrint('FirebaseNotificationService: ❌ Failed to get FCM token');
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('FirebaseNotificationService: Token refreshed: $newToken');
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('fcm_token', newToken);
        });
        // TODO: Send new token to your backend server
        // _sendTokenToServer(newToken);
      });
      
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error setting up FCM token: $e');
    }
  }
  
  /// Subscribe to topics
  Future<void> _subscribeToTopics() async {
    try {
      await _firebaseMessaging.subscribeToTopic('default');
      debugPrint('FirebaseNotificationService: ✅ Subscribed to "default" topic');
      
      // Add more topic subscriptions as needed
      // await _firebaseMessaging.subscribeToTopic('offers');
      // await _firebaseMessaging.subscribeToTopic('orders');
      
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error subscribing to topics: $e');
    }
  }
  
  /// Show local notification for foreground messages
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      debugPrint('FirebaseNotificationService: ⚠️ No notification payload, skipping local notification');
      return;
    }
    
    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      playSound: true,
      enableVibration: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    var details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.toMap()),
    );
    
    debugPrint('FirebaseNotificationService: ✅ Local notification displayed');
  }
  
  /// Handle message navigation
  void _handleMessageNavigation(RemoteMessage message) {
    debugPrint('FirebaseNotificationService: Handling message navigation');
    debugPrint('FirebaseNotificationService: Message data: ${message.data}');
    
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('FirebaseNotificationService: ❌ No valid context for navigation');
      return;
    }
    
    // Extract navigation URL from message data
    final url = message.data['url'] ?? message.data['route'] ?? message.data['navigate_to'];
    
    if (url != null && url.isNotEmpty) {
      debugPrint('FirebaseNotificationService: Navigating to: $url');
      try {
        context.go(url);
      } catch (e) {
        debugPrint('FirebaseNotificationService: ❌ Navigation error: $e');
        // Fallback to home if navigation fails
        context.go('/home');
      }
    } else {
      debugPrint('FirebaseNotificationService: No navigation URL found, going to home');
      context.go('/home');
    }
  }
  
  /// Handle notification tap (foreground)
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('FirebaseNotificationService: Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final messageMap = jsonDecode(response.payload!);
        final message = RemoteMessage.fromMap(messageMap);
        _handleMessageNavigation(message);
      } catch (e) {
        debugPrint('FirebaseNotificationService: ❌ Error parsing notification payload: $e');
      }
    }
  }
  
  /// Handle notification tap (background) - must be static
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('FirebaseNotificationService: Background notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final messageMap = jsonDecode(response.payload!);
        final message = RemoteMessage.fromMap(messageMap);
        
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final url = message.data['url'] ?? message.data['route'] ?? message.data['navigate_to'];
          if (url != null && url.isNotEmpty) {
            context.go(url);
          } else {
            context.go('/home');
          }
        }
      } catch (e) {
        debugPrint('FirebaseNotificationService: ❌ Error in background notification tap: $e');
      }
    }
  }
  
  /// Handle background messages (static method)
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('FirebaseNotificationService: Processing background message: ${message.messageId}');
    
    // Store the message for when app becomes active
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessages = prefs.getStringList('pending_notification_messages') ?? [];
      pendingMessages.add(jsonEncode(message.toMap()));
      
      // Keep only the last 5 messages to avoid storage bloat
      if (pendingMessages.length > 5) {
        pendingMessages.removeRange(0, pendingMessages.length - 5);
      }
      
      await prefs.setStringList('pending_notification_messages', pendingMessages);
      debugPrint('FirebaseNotificationService: ✅ Background message stored for later processing');
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error storing background message: $e');
    }
  }
  
  /// Process any pending messages (call this when app becomes active)
  Future<void> processPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessages = prefs.getStringList('pending_notification_messages') ?? [];
      
      for (final messageJson in pendingMessages) {
        try {
          final messageMap = jsonDecode(messageJson);
          final message = RemoteMessage.fromMap(messageMap);
          debugPrint('FirebaseNotificationService: Processing pending message: ${message.messageId}');
          
          // Process the message (you can customize this based on your needs)
          // For example, update local cache, refresh data, etc.
        } catch (e) {
          debugPrint('FirebaseNotificationService: ❌ Error processing pending message: $e');
        }
      }
      
      // Clear processed messages
      await prefs.remove('pending_notification_messages');
      debugPrint('FirebaseNotificationService: ✅ Processed ${pendingMessages.length} pending messages');
      
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error processing pending messages: $e');
    }
  }
  
  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error getting current token: $e');
      return null;
    }
  }
  
  /// Send token to server (implement this based on your backend)
  Future<void> _sendTokenToServer(String token) async {
    try {
      // TODO: Implement your API call to send token to backend
      // Example:
      // final response = await http.post(
      //   Uri.parse('${ApiConstants.baseUrl}/user/fcm-token'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'token': token}),
      // );
      
      debugPrint('FirebaseNotificationService: ✅ Token sent to server');
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error sending token to server: $e');
    }
  }
  
  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('FirebaseNotificationService: ✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error subscribing to topic $topic: $e');
    }
  }
  
  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('FirebaseNotificationService: ✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('FirebaseNotificationService: ❌ Error unsubscribing from topic $topic: $e');
    }
  }
}
