// lib/core/utils/back_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../utils/logger.dart';

class BackButtonHandler {
  final Logger _logger;
  DateTime? _lastBackPressTime;
  
  BackButtonHandler({Logger? logger}) : _logger = logger ?? Logger();
  
  /// Handles back button press with a callback for custom logic
  /// Returns true if the back press was handled, false otherwise
  Future<bool> handleBackPress(
    BuildContext context, {
    String? customExitMessage,
    String? alternateRoute,
    Duration exitConfirmTime = const Duration(seconds: 2),
  }) async {
    // If we have an alternate route, navigate to it instead of showing exit confirmation
    if (alternateRoute != null) {
      _logger.log('Navigating to alternate route: $alternateRoute');
      context.go(alternateRoute);
      return true;
    }
    
    // If this is the root route and we should show exit confirmation
    // Get the current time
    final now = DateTime.now();
    
    // If this is the first back press or the elapsed time is greater than exitConfirmTime
    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > exitConfirmTime) {
      // Update last back press time
      _lastBackPressTime = now;
      
      // Show a toast message
      final message = customExitMessage ?? 'Press back again to exit';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: exitConfirmTime,
        ),
      );
      
      _logger.log('First back press, showing exit confirmation');
      return true;
    }
    
    // This is the second back press within the time window, so exit the app
    _logger.log('Second back press, exiting app');
    await SystemNavigator.pop();
    return true;
  }
}