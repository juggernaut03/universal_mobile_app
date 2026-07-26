// lib/presentation/widgets/cart_session_listener.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import '../../../../di/infrastructure_providers.dart';


/// A widget that listens for app activity and refreshes the cart session
/// to prevent it from expiring while the app is in use.
class CartSessionListener extends ConsumerStatefulWidget {
  final Widget child;

  const CartSessionListener({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<CartSessionListener> createState() => _CartSessionListenerState();
}

class _CartSessionListenerState extends ConsumerState<CartSessionListener> with WidgetsBindingObserver {
  Timer? _sessionRefreshTimer;
  static const _refreshInterval = Duration(hours: 4); // Refresh every 4 hours
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Start timer to periodically refresh cart session
    _startSessionRefreshTimer();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionRefreshTimer?.cancel();
    super.dispose();
  }
  
  // Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshCartSession();
      _startSessionRefreshTimer();
    } 
    // When app goes to background
    else if (state == AppLifecycleState.paused) {
      _sessionRefreshTimer?.cancel();
    }
  }
  
  // Start timer to periodically refresh cart session
  void _startSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshCartSession();
    });
  }
  
  // Refresh the cart session to extend its expiration
  void _refreshCartSession() {
    final cartNotifier = ref.read(cartProvider.notifier);
    final logger = ref.read(loggerProvider);
    
    // Only refresh if there are items in the cart
    if (ref.read(cartProvider).isNotEmpty) {
      cartNotifier.refreshSession().then((success) {
        if (success) {
          logger.log('Cart session refreshed successfully');
        } else {
          logger.error('Failed to refresh cart session');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pass-through the child
    return widget.child;
  }
}