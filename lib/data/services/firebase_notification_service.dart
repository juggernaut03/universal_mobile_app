import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';

// Provider that creates the service but doesn't initialize it immediately
final firebaseNotificationServiceProvider = Provider<FirebaseNotificationService>((ref) {
  return FirebaseNotificationService();
});

class FirebaseNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'default_channel',
    'Default Notifications',
    description: 'Default notification channel',
    importance: Importance.high,
    playSound: true,
  );
  
  /// Initialize ONLY when explicitly called - NOT in constructor
  Future<void> initializeWhenReady() async {
    if (_isInitialized || _isInitializing) {
      debugPrint('NotificationService: Already initialized or initializing');
      return;
    }
    
    _isInitializing = true;
    
    try {
      debugPrint('NotificationService: Starting safe initialization...');
      
      // Step 1: Initialize local notifications first (safer)
      await _initializeLocalNotificationsSafely();
      
      // Step 2: Request permissions carefully
      await _requestPermissionsSafely();
      
      // Step 3: Setup message handlers
      await _setupMessageHandlers();
      
      // Step 4: Get FCM token
      await _setupFCMTokenSafely();
      
      _isInitialized = true;
      debugPrint('NotificationService: ✅ Safe initialization completed');
      
    } catch (e, stackTrace) {
      debugPrint('NotificationService: ❌ Initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - let app continue without notifications
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Initialize local notifications with maximum safety
  Future<void> _initializeLocalNotificationsSafely() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
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
      );
      
      debugPrint('NotificationService: Local notifications initialized: $initialized');
      
      // Create notification channel for Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(_androidChannel);
          debugPrint('NotificationService: Android notification channel created');
        }
      }
    } catch (e) {
      debugPrint('NotificationService: ❌ Local notifications init error: $e');
      // Don't rethrow
    }
  }
  
  /// Request permissions with maximum safety and error handling
  Future<void> _requestPermissionsSafely() async {
    try {
      debugPrint('NotificationService: Requesting permissions safely...');
      
      // Add extra delay before permission request
      await Future.delayed(const Duration(seconds: 1));
      
      // Use a simpler permission request without timeout complications
      NotificationSettings? settings;
      
      try {
        settings = await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        
        debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');
        
        // Handle different permission states
        switch (settings.authorizationStatus) {
          case AuthorizationStatus.authorized:
            debugPrint('NotificationService: ✅ Notifications authorized');
            break;
          case AuthorizationStatus.denied:
            debugPrint('NotificationService: ❌ Notifications denied');
            break;
          case AuthorizationStatus.notDetermined:
            debugPrint('NotificationService: ⚠️ Permission not determined');
            break;
          case AuthorizationStatus.provisional:
            debugPrint('NotificationService: ⚠️ Provisional permission');
            break;
        }
        
      } catch (e) {
        debugPrint('NotificationService: Permission request failed: $e');
        // Continue without throwing error
      }
      
      // Additional platform-specific permissions
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _requestAndroidPermissions();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _requestIOSPermissions();
      }
      
    } catch (e) {
      debugPrint('NotificationService: ❌ Permission request error: $e');
      // Don't rethrow - let the app continue without notifications
    }
  }
  
  /// Request Android-specific permissions safely
  Future<void> _requestAndroidPermissions() async {
    try {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('NotificationService: Android notification permission: $granted');
      }
    } catch (e) {
      debugPrint('NotificationService: Android permission error: $e');
    }
  }
  
  /// Request iOS-specific permissions safely
  Future<void> _requestIOSPermissions() async {
    try {
      final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('NotificationService: iOS local notification permission: $granted');
      }
    } catch (e) {
      debugPrint('NotificationService: iOS permission error: $e');
    }
  }
  
  /// Setup message handlers safely
  Future<void> _setupMessageHandlers() async {
    try {
      // Configure foreground notification presentation
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          debugPrint('NotificationService: Foreground message: ${message.messageId}');
          _showLocalNotification(message);
        } catch (e) {
          debugPrint('NotificationService: Error handling foreground message: $e');
        }
      });
      
      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        try {
          debugPrint('NotificationService: Background message opened app');
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleMessageNavigation(message);
          });
        } catch (e) {
          debugPrint('NotificationService: Error handling background message: $e');
        }
      });
      
      // Handle initial message
      try {
        final initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('NotificationService: Initial message found');
          Future.delayed(const Duration(seconds: 2), () {
            _handleMessageNavigation(initialMessage);
          });
        }
      } catch (e) {
        debugPrint('NotificationService: Error getting initial message: $e');
      }
      
    } catch (e) {
      debugPrint('NotificationService: Error setting up message handlers: $e');
    }
  }
  
  /// Setup FCM token safely with retries
  Future<void> _setupFCMTokenSafely() async {
    try {
      String? token;
      
      // Try to get token with retries
      for (int i = 0; i < 3; i++) {
        try {
          token = await _firebaseMessaging.getToken();
          
          if (token != null) {
            debugPrint('NotificationService: FCM Token obtained: ${token.substring(0, 20)}...');
            break;
          }
          
          // Wait before retry
          if (i < 2) {
            await Future.delayed(Duration(seconds: (i + 1) * 2));
          }
        } catch (e) {
          debugPrint('NotificationService: Token attempt ${i + 1} failed: $e');
          if (i == 2) return; // Give up after 3 attempts
        }
      }
      
      if (token != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
          debugPrint('NotificationService: ✅ FCM Token saved');
          
          // Subscribe to default topic
          await _firebaseMessaging.subscribeToTopic('default');
          debugPrint('NotificationService: ✅ Subscribed to default topic');
        } catch (e) {
          debugPrint('NotificationService: Error saving token or subscribing: $e');
        }
      } else {
        debugPrint('NotificationService: ❌ Failed to get FCM token after retries');
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        try {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('fcm_token', newToken);
            debugPrint('NotificationService: Token refreshed');
          });
        } catch (e) {
          debugPrint('NotificationService: Error handling token refresh: $e');
        }
      });
      
    } catch (e) {
      debugPrint('NotificationService: Error setting up FCM token: $e');
    }
  }
  
  /// Show local notification
  void _showLocalNotification(RemoteMessage message) {
    try {
      final notification = message.notification;
      if (notification == null) return;
      
      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default Notifications',
        channelDescription: 'Default notification channel',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
        enableVibration: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails, 
        iOS: iosDetails,
      );
      
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(message.toMap()),
      );
      
      debugPrint('NotificationService: Local notification shown');
    } catch (e) {
      debugPrint('NotificationService: Error showing notification: $e');
    }
  }
  
  /// Handle navigation safely
  void _handleMessageNavigation(RemoteMessage message) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        debugPrint('NotificationService: No valid context for navigation');
        return;
      }
      
      final url = message.data['url'];
      if (url != null && url.isNotEmpty) {
        final route = url.startsWith('/') ? url : '/home';
        context.go(route);
        debugPrint('NotificationService: Navigated to: $route');
      } else {
        // Default navigation
        context.go('/home');
        debugPrint('NotificationService: Navigated to home (default)');
      }
    } catch (e) {
      debugPrint('NotificationService: Navigation error: $e');
    }
  }
  
  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('NotificationService: Notification tapped');
      
      if (response.payload != null) {
        final messageMap = jsonDecode(response.payload!);
        final message = RemoteMessage.fromMap(messageMap);
        
        // Small delay to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 300), () {
          _handleMessageNavigation(message);
        });
      } else {
        // No payload, just go to home
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          context.go('/home');
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Tap handler error: $e');
    }
  }
  
  /// Handle background messages
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      debugPrint('NotificationService: Background message: ${message.messageId}');
      
      // Save the message for later processing if needed
      final prefs = await SharedPreferences.getInstance();
      final pendingMessages = prefs.getStringList('pending_notification_messages') ?? [];
      pendingMessages.add(jsonEncode(message.toMap()));
      
      // Keep only the last 5 messages
      if (pendingMessages.length > 5) {
        pendingMessages.removeRange(0, pendingMessages.length - 5);
      }
      
      await prefs.setStringList('pending_notification_messages', pendingMessages);
    } catch (e) {
      debugPrint('NotificationService: Background message error: $e');
    }
  }
  
  /// Get current token
  Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint('NotificationService: Get token error: $e');
      return null;
    }
  }
  
  /// Test local notification (for debugging)
  Future<void> testLocalNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Channel',
        channelDescription: 'Channel for testing notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails, 
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        999,
        'Test Notification',
        'This is a test notification from PatelMart',
        details,
      );
      
      debugPrint('NotificationService: Test notification sent');
    } catch (e) {
      debugPrint('NotificationService: Test notification error: $e');
      rethrow;
    }
  }
}