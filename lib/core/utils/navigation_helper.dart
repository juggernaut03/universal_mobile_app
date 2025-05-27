// lib/core/utils/navigation_helper.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationHelper {
  /// Navigate to login with redirect route
  static void navigateToLogin(BuildContext context, String redirectRoute) {
    context.go('/auth/login?redirectRoute=$redirectRoute');
  }

  /// Check if current route requires authentication and redirect if needed
  static Future<bool> requiresAuthentication(
    BuildContext context, 
    String route,
    Future<bool> Function() isLoggedInCheck,
  ) async {
    final requiresAuth = _routesRequiringAuth.contains(route);
    if (!requiresAuth) return false;
    
    final isLoggedIn = await isLoggedInCheck();
    if (!isLoggedIn) {
      navigateToLogin(context, route);
      return true;
    }
    return false;
  }

  /// List of routes that require authentication
  static const List<String> _routesRequiringAuth = [
    '/favorites',
    '/account',
    '/my-orders',
    '/profile',
    '/address-book',
    '/checkout-flow',
    '/savings',
    '/reorder',
  ];

  /// Get user-friendly name for routes
  static String getRouteDisplayName(String route) {
    switch (route) {
      case '/cart':
        return 'Cart';
      case '/favorites':
        return 'Favorites';
      case '/account':
        return 'Account';
      case '/my-orders':
        return 'My Orders';
      case '/profile':
        return 'Profile';
      case '/address-book':
        return 'Address Book';
      case '/checkout-flow':
        return 'Checkout';
      case '/savings':
        return 'Savings';
      case '/reorder':
        return 'Reorder';
      default:
        return 'Previous Screen';
    }
  }

  /// Navigate with authentication check
  static Future<void> navigateWithAuthCheck(
    BuildContext context,
    String route,
    Future<bool> Function() isLoggedInCheck,
  ) async {
    final requiresRedirect = await requiresAuthentication(context, route, isLoggedInCheck);
    if (!requiresRedirect) {
      context.go(route);
    }
  }
}