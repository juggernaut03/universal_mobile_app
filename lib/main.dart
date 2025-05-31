import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'presentation/providers/launch_flow_provider.dart';
import 'core/widgets/back_button_wrapper.dart';
import 'core/utils/back_handler.dart';
import 'core/utils/logger.dart';
import 'data/services/firebase_notification_service.dart';

// Global navigator key for navigation from background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print('Background message received: ${message.messageId}');
  print('Background message title: ${message.notification?.title}');
  print('Background message body: ${message.notification?.body}');
  print('Background message data: ${message.data}');
  
  // Handle the background message
  await FirebaseNotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set background message handler BEFORE calling runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Create a logger instance
  final logger = Logger();
  
  // Initialize Firebase Notifications
  final notificationService = FirebaseNotificationService();
  await notificationService.initialize();
  
  // Log app startup
  logger.log('Application starting with notifications enabled...');
  
  runApp(
    ProviderScope(
      overrides: [
        // Override the SharedPreferences provider with the instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        // Override the logger provider with the instance
        loggerProvider.overrideWithValue(logger),
        // Override the BackButtonHandler provider with a new instance
        backButtonHandlerProvider.overrideWithValue(BackButtonHandler(logger: logger)),
        // Override notification service provider
        firebaseNotificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const MyApp(),
    ),
  );
}
