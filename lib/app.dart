// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_theme.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/providers/launch_flow_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'PatelMart',
      theme: AppTheme.theme, // Use single light theme
      themeMode: ThemeMode.light, // Force light mode always
      debugShowCheckedModeBanner: false, // Remove debug banner
      routerConfig: router,
    );
  }
}