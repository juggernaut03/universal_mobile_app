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
// POPUP LIFECYCLE IMPORTS
import 'core/handlers/app_lifecycle_handler.dart';
import 'presentation/providers/popup_providers.dart';

// Global navigator key for navigation from background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // ONLY initialize Firebase if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    print('Background message received: ${message.messageId}');
  } catch (e) {
    print('Background handler error: $e');
    // Don't rethrow - let app continue
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Lock orientation FIRST (this is safe)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Initialize SharedPreferences EARLY (this is safe)
    final sharedPreferences = await SharedPreferences.getInstance();
    final logger = Logger();
    
    logger.log('Starting app initialization...');
    
    // Initialize Firebase with error handling
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      logger.log('Firebase initialized successfully');
      
      // Set background message handler ONLY after Firebase is initialized
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      logger.log('Background message handler set');
    } catch (e) {
      logger.error('Firebase initialization failed: $e');
      // Don't stop app - continue without Firebase
    }
    
    logger.log('Application starting...');
    
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          loggerProvider.overrideWithValue(logger),
          backButtonHandlerProvider.overrideWithValue(BackButtonHandler(logger: logger)),
        ],
        child: const AppWithLifecycleHandler(),
      ),
    );
    
  } catch (e, stackTrace) {
    print('CRITICAL ERROR in main(): $e');
    print('Stack trace: $stackTrace');
    
    // Ensure we always show SOMETHING to the user
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded, 
                      size: 64, 
                      color: Colors.orange
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'App is starting...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please wait a moment and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // Restart the app
                        SystemNavigator.pop();
                      },
                      child: const Text('Restart App'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that handles app lifecycle for popup management
class AppWithLifecycleHandler extends ConsumerStatefulWidget {
  const AppWithLifecycleHandler({super.key});

  @override
  ConsumerState<AppWithLifecycleHandler> createState() => _AppWithLifecycleHandlerState();
}

class _AppWithLifecycleHandlerState extends ConsumerState<AppWithLifecycleHandler> 
    with WidgetsBindingObserver {
  
  AppLifecycleState? _lastLifecycleState;
  bool _hasInitializedPopupSystem = false;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize popup system after app is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePopupSystem();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializePopupSystem() {
    if (!_hasInitializedPopupSystem) {
      try {
        // Initialize the app lifecycle handler provider
        ref.read(appLifecycleHandlerProvider);
        _hasInitializedPopupSystem = true;
        
        ref.read(loggerProvider).log('✅ Popup lifecycle system initialized');
      } catch (e) {
        ref.read(loggerProvider).error('❌ Failed to initialize popup system: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final logger = ref.read(loggerProvider);
    logger.log('App lifecycle changed: ${state.name}');
    
    // Handle popup behavior based on app lifecycle
    try {
      // App coming from background/paused to foreground
      if (_lastLifecycleState == AppLifecycleState.paused && 
          state == AppLifecycleState.resumed) {
        
        logger.log('🚀 App resumed from background - resetting popup for new session');
        
        // Reset popup state for new session when app comes to foreground
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(popupDisplayStateProvider.notifier).resetForNewSession();
          }
        });
      }
      
      // App starting fresh
      else if (_lastLifecycleState == null && state == AppLifecycleState.resumed) {
        logger.log('🎯 App launched fresh - popup system ready');
        
        // Ensure popup system is initialized on fresh launch
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_hasInitializedPopupSystem) {
            _initializePopupSystem();
          }
        });
      }
      
    } catch (e) {
      logger.error('Error handling app lifecycle change: $e');
    }
    
    _lastLifecycleState = state;
  }

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}