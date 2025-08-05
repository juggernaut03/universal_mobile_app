import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'facebook_pixel_integration.dart';

/// Usage Examples for Facebook Pixel Integration
/// This file shows how to integrate Facebook Pixel tracking into existing app screens
class FacebookPixelUsageExamples {
  
  /// Example: Track product view when user opens a product page
  static Future<void> trackProductViewExample(WidgetRef ref, {
    required String productId,
    required String productName,
    double? price,
    String? category,
  }) async {
    await FacebookPixelIntegration.trackProductEvent(
      ref,
      eventType: 'view',
      productId: productId,
      productName: productName,
      price: price,
      category: category,
    );
  }
  
  /// Example: Track add to cart when user adds product to cart
  static Future<void> trackAddToCartExample(WidgetRef ref, {
    required String productId,
    required String productName,
    required int quantity,
    double? price,
    String? category,
  }) async {
    await FacebookPixelIntegration.trackProductEvent(
      ref,
      eventType: 'add_to_cart',
      productId: productId,
      productName: productName,
      price: price,
      category: category,
      quantity: quantity,
    );
  }
  
  /// Example: Track category view when user browses a category
  static Future<void> trackCategoryViewExample(WidgetRef ref, {
    required String categoryName,
    String? categoryId,
  }) async {
    await FacebookPixelIntegration.trackDiscoveryEvent(
      ref,
      eventType: 'category_view',
      name: categoryName,
      id: categoryId,
    );
  }
  
  /// Example: Track search when user searches for products
  static Future<void> trackSearchExample(WidgetRef ref, {
    required String searchQuery,
    String? category,
  }) async {
    await FacebookPixelIntegration.trackDiscoveryEvent(
      ref,
      eventType: 'search',
      name: searchQuery,
      category: category,
    );
  }
  
  /// Example: Track checkout initiation when user starts checkout
  static Future<void> trackCheckoutInitiationExample(WidgetRef ref, {
    required List<String> productIds,
    double? totalValue,
    int? numItems,
  }) async {
    await FacebookPixelIntegration.trackCheckoutEvent(
      ref,
      eventType: 'initiate',
      productIds: productIds,
      totalValue: totalValue,
      numItems: numItems,
    );
  }
  
  /// Example: Track purchase when order is completed
  static Future<void> trackPurchaseExample(WidgetRef ref, {
    required String orderId,
    required List<String> productIds,
    required double totalValue,
    int? numItems,
    String? currency,
  }) async {
    await FacebookPixelIntegration.trackCheckoutEvent(
      ref,
      eventType: 'purchase',
      productIds: productIds,
      totalValue: totalValue,
      numItems: numItems,
      orderId: orderId,
      currency: currency,
    );
  }
  
  /// Example: Track user login
  static Future<void> trackUserLoginExample(WidgetRef ref, {
    String? userId,
    String? method,
  }) async {
    await FacebookPixelIntegration.trackUserAuth(
      ref,
      eventType: 'login',
      userId: userId,
      method: method,
    );
  }
  
  /// Example: Track user signup
  static Future<void> trackUserSignupExample(WidgetRef ref, {
    String? userId,
    String? method,
  }) async {
    await FacebookPixelIntegration.trackUserAuth(
      ref,
      eventType: 'signup',
      userId: userId,
      method: method,
    );
  }
  
  /// Example: Track custom app-specific events
  static Future<void> trackCustomEventExample(WidgetRef ref, {
    required String eventName,
    Map<String, dynamic>? parameters,
    double? value,
    String? currency,
  }) async {
    await FacebookPixelIntegration.trackCustomEvent(
      ref,
      eventName: eventName,
      parameters: parameters,
      value: value,
      currency: currency,
    );
  }
}

/// Integration Examples for Existing App Screens
/// These examples show how to integrate Facebook Pixel into specific app screens
class AppScreenIntegrationExamples {
  
  /// Example: Integrate with Product Detail Screen
  /// Add this to your product detail screen's initState or onTap
  static Future<void> onProductView(WidgetRef ref, {
    required String productId,
    required String productName,
    double? price,
    String? category,
  }) async {
    await FacebookPixelUsageExamples.trackProductViewExample(
      ref,
      productId: productId,
      productName: productName,
      price: price,
      category: category,
    );
  }
  
  /// Example: Integrate with Add to Cart Button
  /// Add this to your add to cart button's onPressed
  static Future<void> onAddToCart(WidgetRef ref, {
    required String productId,
    required String productName,
    required int quantity,
    double? price,
    String? category,
  }) async {
    await FacebookPixelUsageExamples.trackAddToCartExample(
      ref,
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      category: category,
    );
  }
  
  /// Example: Integrate with Category Screen
  /// Add this to your category screen's initState
  static Future<void> onCategoryView(WidgetRef ref, {
    required String categoryName,
    String? categoryId,
  }) async {
    await FacebookPixelUsageExamples.trackCategoryViewExample(
      ref,
      categoryName: categoryName,
      categoryId: categoryId,
    );
  }
  
  /// Example: Integrate with Search Screen
  /// Add this to your search screen's search function
  static Future<void> onSearch(WidgetRef ref, {
    required String searchQuery,
    String? category,
  }) async {
    await FacebookPixelUsageExamples.trackSearchExample(
      ref,
      searchQuery: searchQuery,
      category: category,
    );
  }
  
  /// Example: Integrate with Checkout Screen
  /// Add this to your checkout screen's initState
  static Future<void> onCheckoutInitiation(WidgetRef ref, {
    required List<String> productIds,
    double? totalValue,
    int? numItems,
  }) async {
    await FacebookPixelUsageExamples.trackCheckoutInitiationExample(
      ref,
      productIds: productIds,
      totalValue: totalValue,
      numItems: numItems,
    );
  }
  
  /// Example: Integrate with Order Confirmation
  /// Add this to your order confirmation screen
  static Future<void> onPurchaseComplete(WidgetRef ref, {
    required String orderId,
    required List<String> productIds,
    required double totalValue,
    int? numItems,
    String? currency,
  }) async {
    await FacebookPixelUsageExamples.trackPurchaseExample(
      ref,
      orderId: orderId,
      productIds: productIds,
      totalValue: totalValue,
      numItems: numItems,
      currency: currency,
    );
  }
  
  /// Example: Integrate with Login Screen
  /// Add this to your login screen's success callback
  static Future<void> onUserLogin(WidgetRef ref, {
    String? userId,
    String? method,
  }) async {
    await FacebookPixelUsageExamples.trackUserLoginExample(
      ref,
      userId: userId,
      method: method,
    );
  }
  
  /// Example: Integrate with Signup Screen
  /// Add this to your signup screen's success callback
  static Future<void> onUserSignup(WidgetRef ref, {
    String? userId,
    String? method,
  }) async {
    await FacebookPixelUsageExamples.trackUserSignupExample(
      ref,
      userId: userId,
      method: method,
    );
  }
} 