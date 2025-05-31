import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationDebugger {
  static const String _tag = 'NotificationDebugger';
  
  /// Check Firebase setup and permissions
  static Future<void> debugFirebaseSetup() async {
    try {
      debugPrint('$_tag: === FIREBASE SETUP DEBUG ===');
      
      final messaging = FirebaseMessaging.instance;
      debugPrint('$_tag: Firebase messaging instance created ✅');
      
      // Get FCM token
      final token = await messaging.getToken();
      debugPrint('$_tag: FCM Token: $token');
      
      if (token == null) {
        debugPrint('$_tag: ❌ FCM Token is null - check Firebase configuration');
        return;
      }
      
      // Check notification permissions
      final settings = await messaging.getNotificationSettings();
      debugPrint('$_tag: Permission status: ${settings.authorizationStatus}');
      
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          debugPrint('$_tag: ✅ Notifications are authorized');
          break;
        case AuthorizationStatus.denied:
          debugPrint('$_tag: ❌ Notifications are denied');
          break;
        case AuthorizationStatus.notDetermined:
          debugPrint('$_tag: ⚠️ Notification permission not determined');
          break;
        case AuthorizationStatus.provisional:
          debugPrint('$_tag: ⚠️ Provisional notification permission');
          break;
      }
      
    } catch (e) {
      debugPrint('$_tag: ❌ Firebase setup error: $e');
    }
  }
  
  /// Test local notifications functionality
  static Future<void> testLocalNotifications() async {
    try {
      debugPrint('$_tag: === LOCAL NOTIFICATIONS TEST ===');
      
      final localNotifications = FlutterLocalNotificationsPlugin();
      
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Channel',
        channelDescription: 'Channel for testing notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
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
      
      await localNotifications.show(
        999,
        'Test Notification',
        'This is a test notification - if you see this, local notifications work!',
        details,
      );
      
      debugPrint('$_tag: ✅ Test notification sent');
      
    } catch (e) {
      debugPrint('$_tag: ❌ Local notification test error: $e');
    }
  }
  
  /// Generate comprehensive debug report
  static Future<String> generateDebugReport() async {
    final report = StringBuffer();
    report.writeln('=== FIREBASE PUSH NOTIFICATION DEBUG REPORT ===');
    report.writeln('Generated: ${DateTime.now()}');
    report.writeln('Platform: ${defaultTargetPlatform}');
    report.writeln();
    
    try {
      // FCM Token
      final token = await FirebaseMessaging.instance.getToken();
      report.writeln('FCM Token: ${token ?? "NULL"}');
      
      // Permissions
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      report.writeln('Authorization Status: ${settings.authorizationStatus}');
      report.writeln('Alert Setting: ${settings.alert}');
      report.writeln('Badge Setting: ${settings.badge}');
      report.writeln('Sound Setting: ${settings.sound}');
      
      // SharedPreferences check
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('fcm_token');
      report.writeln('Saved Token: ${savedToken ?? "NULL"}');
      
      // Check for pending messages
      final pendingMessages = prefs.getStringList('pending_notification_messages') ?? [];
      report.writeln('Pending Messages: ${pendingMessages.length}');
      
      report.writeln();
      report.writeln('=== TROUBLESHOOTING CHECKLIST ===');
      report.writeln('✓ Check if notification icon exists: @drawable/ic_notification');
      report.writeln('✓ Verify Firebase configuration files are in place');
      report.writeln('✓ Confirm package name matches Firebase project');
      report.writeln('✓ Test with Firebase Console send test message');
      report.writeln('✓ Check device notification settings for the app');
      report.writeln('✓ Ensure app is not in battery optimization');
      
    } catch (e) {
      report.writeln('Error generating report: $e');
    }
    
    final reportString = report.toString();
    debugPrint('$_tag: $reportString');
    return reportString;
  }
}