// File: lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  void initState() {
    super.initState();
    
    // Start the app initialization process after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppLaunchFlow();
      _initializeAuthFavoritesWatcher();
    });
  }
  
  Future<void> _initializeAppLaunchFlow() async {
    // Get the launch flow notifier
    final launchFlowNotifier = ref.read(launchFlowProvider.notifier);
    
    // Get the current launch state
    final launchState = ref.read(launchFlowProvider);
    
    // If this is a first-time launch, we'll handle it after onboarding completes
    if (launchState == AppLaunchState.firstLaunch) {
      return;
    }
    
    // If we need to get the user's location, do it now
    if (launchState == AppLaunchState.subsequentLaunch) {
      // For subsequent launches, we'll fetch offers based on cached outlet
      // but this is handled by the router automatically
    } else if (launchState == AppLaunchState.needPincodeSelection || 
               launchState == AppLaunchState.needLocationPermission) {
      // Try to fetch location and check pincode
      await launchFlowNotifier.fetchLocationAndCheckPincode();
    }
  }
  
  void _initializeAuthFavoritesWatcher() {
    // Watch login status and manage favorites accordingly
    ref.listen<AsyncValue<bool>>(isLoggedInProvider, (previous, next) {
      next.whenData((isLoggedIn) {
        final favoritesState = ref.read(favoritesProvider);
        
        if (isLoggedIn && !favoritesState.isInitialized) {
          // User just logged in - favorites will auto-initialize
          ref.read(loggerProvider).log('User logged in - favorites will initialize');
          ref.read(favoritesProvider.notifier).initializeFavorites();
        } else if (!isLoggedIn && favoritesState.isInitialized) {
          // User logged out - clear favorites
          ref.read(favoritesProvider.notifier).clearFavorites();
          ref.read(loggerProvider).log('User logged out - favorites cleared');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    
    // Wrap the app with CartSessionListener to maintain cart session
    return CartSessionListener(
      child: MaterialApp.router(
        title: 'PatelMart',
        theme: AppTheme.theme, // Use single light theme
        themeMode: ThemeMode.light, // Force light mode always
        debugShowCheckedModeBanner: false, // Remove debug banner
        routerConfig: router,
        // Remove navigatorKey from here - it should be in GoRouter
      ),
    );
  }
}