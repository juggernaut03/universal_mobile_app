// File: lib/data/services/firebase_notification_service.dart
import 'dart:convert';
import 'dart:io';
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
      debugPrint('NotificationService: Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      
      // Step 1: Initialize local notifications first (safer)
      await _initializeLocalNotificationsSafely();
      
      // Step 2: Request permissions with platform-specific handling
      await _requestPermissionsSafely();
      
      // Step 3: Setup message handlers
      await _setupMessageHandlers();
      
      // Step 4: Get FCM token with enhanced iOS support
      await _setupFCMTokenWithIOSSupport();
      
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
      debugPrint('NotificationService: Initializing local notifications...');
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS settings optimized for better compatibility
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // We handle this separately
        requestBadgePermission: false, // We handle this separately
        requestSoundPermission: false, // We handle this separately
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
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
      
      debugPrint('NotificationService: Local notifications initialized: $initialized');
      
      // Create notification channel for Android
      if (Platform.isAndroid) {
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
  
  /// Request permissions with enhanced iOS handling
  Future<void> _requestPermissionsSafely() async {
    try {
      debugPrint('NotificationService: Requesting permissions safely...');
      
      // Platform-specific permission handling
      if (Platform.isIOS) {
        await _requestIOSPermissions();
      } else {
        await _requestAndroidPermissions();
      }
      
    } catch (e) {
      debugPrint('NotificationService: ❌ Permission request error: $e');
      // Don't rethrow - let the app continue without notifications
    }
  }
  
  /// Request iOS-specific permissions with enhanced error handling
  Future<void> _requestIOSPermissions() async {
    try {
      debugPrint('NotificationService: 🍎 Requesting iOS permissions...');
      
      // Small delay to ensure app is ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Request Firebase Messaging permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );
      
      debugPrint('NotificationService: 🍎 Firebase permission status: ${settings.authorizationStatus}');
      
      // Configure foreground presentation for iOS
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('NotificationService: 🍎 Foreground presentation configured');
      
      // Request local notification permissions
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final localGranted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('NotificationService: 🍎 Local notification permission: $localGranted');
      }
      
    } catch (e) {
      debugPrint('NotificationService: ❌ iOS permission error: $e');
    }
  }
  
  /// Request Android-specific permissions
  Future<void> _requestAndroidPermissions() async {
    try {
      debugPrint('NotificationService: 🤖 Requesting Android permissions...');
      
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      debugPrint('NotificationService: 🤖 Permission status: ${settings.authorizationStatus}');
      
      // Request local notification permissions for Android
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('NotificationService: 🤖 Local notification permission: $granted');
      }
    } catch (e) {
      debugPrint('NotificationService: ❌ Android permission error: $e');
    }
  }
  
  /// Setup message handlers safely
  Future<void> _setupMessageHandlers() async {
    try {
      debugPrint('NotificationService: Setting up message handlers...');
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          debugPrint('NotificationService: 📨 Foreground message: ${message.messageId}');
          _showLocalNotification(message);
        } catch (e) {
          debugPrint('NotificationService: Error handling foreground message: $e');
        }
      });
      
      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        try {
          debugPrint('NotificationService: 📱 Background message opened app');
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
          debugPrint('NotificationService: 🚀 Initial message found');
          Future.delayed(const Duration(seconds: 2), () {
            _handleMessageNavigation(initialMessage);
          });
        }
      } catch (e) {
        debugPrint('NotificationService: Error getting initial message: $e');
      }
      
      debugPrint('NotificationService: ✅ Message handlers configured');
      
    } catch (e) {
      debugPrint('NotificationService: Error setting up message handlers: $e');
    }
  }
  
  /// Setup FCM token with enhanced iOS APNS token handling
  Future<void> _setupFCMTokenWithIOSSupport() async {
    try {
      debugPrint('NotificationService: 🔑 Starting FCM token setup...');
      
      String? token;
      
      if (Platform.isIOS) {
        // iOS-specific token handling with APNS support
        token = await _getIOSTokenWithAPNSHandling();
      } else {
        // Android token handling
        token = await _getAndroidTokenSafely();
      }
      
      if (token != null) {
        await _saveAndProcessToken(token);
      } else {
        debugPrint('NotificationService: ❌ Failed to get FCM token after all attempts');
        
        // Schedule a retry for later
        _scheduleTokenRetry();
      }
      
      // Set up token refresh listener
      _setupTokenRefreshListener();
      
    } catch (e) {
      debugPrint('NotificationService: Error setting up FCM token: $e');
    }
  }
  
  /// Get iOS token with enhanced APNS handling
  Future<String?> _getIOSTokenWithAPNSHandling() async {
    debugPrint('NotificationService: 🍎 Getting iOS FCM token with APNS handling...');
    
    try {
      // Method 1: Check if APNS token is immediately available
      final immediateApns = await _firebaseMessaging.getAPNSToken();
      if (immediateApns != null) {
        debugPrint('NotificationService: 🍎 APNS token immediately available');
        final fcmToken = await _firebaseMessaging.getToken();
        if (fcmToken != null) {
          debugPrint('NotificationService: ✅ FCM token obtained immediately');
          return fcmToken;
        }
      }
      
      // Method 2: Wait for APNS token to become available
      debugPrint('NotificationService: 🍎 Waiting for APNS token...');
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 1));
        
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('NotificationService: 🍎 APNS token available after ${i + 1} seconds');
          
          // Small delay to ensure token is fully ready
          await Future.delayed(const Duration(milliseconds: 500));
          
          final fcmToken = await _firebaseMessaging.getToken();
          if (fcmToken != null) {
            debugPrint('NotificationService: ✅ FCM token obtained after waiting');
            return fcmToken;
          }
        }
        
        debugPrint('NotificationService: ⏳ Waiting for APNS token... attempt ${i + 1}/15');
      }
      
      // Method 3: Force token refresh
      debugPrint('NotificationService: 🔄 Forcing token refresh...');
      await _firebaseMessaging.deleteToken();
      await Future.delayed(const Duration(seconds: 2));
      
      final refreshedToken = await _firebaseMessaging.getToken();
      if (refreshedToken != null) {
        debugPrint('NotificationService: ✅ FCM token obtained after forced refresh');
        return refreshedToken;
      }
      
      debugPrint('NotificationService: ❌ All iOS token acquisition methods failed');
      return null;
      
    } catch (e) {
      debugPrint('NotificationService: ❌ iOS token acquisition error: $e');
      return null;
    }
  }
  
  /// Get Android token safely
  Future<String?> _getAndroidTokenSafely() async {
    debugPrint('NotificationService: 🤖 Getting Android FCM token...');
    
    // Try to get token with retries for Android
    for (int i = 0; i < 3; i++) {
      try {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          debugPrint('NotificationService: ✅ Android FCM Token obtained: ${token.substring(0, 20)}...');
          return token;
        }
        
        // Wait before retry
        if (i < 2) {
          await Future.delayed(Duration(seconds: (i + 1) * 2));
        }
      } catch (e) {
        debugPrint('NotificationService: Android Token attempt ${i + 1} failed: $e');
        if (i == 2) break; // Give up after 3 attempts
      }
    }
    
    return null;
  }
  
  /// Save and process the obtained token
  Future<void> _saveAndProcessToken(String token) async {
    try {
      debugPrint('NotificationService: 💾 Saving FCM token: ${token.substring(0, 20)}...');
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      
      // Subscribe to default topic
      await _firebaseMessaging.subscribeToTopic('default');
      
      debugPrint('NotificationService: ✅ FCM token saved and subscribed to default topic');
    } catch (e) {
      debugPrint('NotificationService: ❌ Error saving token: $e');
    }
  }
  
  /// Schedule token retry for later
  void _scheduleTokenRetry() {
    debugPrint('NotificationService: ⏰ Scheduling token retry...');
    
    // Retry after 30 seconds
    Future.delayed(const Duration(seconds: 30), () async {
      try {
        debugPrint('NotificationService: 🔄 Attempting token retry...');
        
        String? token;
        if (Platform.isIOS) {
          token = await _getIOSTokenWithAPNSHandling();
        } else {
          token = await _getAndroidTokenSafely();
        }
        
        if (token != null) {
          await _saveAndProcessToken(token);
          debugPrint('NotificationService: ✅ Token obtained on retry');
        } else {
          debugPrint('NotificationService: ❌ Token retry also failed');
        }
      } catch (e) {
        debugPrint('NotificationService: ❌ Token retry error: $e');
      }
    });
  }
  
  /// Setup token refresh listener
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      try {
        debugPrint('NotificationService: 🔄 Token refreshed: ${newToken.substring(0, 20)}...');
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('fcm_token', newToken);
          debugPrint('NotificationService: ✅ New token saved');
        });
      } catch (e) {
        debugPrint('NotificationService: Error handling token refresh: $e');
      }
    });
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
        categoryIdentifier: 'default',
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
      
      debugPrint('NotificationService: ✅ Local notification shown');
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
      debugPrint('NotificationService: 👆 Notification tapped');
      
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
  
  /// Handle background notification tap
  void _onBackgroundNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('NotificationService: 🔄 Background notification tapped');
      _onNotificationTapped(response);
    } catch (e) {
      debugPrint('NotificationService: Background tap handler error: $e');
    }
  }
  
  /// Handle background messages
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      debugPrint('NotificationService: 📱 Background message: ${message.messageId}');
      
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
  
  /// Get current token with platform-specific handling
  Future<String?> getCurrentToken() async {
    try {
      if (Platform.isIOS) {
        // For iOS, ensure APNS token is available first
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('NotificationService: ⚠️ APNS token not available when getting current token');
          // Try to wait a bit for APNS token
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      
      final token = await _firebaseMessaging.getToken();
      if (token != null && kDebugMode) {
        debugPrint('NotificationService: Current token: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      debugPrint('NotificationService: Get token error: $e');
      return null;
    }
  }
  
  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('NotificationService: Error checking notification settings: $e');
      return false;
    }
  }
  
  /// Get APNS token (iOS only)
  Future<String?> getAPNSToken() async {
    try {
      if (Platform.isIOS) {
        return await _firebaseMessaging.getAPNSToken();
      }
      return null;
    } catch (e) {
      debugPrint('NotificationService: Error getting APNS token: $e');
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
      
      debugPrint('NotificationService: ✅ Test notification sent');
    } catch (e) {
      debugPrint('NotificationService: Test notification error: $e');
      rethrow;
    }
  }
  
  /// Force token refresh (useful for debugging iOS issues)
  Future<String?> forceTokenRefresh() async {
    try {
      debugPrint('NotificationService: 🔄 Forcing token refresh...');
      
      // Delete current token
      await _firebaseMessaging.deleteToken();
      await Future.delayed(const Duration(seconds: 1));
      
      // Get new token
      String? newToken;
      if (Platform.isIOS) {
        newToken = await _getIOSTokenWithAPNSHandling();
      } else {
        newToken = await _getAndroidTokenSafely();
      }
      
      if (newToken != null) {
        await _saveAndProcessToken(newToken);
        debugPrint('NotificationService: ✅ Token refresh successful');
      }
      
      return newToken;
    } catch (e) {
      debugPrint('NotificationService: ❌ Force token refresh error: $e');
      return null;
    }
  }
}