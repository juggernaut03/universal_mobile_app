// lib/core/handlers/app_lifecycle_handler.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/popup_providers.dart';
import '../providers/loyalty_provider.dart';
import '../../di/infrastructure_providers.dart';
import 'package:flutter/foundation.dart';

/// Handles app lifecycle events to manage popup behavior
/// This ensures popup shows on every app launch/resume
class AppLifecycleHandler extends WidgetsBindingObserver {
  final Ref _ref;
  AppLifecycleState? _lastLifecycleState;

  AppLifecycleHandler(this._ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    try {
      final logger = _ref.read(loggerProvider);
      logger.log('AppLifecycleHandler: State changed to ${state.name}');
      
      // Check if app is coming from background/paused to foreground
      if (_lastLifecycleState == AppLifecycleState.paused && 
          state == AppLifecycleState.resumed) {
        
        logger.log('App resumed from background - resetting popup state');

        // Reset popup state for new session when app comes to foreground
        _ref.read(popupDisplayStateProvider.notifier).resetForNewSession();

        // Loyalty points/tier/challenges can change from something that
        // happened entirely server-side while this app was backgrounded
        // (an order this account referred finally got delivered, a reward
        // expired, an admin adjustment) - there's no realtime push wired to
        // every one of those, so the dashboard was showing whatever it last
        // fetched, sometimes stale by however long the app sat backgrounded.
        // Refreshing on resume, not just on in-app actions, keeps the
        // balance honest whenever the shopper is actually looking at it.
        _ref.read(loyaltyRefreshProvider.notifier).state++;
      }
      
      _lastLifecycleState = state;
    } catch (e) {
      // Handle any errors gracefully
      if (kDebugMode) print('Error in AppLifecycleHandler: $e');
    }
  }

  /// Initialize the lifecycle observer
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Clean up the lifecycle observer
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Provider for app lifecycle handler - Fixed to use Ref instead of WidgetRef
final appLifecycleHandlerProvider = Provider<AppLifecycleHandler>((ref) {
  final handler = AppLifecycleHandler(ref);
  handler.initialize();
  
  // Dispose when provider is disposed
  ref.onDispose(() {
    handler.dispose();
  });
  
  return handler;
});