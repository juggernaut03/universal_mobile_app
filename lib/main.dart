// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'presentation/providers/launch_flow_provider.dart';
import 'core/widgets/back_button_wrapper.dart';
import 'core/utils/back_handler.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Create a logger instance
  final logger = Logger();
  
  // Log app startup
  logger.log('Application starting...');
  
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