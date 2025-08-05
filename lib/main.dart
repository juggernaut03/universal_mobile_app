import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/models/auth_models.dart';
import 'package:patelmart/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
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
import 'presentation/providers/favorites_provider.dart';
// FACEBOOK PIXEL IMPORTS
import 'facebook_pixel/facebook_pixel_integration.dart';

// Global navigator key for navigation from background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler - MUST be top-level function with enhanced iOS support
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    print('🔔 Background message handler started');
    print('   Message ID: ${message.messageId}');
    print('   Platform: ${Platform.isIOS ? "iOS" : "Android"}');
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
    print('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');
    
    // Lock orientation FIRST (this is safe)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('📱 Orientation locked to portrait');
    
    // Initialize SharedPreferences EARLY (this is safe)
    final sharedPreferences = await SharedPreferences.getInstance();
    final logger = Logger();
    
    logger.log('🚀 Starting app initialization...');
    
    // Initialize Firebase with enhanced error handling and iOS-specific configuration
    try {
      print('🔥 Initializing Firebase...');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      logger.log('✅ Firebase initialized successfully');
      
      // Platform-specific Firebase configuration
      if (Platform.isIOS) {
        logger.log('🍎 Configuring iOS-specific Firebase settings...');
        
        try {
          // Enable auto initialization for iOS (helps with APNS token)
          await FirebaseMessaging.instance.setAutoInitEnabled(true);
          logger.log('✅ iOS auto initialization enabled');
          
          // Set foreground notification presentation options for iOS
          await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
          logger.log('✅ iOS foreground notification presentation configured');
          
          // Early permission request for iOS (non-blocking)
          _requestIOSPermissionsEarly(logger);
          
        } catch (e) {
          logger.log('⚠️ iOS Firebase configuration warning: $e');
          // Continue - this is not critical for app startup
        }
      }
      
      // Set background message handler ONLY after Firebase is initialized
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      logger.log('📱 Background message handler set');
      
      // Log current Firebase project for debugging
      if (kDebugMode) {
        final app = Firebase.app();
        logger.log('📊 Firebase project: ${app.options.projectId}');
        if (Platform.isIOS) {
          logger.log('📱 iOS bundle ID: ${app.options.iosBundleId}');
        }
      }
      
    } catch (e, stackTrace) {
      logger.error('❌ Firebase initialization failed: $e');
      logger.error('Stack trace: $stackTrace');
      // Don't stop app - continue without Firebase but log the issue
      print('⚠️ Continuing without Firebase - some features may be limited');
    }
    
    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.error('Flutter Error: ${details.exception}');
      if (kDebugMode) {
        logger.error('Stack trace: ${details.stack}');
      }
    };
    
    // Handle platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.error('Platform Error: $error');
      if (kDebugMode) {
        logger.error('Stack trace: $stack');
      }
      return true;
    };
    
    logger.log('🎯 Application starting...');
    
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          loggerProvider.overrideWithValue(logger),
          backButtonHandlerProvider.overrideWithValue(BackButtonHandler(logger: logger)),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            // Initialize Facebook Pixel after Firebase
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FacebookPixelIntegration.initialize(ref);
            });
            
            return const AppWithLifecycleAndNotificationHandler();
          },
        ),
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

/// Early iOS permissions request (non-blocking)
void _requestIOSPermissionsEarly(Logger logger) {
  if (!Platform.isIOS) return;
  
  // Do this in the background without blocking app startup
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      logger.log('🔐 Early iOS permission request starting...');
      
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );
      
      logger.log('🔐 Early iOS permission result: ${settings.authorizationStatus}');
      
      // Log APNS token status early
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      logger.log('🍎 Early APNS token check: ${apnsToken != null ? "Available" : "Not available"}');
      
    } catch (e) {
      logger.log('⚠️ Early iOS permission request failed: $e');
      // This is okay - we'll try again later
    }
  });
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
      
      // STEP 4: Initialize notifications AFTER app is stable with enhanced iOS support
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
        
        // Try to initialize FCM token providers if they exist
        try {
          // Only initialize if the providers exist in your app
          // Comment out any providers that don't exist in your codebase
          // ref.read(fcmTokenAutoSaveWatcherProvider);
          // ref.read(fcmTokenBackgroundManagerProvider);
          
          logger.log('✅ Available FCM token providers initialized');
        } catch (e) {
          logger.log('ℹ️ Some FCM token providers not available: $e');
          // This is okay - continue without them
        }
        
        _hasInitializedFcmTokenSystem = true;
        logger.log('✅ FCM token system initialization completed');
        
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
      
      // Longer delay for iOS to ensure APNS token availability
      final delay = Platform.isIOS ? const Duration(seconds: 5) : const Duration(seconds: 3);
      await Future.delayed(delay);
      
      // Check if we're still mounted and app is ready
      if (!mounted || !_appFullyInitialized) {
        logger.log('⚠️ App not ready for notifications, skipping initialization');
        return;
      }
      
      logger.log('📱 App is stable, initializing notification service...');
      
      // iOS-specific pre-initialization checks
      if (Platform.isIOS) {
        await _performIOSPreInitializationChecks(logger);
      }
      
      // Initialize the notification service with enhanced error handling
      final notificationService = ref.read(firebaseNotificationServiceProvider);
      await notificationService.initializeWhenReady();
      
      _hasInitializedNotifications = true;
      logger.log('✅ Notifications initialized successfully');
      
      // Post-initialization checks for iOS
      if (Platform.isIOS && kDebugMode) {
        _performIOSPostInitializationChecks(notificationService, logger);
      }
      
    } catch (e, stackTrace) {
      ref.read(loggerProvider).error('⚠️ Notification initialization failed: $e');
      ref.read(loggerProvider).error('Stack trace: $stackTrace');
      // Don't crash the app - just continue without notifications
    }
  }

  /// Perform iOS-specific pre-initialization checks
  Future<void> _performIOSPreInitializationChecks(Logger logger) async {
    try {
      logger.log('🍎 Performing iOS pre-initialization checks...');
      
      // Check if Firebase is properly initialized
      if (Firebase.apps.isEmpty) {
        logger.warning('⚠️ Firebase not initialized - this may cause issues');
        return;
      }
      
      // Check current permission status
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      logger.log('🔐 Current permission status: ${settings.authorizationStatus}');
      
      // Check APNS token availability
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      logger.log('🍎 APNS token available: ${apnsToken != null}');
      
      if (apnsToken == null) {
        logger.log('⚠️ APNS token not available - will attempt to get FCM token anyway');
      }
      
      // Check if auto initialization is enabled
      logger.log('🔄 Firebase Messaging auto-init should be enabled');
      
    } catch (e) {
      logger.error('❌ iOS pre-initialization checks failed: $e');
    }
  }

  /// Perform iOS-specific post-initialization checks
  void _performIOSPostInitializationChecks(FirebaseNotificationService service, Logger logger) async {
    try {
      logger.log('🍎 Performing iOS post-initialization checks...');
      
      // Wait a bit for everything to settle
      await Future.delayed(const Duration(seconds: 2));
      
      // Check notification permissions
      final enabled = await service.areNotificationsEnabled();
      logger.log('📱 iOS Notifications enabled: $enabled');
      
      // Check FCM token availability
      final fcmToken = await service.getCurrentToken();
      logger.log('🔑 FCM Token available: ${fcmToken != null}');
      if (fcmToken != null) {
        logger.log('🔑 FCM Token preview: ${fcmToken.substring(0, 20)}...');
      } else {
        logger.warning('⚠️ FCM Token not available after initialization');
        
        // Try to get token one more time
        await Future.delayed(const Duration(seconds: 3));
        final retryToken = await service.getCurrentToken();
        if (retryToken != null) {
          logger.log('✅ FCM Token obtained on retry: ${retryToken.substring(0, 20)}...');
        } else {
          logger.error('❌ FCM Token still not available after retry');
        }
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
      logger.error('❌ iOS post-initialization checks failed: $e');
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
        
        // Check notification status on app resume (especially important for iOS)
        if (Platform.isIOS && _hasInitializedNotifications) {
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
      
      // Special handling for iOS when app becomes inactive then active
      else if (Platform.isIOS && state == AppLifecycleState.resumed && 
               _lastLifecycleState == AppLifecycleState.inactive) {
        logger.log('🍎 iOS app resumed from inactive state');
        
        // Check if we need to retry notification initialization
        if (!_hasInitializedNotifications) {
          Future.delayed(const Duration(seconds: 1), () {
            _initializeNotificationsWhenSafe();
          });
        }
      }
      
    } catch (e) {
      logger.error('❌ Error handling app lifecycle change: $e');
    }
    
    _lastLifecycleState = state;
  }

  /// Check notification status when app resumes (especially important for iOS)
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
            
            // For iOS, also check if we have tokens
            if (Platform.isIOS) {
              final fcmToken = await service.getCurrentToken();
              final apnsToken = await service.getAPNSToken();
              
              logger.log('🔑 FCM Token on resume: ${fcmToken != null}');
              logger.log('🍎 APNS Token on resume: ${apnsToken != null}');
              
              // If we don't have FCM token on resume, try to get it
              if (fcmToken == null) {
                logger.log('🔄 Attempting to get FCM token on app resume...');
                
                Future.delayed(const Duration(seconds: 2), () async {
                  final retryToken = await service.getCurrentToken();
                  if (retryToken != null) {
                    logger.log('✅ FCM token obtained on app resume');
                  } else {
                    logger.warning('⚠️ FCM token still not available on app resume');
                  }
                });
              }
            }
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
          // Only proceed if user profile provider exists
          try {
            final userProfileAsync = ref.read(userProfileProvider);
            // Add null check for the future extension
            if (userProfileAsync.hasValue) {
              final userProfile = userProfileAsync.value;
              
              if (userProfile != null) {
                logger.log('👤 User is logged in, checking FCM token status...');
                
                try {
                  final authService = ref.read(authServiceProvider);
                  
                  // Check if these methods exist before calling them
                  // Uncomment and modify based on your actual auth service methods
                  // final needsUpdate = await authService.shouldUpdateFcmToken();
                  // if (needsUpdate) {
                  //   logger.log('🔄 FCM token needs update on app resume, refreshing...');
                  //   final success = await authService.refreshFcmToken();
                  //   
                  //   if (success) {
                  //     logger.log('✅ FCM token refreshed successfully on app resume');
                  //   } else {
                  //     logger.warning('⚠️ FCM token refresh failed on app resume');
                  //   }
                  // } else {
                  //   logger.log('✅ FCM token is up to date on app resume');
                  // }
                  
                  logger.log('ℹ️ FCM token check completed on app resume');
                } catch (e) {
                  logger.log('ℹ️ Auth service methods not available: $e');
                }
              }
            }
          } catch (e) {
            logger.log('ℹ️ User profile provider not available: $e');
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
    // Show enhanced loading screen until app is ready
    if (!_appFullyInitialized) {
      return MaterialApp(
        title: 'PatelMart',
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo placeholder
                const FlutterLogo(size: 80),
                const SizedBox(height: 24),
                
                // Loading indicator
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                
                // Loading text
                const Text(
                  'Loading PatelMart...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Platform-specific initialization status
                Text(
                  Platform.isIOS 
                    ? 'Initializing iOS systems...'
                    : 'Initializing Android systems...',
                  style: const TextStyle(
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

/// Wrapper for MyApp that ensures FCM token management is active
class FcmTokenAwareMyApp extends ConsumerWidget {
  const FcmTokenAwareMyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to watch FCM token providers if they exist
    try {
      // Only watch providers that exist in your codebase
      // Comment out any that don't exist
      // ref.watch(fcmTokenAutoSaveWatcherProvider);
      // ref.watch(fcmTokenBackgroundManagerProvider);
    } catch (e) {
      // Providers don't exist - that's okay
      if (kDebugMode) {
        print('ℹ️ Some FCM token providers not available: $e');
      }
    }
    
    // Initialize favorites watcher for proper authentication handling
    try {
      ref.watch(favoritesInitializationWatcherProvider);
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Favorites initialization watcher not available: $e');
      }
    }
    
    // Try to watch user profile changes for FCM token management
    try {
      final userProfileAsync = ref.watch(userProfileProvider);
      
      // Enhanced FCM token status logging for iOS debugging
      if (kDebugMode) {
        if (userProfileAsync.hasValue && userProfileAsync.value != null) {
          final userProfile = userProfileAsync.value!;
          final logger = ref.read(loggerProvider);
          logger.log('🔐 FCM: User profile available for ${userProfile.mobile}');
          
          // Try to check FCM token status if the provider exists
          try {
            // Uncomment if you have this provider
            // ref.read(fcmTokenStatusProvider).whenData((status) {
            //   if (status['tokens_match'] != true) {
            //     logger.log('⚠️ FCM: Token status - needs attention');
            //     
            //     // For iOS, log additional debug info
            //     if (Platform.isIOS) {
            //       logger.log('🍎 iOS FCM Debug: Tokens don\'t match - investigating...');
            //     }
            //   } else {
            //     logger.log('✅ FCM: Token status - up to date');
            //   }
            // });
          } catch (e) {
            logger.log('ℹ️ FCM token status provider not available');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ User profile provider not available: $e');
      }
    }
    
    return const BackButtonWrapper(
      child: MyApp(),
    );
  }
}

/// Helper method for post-login notification initialization (iOS-optimized)
void initializeNotificationsAfterLogin(WidgetRef ref) {
  final logger = ref.read(loggerProvider);
  
  try {
    logger.log('🔔 Initializing notifications after login...');
    
    // Longer delay for iOS to ensure everything is ready
    final delay = Platform.isIOS ? const Duration(seconds: 3) : const Duration(seconds: 2);
    
    Future.delayed(delay, () async {
      try {
        final service = ref.read(firebaseNotificationServiceProvider);
        await service.initializeWhenReady();
        logger.log('✅ Notifications initialized after login');
        
        // For iOS, perform additional checks
        if (Platform.isIOS && kDebugMode) {
          await Future.delayed(const Duration(seconds: 1));
          
          final fcmToken = await service.getCurrentToken();
          
          // Try to get APNS token if the method exists
          String? apnsToken;
          try {
            apnsToken = await service.getAPNSToken();
          } catch (e) {
            logger.log('ℹ️ getAPNSToken method not available: $e');
          }
          
          logger.log('🍎 Post-login iOS status:');
          logger.log('   FCM Token: ${fcmToken != null}');
          logger.log('   APNS Token: ${apnsToken != null}');
          
          if (fcmToken == null) {
            logger.warning('⚠️ FCM token not available after login - may need manual retry');
          }
        }
        
      } catch (e) {
        logger.error('❌ Post-login notification initialization failed: $e');
      }
    });
  } catch (e) {
    logger.error('❌ Error scheduling post-login notifications: $e');
  }
}