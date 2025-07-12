import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/models/auth_models.dart';
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
// NOTIFICATION IMPORTS
import 'data/services/firebase_notification_service.dart';
// FCM TOKEN IMPORTS
import 'presentation/providers/auth_providers.dart';

// Global navigator key for navigation from background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler - MUST be top-level function with enhanced iOS support
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    print('🔔 Background message handler started');
    print('   Message ID: ${message.messageId}');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');
    
    // ONLY initialize Firebase if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('🔥 Firebase initialized in background handler');
    }
    
    // Handle the background message using the service
    await FirebaseNotificationService.handleBackgroundMessage(message);
    print('✅ Background message handled successfully');
    
  } catch (e, stackTrace) {
    print('❌ Background handler error: $e');
    print('Stack trace: $stackTrace');
    // Don't rethrow - let app continue
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('🚀 App starting - Flutter binding initialized');
    
    // Lock orientation FIRST (this is safe)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('📱 Orientation locked to portrait');
    
    // Initialize SharedPreferences EARLY (this is safe)
    final sharedPreferences = await SharedPreferences.getInstance();
    final logger = Logger();
    
    logger.log('Starting app initialization...');
    
    // Initialize Firebase with enhanced error handling and iOS support
    try {
      print('🔥 Initializing Firebase...');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      logger.log('✅ Firebase initialized successfully');
      
      // Set background message handler ONLY after Firebase is initialized
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      logger.log('📱 Background message handler set');
      
      // Enable Firebase Messaging auto initialization for better iOS support
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      logger.log('🔄 Firebase Messaging auto-init enabled');
      
      // Log current Firebase project for debugging
      if (kDebugMode) {
        final app = Firebase.app();
        logger.log('📊 Firebase project: ${app.options.projectId}');
        logger.log('📊 iOS bundle ID: ${app.options.iosBundleId}');
      }
      
    } catch (e, stackTrace) {
      logger.error('❌ Firebase initialization failed: $e');
      logger.error('Stack trace: $stackTrace');
      // Don't stop app - continue without Firebase but log the issue
      print('⚠️ Continuing without Firebase - some features may be limited');
    }
    
    logger.log('🎯 Application starting...');
    
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          loggerProvider.overrideWithValue(logger),
          backButtonHandlerProvider.overrideWithValue(BackButtonHandler(logger: logger)),
        ],
        child: const AppWithLifecycleAndNotificationHandler(),
      ),
    );
    
  } catch (e, stackTrace) {
    print('❌ CRITICAL ERROR in main(): $e');
    print('Stack trace: $stackTrace');
    
    // Ensure we always show SOMETHING to the user
    runApp(
      MaterialApp(
        title: 'PatelMart',
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
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Enhanced wrapper widget that handles BOTH app lifecycle for popup management AND notifications
class AppWithLifecycleAndNotificationHandler extends ConsumerStatefulWidget {
  const AppWithLifecycleAndNotificationHandler({super.key});

  @override
  ConsumerState<AppWithLifecycleAndNotificationHandler> createState() => _AppWithLifecycleAndNotificationHandlerState();
}

class _AppWithLifecycleAndNotificationHandlerState extends ConsumerState<AppWithLifecycleAndNotificationHandler> 
    with WidgetsBindingObserver {
  
  AppLifecycleState? _lastLifecycleState;
  bool _hasInitializedPopupSystem = false;
  bool _hasInitializedNotifications = false;
  bool _hasInitializedFcmTokenSystem = false;
  bool _appFullyInitialized = false;

  @override
  void initState() {
    super.initState();
    print('🎯 App lifecycle handler initializing...');
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize app systems after app is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppSystems();
    });
  }

  @override
  void dispose() {
    print('🔄 App lifecycle handler disposing...');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Initialize all app systems including FCM token management
  Future<void> _initializeAppSystems() async {
    try {
      final logger = ref.read(loggerProvider);
      logger.log('🚀 Starting app systems initialization...');
      
      // STEP 1: Initialize popup system first (lighter)
      _initializePopupSystem();
      
      // STEP 2: Initialize app launch flow
      await _initializeAppLaunchFlow();
      
      // STEP 3: Initialize FCM token system
      _initializeFcmTokenSystem();
      
      // Mark app as ready
      if (mounted) {
        setState(() {
          _appFullyInitialized = true;
        });
        logger.log('✅ App marked as fully initialized');
      }
      
      // STEP 4: Initialize notifications AFTER app is stable (separate) with iOS support
      _initializeNotificationsWhenSafe();
      
      logger.log('✅ App systems initialization completed');
      
    } catch (e, stackTrace) {
      ref.read(loggerProvider).error('❌ App systems initialization failed: $e');
      ref.read(loggerProvider).error('Stack trace: $stackTrace');
      // Don't crash - just mark as initialized
      if (mounted) {
        setState(() {
          _appFullyInitialized = true;
        });
      }
    }
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

  Future<void> _initializeAppLaunchFlow() async {
    try {
      // Initialize launch flow if needed
      final launchState = ref.read(launchFlowProvider);
      ref.read(loggerProvider).log('🚀 Launch state: $launchState');
      // Add any launch flow initialization here if needed
    } catch (e) {
      ref.read(loggerProvider).error('❌ Launch flow initialization error: $e');
    }
  }

  /// Initialize FCM token management system
  void _initializeFcmTokenSystem() {
    if (!_hasInitializedFcmTokenSystem) {
      try {
        final logger = ref.read(loggerProvider);
        logger.log('🔐 Starting FCM token system initialization...');
        
        // Initialize FCM token auto-save watcher
        ref.read(fcmTokenAutoSaveWatcherProvider);
        
        // Initialize FCM token background manager
        ref.read(fcmTokenBackgroundManagerProvider);
        
        _hasInitializedFcmTokenSystem = true;
        logger.log('✅ FCM token system initialized successfully');
        
      } catch (e) {
        ref.read(loggerProvider).error('❌ Failed to initialize FCM token system: $e');
        // Don't crash - FCM is not critical for app function
      }
    }
  }

  /// Initialize notifications AFTER app is completely stable with enhanced iOS support
  Future<void> _initializeNotificationsWhenSafe() async {
    if (_hasInitializedNotifications) {
      ref.read(loggerProvider).log('📱 Notifications already initialized, skipping');
      return;
    }
    
    try {
      final logger = ref.read(loggerProvider);
      logger.log('🔔 Starting notification initialization...');
      
      // Wait for app to be completely stable - longer delay for iOS
      await Future.delayed(const Duration(seconds: 4));
      
      // Check if we're still mounted and app is ready
      if (!mounted || !_appFullyInitialized) {
        logger.log('⚠️ App not ready for notifications, skipping initialization');
        return;
      }
      
      logger.log('📱 App is stable, initializing notification service...');
      
      // Initialize the notification service with enhanced error handling
      final notificationService = ref.read(firebaseNotificationServiceProvider);
      await notificationService.initializeWhenReady();
      
      _hasInitializedNotifications = true;
      logger.log('✅ Notifications initialized successfully');
      
      // Additional iOS-specific checks in debug mode
      if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS) {
        _performIOSNotificationDebugChecks(notificationService, logger);
      }
      
    } catch (e, stackTrace) {
      ref.read(loggerProvider).error('⚠️ Notification initialization failed: $e');
      ref.read(loggerProvider).error('Stack trace: $stackTrace');
      // Don't crash the app - just continue without notifications
    }
  }

  /// Perform iOS-specific debug checks for notifications
  void _performIOSNotificationDebugChecks(FirebaseNotificationService service, Logger logger) async {
    try {
      logger.log('🍎 Performing iOS notification debug checks...');
      
      // Check notification permissions
      final enabled = await service.areNotificationsEnabled();
      logger.log('📱 iOS Notifications enabled: $enabled');
      
      // Check FCM token availability
      final fcmToken = await service.getCurrentToken();
      logger.log('🔑 FCM Token available: ${fcmToken != null}');
      if (fcmToken != null) {
        logger.log('🔑 FCM Token preview: ${fcmToken.substring(0, 20)}...');
      }
      
      // Check APNS token availability (iOS specific)
      final apnsToken = await service.getAPNSToken();
      logger.log('🍎 APNS Token available: ${apnsToken != null}');
      if (apnsToken != null) {
        logger.log('🍎 APNS Token preview: ${apnsToken.substring(0, 20)}...');
      }
      
      // Log Firebase project info for verification
      if (Firebase.apps.isNotEmpty) {
        final app = Firebase.app();
        logger.log('🔥 Firebase project: ${app.options.projectId}');
        logger.log('📱 Bundle ID: ${app.options.iosBundleId}');
      }
      
    } catch (e) {
      logger.error('❌ iOS debug checks failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final logger = ref.read(loggerProvider);
    logger.log('📱 App lifecycle changed: ${state.name}');
    
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

        // Handle FCM token check on app resume
        _handleFcmTokenOnAppResume();
        
        // Check notification status on app resume (iOS specific)
        if (defaultTargetPlatform == TargetPlatform.iOS && _hasInitializedNotifications) {
          _checkNotificationStatusOnResume();
        }
      }
      
      // App starting fresh
      else if (_lastLifecycleState == null && state == AppLifecycleState.resumed) {
        logger.log('🎯 App launched fresh - popup system ready');
        
        // Ensure systems are initialized on fresh launch
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_hasInitializedPopupSystem) {
            _initializePopupSystem();
          }
          if (mounted && !_hasInitializedFcmTokenSystem) {
            _initializeFcmTokenSystem();
          }
        });
      }
      
    } catch (e) {
      logger.error('❌ Error handling app lifecycle change: $e');
    }
    
    _lastLifecycleState = state;
  }

  /// Check notification status when app resumes (iOS specific)
  void _checkNotificationStatusOnResume() {
    try {
      final logger = ref.read(loggerProvider);
      logger.log('🔔 Checking notification status on app resume...');
      
      Future.delayed(const Duration(seconds: 1), () async {
        if (!mounted) return;
        
        try {
          final service = ref.read(firebaseNotificationServiceProvider);
          final enabled = await service.areNotificationsEnabled();
          
          if (!enabled) {
            logger.warning('⚠️ Notifications are disabled - user may have changed settings');
          } else {
            logger.log('✅ Notifications are still enabled');
          }
        } catch (e) {
          logger.error('❌ Error checking notification status: $e');
        }
      });
    } catch (e) {
      ref.read(loggerProvider).error('❌ Error in notification status check: $e');
    }
  }

  /// Handle FCM token check when app resumes from background
  void _handleFcmTokenOnAppResume() {
    try {
      final logger = ref.read(loggerProvider);
      logger.log('🔐 Checking FCM token on app resume...');
      
      // Check if user is logged in and FCM token needs update
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        
        try {
          final userProfileAsync = ref.read(userProfileProvider);
          final userProfile = await userProfileAsync.future;
           
          if (userProfile != null) {
            logger.log('👤 User is logged in, checking FCM token status...');
            
            final authService = ref.read(authServiceProvider);
            final needsUpdate = await authService.shouldUpdateFcmToken();
            
            if (needsUpdate) {
              logger.log('🔄 FCM token needs update on app resume, refreshing...');
              final success = await authService.refreshFcmToken();
              
              if (success) {
                logger.log('✅ FCM token refreshed successfully on app resume');
              } else {
                logger.warning('⚠️ FCM token refresh failed on app resume');
              }
            } else {
              logger.log('✅ FCM token is up to date on app resume');
            }
          }
        } catch (e) {
          logger.error('❌ Error checking FCM token on app resume: $e');
        }
      });
    } catch (e) {
      ref.read(loggerProvider).error('❌ Error in FCM token app resume handler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen until app is ready
    if (!_appFullyInitialized) {
      return MaterialApp(
        title: 'PatelMart',
        home: Scaffold(
          backgroundColor: Colors.white,
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo placeholder
                FlutterLogo(size: 80),
                SizedBox(height: 24),
                
                // Loading indicator
                CircularProgressIndicator(),
                SizedBox(height: 16),
                
                // Loading text
                Text(
                  'Loading PatelMart...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                SizedBox(height: 8),
                
                // Initialization status
                Text(
                  'Initializing systems...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // App is ready - show the main app wrapped with FCM token initializer
    return const FcmTokenAwareMyApp();
  }
}

extension on AsyncValue<UserProfile?> {
  get future => null;
}

/// Wrapper for MyApp that ensures FCM token management is active
class FcmTokenAwareMyApp extends ConsumerWidget {
  const FcmTokenAwareMyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch FCM token providers to keep them active
    ref.watch(fcmTokenAutoSaveWatcherProvider);
    ref.watch(fcmTokenBackgroundManagerProvider);
    
    // Optional: Watch user profile changes for FCM token management
    final userProfileAsync = ref.watch(userProfileProvider);
    
    // Log FCM token status changes in debug mode
    if (kDebugMode) {
      userProfileAsync.whenData((userProfile) {
        if (userProfile != null) {
          final logger = ref.read(loggerProvider);
          logger.log('🔐 FCM: User profile available for ${userProfile.mobile}');
          
          // Check FCM token status
          ref.read(fcmTokenStatusProvider).whenData((status) {
            if (status['tokens_match'] != true) {
              logger.log('⚠️ FCM: Token status - needs attention');
            } else {
              logger.log('✅ FCM: Token status - up to date');
            }
          });
        }
      });
    }
    
    return const MyApp();
  }
}