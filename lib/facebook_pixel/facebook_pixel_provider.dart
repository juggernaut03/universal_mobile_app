import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'facebook_pixel_service.dart';

/// Facebook Pixel Provider
/// Provides Facebook Pixel service throughout the app
final facebookPixelProvider = Provider<FacebookPixelService>((ref) {
  return FacebookPixelService.instance;
});

/// Facebook Pixel Initialization Provider
/// Handles initialization of Facebook Pixel
final facebookPixelInitializationProvider = FutureProvider<void>((ref) async {
  final facebookPixel = ref.read(facebookPixelProvider);
  await facebookPixel.initialize();
});

/// Facebook Pixel Tracking Provider
/// Provides methods for tracking events
final facebookPixelTrackingProvider = Provider<FacebookPixelTracking>((ref) {
  final facebookPixel = ref.read(facebookPixelProvider);
  return FacebookPixelTracking(facebookPixel);
});

/// Facebook Pixel Tracking Class
/// Provides convenient methods for tracking common events
class FacebookPixelTracking {
  final FacebookPixelService _service;
  
  FacebookPixelTracking(this._service);
  
  /// Track app launch
  Future<void> trackAppLaunch() async {
    await _service.trackAppLaunch();
  }
  
  /// Track user login
  Future<void> trackUserLogin({String? userId, String? method}) async {
    await _service.trackUserLogin(userId: userId, method: method);
  }
  
  /// Track user signup
  Future<void> trackUserSignUp({String? userId, String? method}) async {
    await _service.trackUserSignUp(userId: userId, method: method);
  }
  
  /// Track product view
  Future<void> trackProductView({
    required String productId,
    required String productName,
    double? price,
    String? category,
  }) async {
    await _service.trackProductView(
      productId: productId,
      productName: productName,
      price: price,
      category: category,
    );
  }
  
  /// Track add to cart
  Future<void> trackAddToCart({
    required String productId,
    required String productName,
    required int quantity,
    double? price,
    String? category,
  }) async {
    await _service.trackAddToCart(
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      category: category,
    );
  }
  
  /// Track initiate checkout
  Future<void> trackInitiateCheckout({
    required List<String> productIds,
    double? totalValue,
    int? numItems,
  }) async {
    await _service.trackInitiateCheckout(
      productIds: productIds,
      totalValue: totalValue,
      numItems: numItems,
    );
  }
  
  /// Track purchase
  Future<void> trackPurchase({
    required String orderId,
    required List<String> productIds,
    required double totalValue,
    String? currency,
    int? numItems,
  }) async {
    await _service.trackPurchase(
      orderId: orderId,
      productIds: productIds,
      totalValue: totalValue,
      currency: currency,
      numItems: numItems,
    );
  }
  
  /// Track search
  Future<void> trackSearch({
    required String searchString,
    String? category,
  }) async {
    await _service.trackSearch(
      searchString: searchString,
      category: category,
    );
  }
  
  /// Track add to wishlist
  Future<void> trackAddToWishlist({
    required String productId,
    required String productName,
    double? price,
    String? category,
  }) async {
    await _service.trackAddToWishlist(
      productId: productId,
      productName: productName,
      price: price,
      category: category,
    );
  }
  
  /// Track view category
  Future<void> trackViewCategory({
    required String categoryName,
    String? categoryId,
  }) async {
    await _service.trackViewCategory(
      categoryName: categoryName,
      categoryId: categoryId,
    );
  }
  
  /// Track custom event
  Future<void> trackCustomEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
    double? value,
    String? currency,
  }) async {
    await _service.trackEvent(
      eventName,
      parameters: parameters,
      value: value,
      currency: currency,
    );
  }
} 