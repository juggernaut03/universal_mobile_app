import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'facebook_pixel_provider.dart';

/// Facebook Pixel Integration
/// Provides easy integration methods for Facebook Pixel tracking
class FacebookPixelIntegration {
  /// Initialize Facebook Pixel in the app
  /// Call this in main.dart after Firebase initialization
  static Future<void> initialize(WidgetRef ref) async {
    try {
      // Initialize Facebook Pixel
      await ref.read(facebookPixelInitializationProvider.future);
      
      // Track app launch event
      final tracking = ref.read(facebookPixelTrackingProvider);
      await tracking.trackAppLaunch();
      
      print('✅ Facebook Pixel initialized and app launch tracked');
    } catch (e) {
      print('❌ Facebook Pixel initialization failed: $e');
    }
  }
  
  /// Track user authentication events
  static Future<void> trackUserAuth(WidgetRef ref, {
    required String eventType, // 'login' or 'signup'
    String? userId,
    String? method,
  }) async {
    try {
      final tracking = ref.read(facebookPixelTrackingProvider);
      
      switch (eventType.toLowerCase()) {
        case 'login':
          await tracking.trackUserLogin(userId: userId, method: method);
          break;
        case 'signup':
          await tracking.trackUserSignUp(userId: userId, method: method);
          break;
        default:
          print('⚠️ Unknown auth event type: $eventType');
      }
    } catch (e) {
      print('❌ Failed to track auth event: $e');
    }
  }
  
  /// Track product-related events
  static Future<void> trackProductEvent(WidgetRef ref, {
    required String eventType, // 'view', 'add_to_cart', 'add_to_wishlist'
    required String productId,
    required String productName,
    double? price,
    String? category,
    int? quantity,
  }) async {
    try {
      final tracking = ref.read(facebookPixelTrackingProvider);
      
      switch (eventType.toLowerCase()) {
        case 'view':
          await tracking.trackProductView(
            productId: productId,
            productName: productName,
            price: price,
            category: category,
          );
          break;
        case 'add_to_cart':
          await tracking.trackAddToCart(
            productId: productId,
            productName: productName,
            quantity: quantity ?? 1,
            price: price,
            category: category,
          );
          break;
        case 'add_to_wishlist':
          await tracking.trackAddToWishlist(
            productId: productId,
            productName: productName,
            price: price,
            category: category,
          );
          break;
        default:
          print('⚠️ Unknown product event type: $eventType');
      }
    } catch (e) {
      print('❌ Failed to track product event: $e');
    }
  }
  
  /// Track checkout events
  static Future<void> trackCheckoutEvent(WidgetRef ref, {
    required String eventType, // 'initiate', 'purchase'
    required List<String> productIds,
    double? totalValue,
    int? numItems,
    String? orderId,
    String? currency,
  }) async {
    try {
      final tracking = ref.read(facebookPixelTrackingProvider);
      
      switch (eventType.toLowerCase()) {
        case 'initiate':
          await tracking.trackInitiateCheckout(
            productIds: productIds,
            totalValue: totalValue,
            numItems: numItems,
          );
          break;
        case 'purchase':
          if (orderId != null && totalValue != null) {
            await tracking.trackPurchase(
              orderId: orderId,
              productIds: productIds,
              totalValue: totalValue,
              currency: currency,
              numItems: numItems,
            );
          } else {
            print('⚠️ Order ID and total value required for purchase tracking');
          }
          break;
        default:
          print('⚠️ Unknown checkout event type: $eventType');
      }
    } catch (e) {
      print('❌ Failed to track checkout event: $e');
    }
  }
  
  /// Track category and search events
  static Future<void> trackDiscoveryEvent(WidgetRef ref, {
    required String eventType, // 'category_view', 'search'
    required String name,
    String? id,
    String? category,
  }) async {
    try {
      final tracking = ref.read(facebookPixelTrackingProvider);
      
      switch (eventType.toLowerCase()) {
        case 'category_view':
          await tracking.trackViewCategory(
            categoryName: name,
            categoryId: id,
          );
          break;
        case 'search':
          await tracking.trackSearch(
            searchString: name,
            category: category,
          );
          break;
        default:
          print('⚠️ Unknown discovery event type: $eventType');
      }
    } catch (e) {
      print('❌ Failed to track discovery event: $e');
    }
  }
  
  /// Track custom events
  static Future<void> trackCustomEvent(WidgetRef ref, {
    required String eventName,
    Map<String, dynamic>? parameters,
    double? value,
    String? currency,
  }) async {
    try {
      final tracking = ref.read(facebookPixelTrackingProvider);
      await tracking.trackCustomEvent(
        eventName,
        parameters: parameters,
        value: value,
        currency: currency,
      );
    } catch (e) {
      print('❌ Failed to track custom event: $e');
    }
  }
} 