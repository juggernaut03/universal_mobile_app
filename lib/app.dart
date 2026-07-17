// lib/app.dart - Simplified to avoid conflicts with main.dart lifecycle handling

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/presentation/routes/app_router.dart';
import 'data/repositories/project_config_repository.dart';
import 'presentation/providers/launch_flow_provider.dart';
// POPUP IMPORTS
import 'presentation/providers/popup_providers.dart';
import 'core/handlers/app_lifecycle_handler.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  // Remove WidgetsBindingObserver from here since main.dart handles it
  
  @override
  void initState() {
    super.initState();
    
    // Simple initialization - main.dart handles the complex lifecycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logAppReady();
    });
  }

  void _logAppReady() {
    try {
      ref.read(loggerProvider).log('✅ MyApp widget ready - UI can be rendered');
    } catch (e) {
      ref.read(loggerProvider).error('❌ MyApp initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Runtime branding from the tenant's project config; falls back to the
    // built-in brand while loading or when unset.
    final projectConfig = ref.watch(projectConfigProvider).valueOrNull;
    final brandPrimary = projectConfig?.primarySeedColor ?? AppColors.primary;
    final appTitle = projectConfig?.displayName ?? 'Patel Mart';

    return MaterialApp.router(
      title: appTitle,
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPrimary,
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
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandPrimary,
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
            borderSide: BorderSide(color: brandPrimary),
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