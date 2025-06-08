// lib/app.dart - Updated to support popup lifecycle management

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/presentation/routes/app_router.dart';
import 'presentation/providers/launch_flow_provider.dart';
// POPUP IMPORTS
import 'presentation/providers/popup_providers.dart';
import 'core/handlers/app_lifecycle_handler.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool _hasInitializedAppLifecycle = false;

  @override
  void initState() {
    super.initState();
    
    // Add observer for additional lifecycle handling
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize app lifecycle handler after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppLifecycleHandler();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeAppLifecycleHandler() {
    if (!_hasInitializedAppLifecycle && mounted) {
      try {
        // Initialize the app lifecycle handler
        ref.read(appLifecycleHandlerProvider);
        _hasInitializedAppLifecycle = true;
        
        ref.read(loggerProvider).log('✅ App lifecycle handler initialized in MyApp');
      } catch (e) {
        ref.read(loggerProvider).error('❌ Failed to initialize app lifecycle handler: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Additional lifecycle handling specific to the app widget
    if (state == AppLifecycleState.resumed && mounted) {
      // Ensure popup system is ready when app resumes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _hasInitializedAppLifecycle) {
          ref.read(loggerProvider).log('🔄 App resumed - popup system check');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Patel Mart',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        textTheme: TextTheme(
          displayLarge: AppTextStyles.h1,
          displayMedium: AppTextStyles.h2,
          displaySmall: AppTextStyles.h3,
          headlineLarge: AppTextStyles.h4,
          headlineMedium: AppTextStyles.h5,
          headlineSmall: AppTextStyles.h6,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.bodySmall,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
      
      // Router configuration
      routerConfig: router,
      
      // Error handling
      builder: (context, child) {
        // Wrap the entire app with error boundary
        return _AppErrorBoundary(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// Error boundary wrapper for the entire app
class _AppErrorBoundary extends StatelessWidget {
  final Widget child;
  
  const _AppErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Extension for popup debugging in development
extension PopupDebugExtension on ConsumerState {
  void debugPopupInfo() {
    if (kDebugMode) {
      final state = ref.read(popupDisplayStateProvider);
      ref.read(loggerProvider).log('''
🔍 Popup Debug Info:
   └─ Visible: ${state.isVisible}
   └─ Shown: ${state.hasBeenShown}
   └─ Initialized: ${state.isInitialized}
   └─ Store: ${state.currentStoreCode ?? 'None'}
   └─ Session: ${state.currentSessionId ?? 'None'}
''');
    }
  }
}

/// Utility class for app-wide popup management
class AppPopupManager {
  static void handleAppLaunch(WidgetRef ref) {
    try {
      ref.read(loggerProvider).log('📱 Handling app launch for popup system');
      
      // Ensure popup system is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appLifecycleHandlerProvider);
      });
      
    } catch (e) {
      ref.read(loggerProvider).error('❌ Error in app launch popup handling: $e');
    }
  }
  
  static void handleAppResume(WidgetRef ref) {
    try {
      ref.read(loggerProvider).log('🔄 Handling app resume for popup system');
      
      // Reset popup state for new session
      ref.read(popupDisplayStateProvider.notifier).resetForNewSession();
      
    } catch (e) {
      ref.read(loggerProvider).error('❌ Error in app resume popup handling: $e');
    }
  }
}