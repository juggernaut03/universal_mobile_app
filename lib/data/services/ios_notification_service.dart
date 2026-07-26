// File: lib/data/services/ios_notification_service_fixed.dart
import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final logger = Logger();
  logger.log('Background notification received: ${message.notification?.title}');
}

class IOSNotificationService {
  static final IOSNotificationService _instance = IOSNotificationService._internal();
  factory IOSNotificationService() => _instance;
  IOSNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();
  
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  /// Initialize notifications with proper iOS APNS handling
  Future<void> initializeWhenReady() async {
    if (_isInitialized || _isInitializing) {
      _logger.log('Notification service already initialized or initializing');
      return;
    }

    _isInitializing = true;
    
    try {
      _logger.log('🚀 Starting iOS notification service initialization');
      
      // Step 1: Request permissions FIRST (critical for iOS)
      await _requestIOSPermissions();
      
      // Step 2: Initialize local notifications
      await _initializeLocalNotifications();
      
      // Step 3: Wait for app to be fully ready (crucial for iOS)
      await _waitForAppReadiness();
      
      // Step 4: Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Step 5: Configure iOS-specific settings
      await _configureIOSSettings();
      
      // Step 6: Set up message listeners
      _setupMessageListeners();
      
      // Step 7: Get FCM token with proper iOS handling
      await _getIOSTokenWithProperHandling();
      
      _isInitialized = true;
      _logger.log('✅ iOS notification service initialized successfully');
      
    } catch (e) {
      _logger.error('❌ Error initializing iOS notifications: $e');
      // Don't rethrow - let app continue
    } finally {
      _isInitializing = false;
    }
  }

  /// Request iOS permissions with proper sequence
  Future<void> _requestIOSPermissions() async {
    try {
      _logger.log('📋 Requesting iOS notification permissions...');
      
      // First request Firebase Messaging permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );
      
      _logger.log('🔐 Firebase permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        throw Exception('Firebase notification permissions denied by user');
      }
      
      // Wait a bit after permission request
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Request local notification permissions
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final localGranted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _logger.log('📱 Local notification permission: $localGranted');
      }
      
    } catch (e) {
      _logger.error('❌ Error requesting iOS permissions: $e');
      rethrow;
    }
  }

  /// Wait for app to be fully ready (critical for iOS APNS)
  Future<void> _waitForAppReadiness() async {
    _logger.log('⏳ Waiting for app readiness...');
    
    // Wait for the app to be fully initialized
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if we're in the correct lifecycle state
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _logger.log('✅ App is in resumed state');
    } else {
      _logger.log('⚠️ App is not in resumed state: ${WidgetsBinding.instance.lifecycleState}');
      // Wait a bit more for app to be ready
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Configure iOS-specific Firebase Messaging settings
  Future<void> _configureIOSSettings() async {
    if (!Platform.isIOS) return;
    
    try {
      _logger.log('⚙️ Configuring iOS Firebase settings...');
      
      // Set foreground notification presentation options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Set auto initialization (this helps with APNS token)
      await _firebaseMessaging.setAutoInitEnabled(true);
      
      _logger.log('✅ iOS Firebase settings configured');
      
    } catch (e) {
      _logger.error('❌ Error configuring iOS settings: $e');
    }
  }

  /// Get FCM token with proper iOS APNS handling
  Future<void> _getIOSTokenWithProperHandling() async {
    _logger.log('🎯 Starting iOS FCM token retrieval...');
    
    try {
      // Method 1: Try immediate token retrieval
      String? token = await _tryImmediateTokenRetrieval();
      
      if (token != null) {
        await _saveAndProcessToken(token);
        return;
      }
      
      // Method 2: Wait for APNS token and retry
      token = await _waitForAPNSAndRetryToken();
      
      if (token != null) {
        await _saveAndProcessToken(token);
        return;
      }
      
      // Method 3: Force APNS token refresh and retry
      token = await _forceAPNSRefreshAndRetryToken();
      
      if (token != null) {
        await _saveAndProcessToken(token);
        return;
      }
      
      // Method 4: Schedule delayed retry
      _scheduleDelayedTokenRetrieval();
      
    } catch (e) {
      _logger.error('❌ Error in iOS token handling: $e');
    }
  }

  /// Try immediate token retrieval
  Future<String?> _tryImmediateTokenRetrieval() async {
    try {
      _logger.log('🔄 Attempting immediate token retrieval...');
      
      // Check if APNS token is already available
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      if (apnsToken != null) {
        _logger.log('✅ APNS token immediately available');
        return await _firebaseMessaging.getToken();
      } else {
        _logger.log('⚠️ APNS token not immediately available');
        return null;
      }
    } catch (e) {
      _logger.error('❌ Immediate token retrieval failed: $e');
      return null;
    }
  }

  /// Wait for APNS token and retry FCM token
  Future<String?> _waitForAPNSAndRetryToken() async {
    _logger.log('⏳ Waiting for APNS token availability...');
    
    try {
      // Wait up to 15 seconds for APNS token
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 1));
        
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) {
          _logger.log('✅ APNS token available after ${i + 1} seconds');
          
          // Small delay to ensure everything is ready
          await Future.delayed(const Duration(milliseconds: 500));
          
          return await _firebaseMessaging.getToken();
        }
        
        _logger.log('⏳ Waiting for APNS... attempt ${i + 1}/15');
      }
      
      _logger.log('⚠️ APNS token not available after 15 seconds');
      return null;
    } catch (e) {
      _logger.error('❌ Error waiting for APNS token: $e');
      return null;
    }
  }

  /// Force APNS token refresh and retry
  Future<String?> _forceAPNSRefreshAndRetryToken() async {
    _logger.log('🔄 Forcing APNS token refresh...');
    
    try {
      // Delete current FCM token to force refresh
      await _firebaseMessaging.deleteToken();
      _logger.log('🗑️ Deleted existing FCM token');
      
      // Wait a bit
      await Future.delayed(const Duration(seconds: 2));
      
      // Try to get new token
      final newToken = await _firebaseMessaging.getToken();
      if (newToken != null) {
        _logger.log('✅ FCM token obtained after forced refresh');
        return newToken;
      }
      
      _logger.log('❌ Failed to get token after forced refresh');
      return null;
    } catch (e) {
      _logger.error('❌ Error forcing APNS refresh: $e');
      return null;
    }
  }

  /// Schedule delayed token retrieval for later
  void _scheduleDelayedTokenRetrieval() {
    _logger.log('⏰ Scheduling delayed token retrieval...');
    
    // Try again after 30 seconds
    Future.delayed(const Duration(seconds: 30), () async {
      try {
        _logger.log('🔄 Attempting delayed token retrieval...');
        
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          _logger.log('✅ FCM token obtained in delayed attempt');
          await _saveAndProcessToken(token);
        } else {
          _logger.log('❌ Delayed token retrieval also failed');
          
          // Try one more time after app becomes active
          _setupAppLifecycleTokenRetry();
        }
      } catch (e) {
        _logger.error('❌ Delayed token retrieval error: $e');
      }
    });
  }

  /// Setup app lifecycle-based token retry
  void _setupAppLifecycleTokenRetry() {
    _logger.log('🔄 Setting up app lifecycle token retry...');
    
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver((state) async {
      if (state == AppLifecycleState.resumed) {
        _logger.log('📱 App resumed, trying token retrieval...');
        
        // Wait a bit for app to be fully ready
        await Future.delayed(const Duration(seconds: 1));
        
        try {
          final token = await _firebaseMessaging.getToken();
          if (token != null) {
            _logger.log('✅ FCM token obtained on app resume');
            await _saveAndProcessToken(token);
            
            // Remove observer after success
            WidgetsBinding.instance.removeObserver(_AppLifecycleObserver((state) {}));
          }
        } catch (e) {
          _logger.error('❌ App resume token retrieval error: $e');
        }
      }
    }));
  }

  /// Save and process the obtained token
  Future<void> _saveAndProcessToken(String token) async {
    try {
      _logger.log('💾 Saving FCM token: ${token.substring(0, 300)}...');
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      
      // Subscribe to default topic
      await _firebaseMessaging.subscribeToTopic('default');
      
      _logger.log('✅ FCM token saved and subscribed to default topic');
    } catch (e) {
      _logger.error('❌ Error saving token: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
      
      // iOS settings optimized for iOS 10+
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

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
      );
      
      _logger.log('✅ Local notifications initialized');
      
    } catch (e) {
      _logger.error('❌ Error initializing local notifications: $e');
      rethrow;
    }
  }

  /// Setup message listeners
  void _setupMessageListeners() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle app opened from terminated state
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
    
    _logger.log('✅ Message listeners configured');
  }

  /// Handle foreground notifications
  void _handleForegroundMessage(RemoteMessage message) {
    _logger.log('📨 Foreground notification: ${message.notification?.title}');
    
    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Show local notification when app is in foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;
      
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: 'default',
          ),
        ),
        payload: jsonEncode(message.toMap()),
      );
      
      _logger.log('✅ Local notification shown');
      
    } catch (e) {
      _logger.error('❌ Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    _logger.log('👆 Notification tapped');
    _logger.log('Title: ${message.notification?.title}');
    _logger.log('Body: ${message.notification?.body}');
    _logger.log('Data: ${message.data}');
    
    // Handle navigation based on notification data
    final data = message.data;
    if (data.isNotEmpty) {
      _handleNotificationNavigation(data);
    }
  }

  /// Handle notification-based navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    _logger.log('🧭 Handling navigation with data: $data');
    
    // Implement your navigation logic based on notification data
    // Example:
    // if (data.containsKey('product_id')) {
    //   // Navigate to product page
    // } else if (data.containsKey('order_id')) {
    //   // Navigate to order page
    // }
  }

  /// Handle notification response
  static void _onDidReceiveNotificationResponse(NotificationResponse details) {
    final logger = Logger();
    logger.log('👆 Notification response: ${details.payload}');
    
    if (details.payload != null) {
      try {
        final data = jsonDecode(details.payload!);
        logger.log('📊 Handling notification response data: $data');
      } catch (e) {
        logger.error('❌ Error processing notification response: $e');
      }
    }
  }

  /// Handle background notification response
  static void _onDidReceiveBackgroundNotificationResponse(NotificationResponse details) {
    final logger = Logger();
    logger.log('🔄 Background notification response: ${details.payload}');
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      _logger.error('❌ Error getting current token: $e');
      return null;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      _logger.error('❌ Error checking notification settings: $e');
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
      _logger.error('❌ Error getting APNS token: $e');
      return null;
    }
  }

  /// Test notification (for debugging)
  Future<void> sendTestNotification() async {
    try {
      await _localNotifications.show(
        999,
        'Test Notification',
        'This is a test notification from iOS service',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Channel',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      _logger.log('✅ Test notification sent');
    } catch (e) {
      _logger.error('❌ Error sending test notification: $e');
    }
  }
}

/// Custom app lifecycle observer for token retry
class _AppLifecycleObserver with WidgetsBindingObserver {
  final Function(AppLifecycleState) _onStateChanged;
  
  _AppLifecycleObserver(this._onStateChanged);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _onStateChanged(state);
  }
}