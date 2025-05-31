import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_core/firebase_core.dart'; // Add this
import 'app.dart';
import 'presentation/providers/launch_flow_provider.dart';
import 'core/widgets/back_button_wrapper.dart';
import 'core/utils/back_handler.dart';
import 'core/utils/logger.dart';
import 'data/services/simple_notification_service.dart'; // Add this

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
FirebaseMessaging.instance.subscribeToTopic("default");
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Create a logger instance
  final logger = Logger();
  
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
      ],
      child: const MyApp(),
    ),
  );
}