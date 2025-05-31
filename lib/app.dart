// File: lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/services/firebase_notification_service.dart';
import 'package:patelmart/presentation/features/cart/widgets/cart_session_listener.dart';
import 'package:patelmart/presentation/providers/favorites_provider.dart';
import 'core/config/app_theme.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/providers/launch_flow_provider.dart';
import 'presentation/providers/auth_providers.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _appFullyInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize app components SAFELY with delays
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppSafely();
    });
  }

  Future<void> _initializeAppSafely() async {
    try {
      // STEP 1: Initialize critical app components first
      await _initializeAppLaunchFlow();
      _initializeAuthFavoritesWatcher();
      
      // Mark app as ready
      if (mounted) {
        setState(() {
          _appFullyInitialized = true;
        });
      }
      
      // STEP 2: Initialize notifications AFTER app is stable (non-blocking)
      _initializeNotificationsWhenSafe();
      
    } catch (e) {
      ref.read(loggerProvider).error('App initialization error: $e');
      // Don't crash - just mark as initialized without notifications
      if (mounted) {
        setState(() {
          _appFullyInitialized = true;
        });
      }
    }
  }

  Future<void> _initializeNotificationsWhenSafe() async {
    try {
      // Wait for app to be completely stable
      await Future.delayed(const Duration(seconds: 5));
      
      // Check if we're still mounted and app is ready
      if (!mounted || !_appFullyInitialized) return;
      
      final notificationService = ref.read(firebaseNotificationServiceProvider);
      await notificationService.initializeWhenReady();
      
      ref.read(loggerProvider).log('✅ Notifications initialized successfully');
    } catch (e) {
      ref.read(loggerProvider).error('⚠️ Notification initialization failed: $e');
      // Don't crash the app - just continue without notifications
    }
  }

  Future<void> _initializeAppLaunchFlow() async {
    try {
      final launchFlowNotifier = ref.read(launchFlowProvider.notifier);
      final launchState = ref.read(launchFlowProvider);
      
      // Handle different launch states
      if (launchState == AppLaunchState.firstLaunch) {
        ref.read(loggerProvider).log('First launch detected');
        return;
      }
      
      if (launchState == AppLaunchState.subsequentLaunch) {
        ref.read(loggerProvider).log('Subsequent launch - will fetch offers');
      } else if (launchState == AppLaunchState.needPincodeSelection || 
                 launchState == AppLaunchState.needLocationPermission) {
        ref.read(loggerProvider).log('Need location/pincode - will fetch when ready');
        await launchFlowNotifier.fetchLocationAndCheckPincode();
      }
    } catch (e) {
      ref.read(loggerProvider).error('Launch flow initialization error: $e');
      // Don't rethrow - let app continue
    }
  }
  
  void _initializeAuthFavoritesWatcher() {
    try {
      // Watch login status and manage favorites accordingly
      ref.listen<AsyncValue<bool>>(isLoggedInProvider, (previous, next) {
        next.whenData((isLoggedIn) {
          final favoritesState = ref.read(favoritesProvider);
          
          if (isLoggedIn && !favoritesState.isInitialized) {
            ref.read(loggerProvider).log('User logged in - initializing favorites');
            ref.read(favoritesProvider.notifier).initializeFavorites();
          } else if (!isLoggedIn && favoritesState.isInitialized) {
            ref.read(loggerProvider).log('User logged out - clearing favorites');
            ref.read(favoritesProvider.notifier).clearFavorites();
          }
        });
      });
    } catch (e) {
      ref.read(loggerProvider).error('Auth favorites watcher error: $e');
      // Don't rethrow - let app continue
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen until app is ready
    if (!_appFullyInitialized) {
      return MaterialApp(
        title: 'PatelMart',
        theme: AppTheme.theme,
        home: const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
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
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // App is ready - show the main app
    final router = ref.watch(routerProvider);
    
    return CartSessionListener(
      child: MaterialApp.router(
        title: 'PatelMart',
        theme: AppTheme.theme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    );
  }
}