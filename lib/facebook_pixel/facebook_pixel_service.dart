import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/branding/app_branding.dart';
import 'facebook_pixel_config.dart';

/// Facebook Pixel Service
/// Handles all Facebook Pixel tracking operations using platform channels
class FacebookPixelService {
  static FacebookPixelService? _instance;
  static FacebookPixelService get instance => _instance ??= FacebookPixelService._();
  
  FacebookPixelService._();
  
  static const MethodChannel _channel = MethodChannel('facebook_pixel');
  bool _isInitialized = false;
  bool _isEnabled = FacebookPixelConfig.enableTracking;
  
  /// Initialize Facebook SDK and Pixel
  Future<void> initialize() async {
    if (_isInitialized || !_isEnabled) return;
    
    try {
      // Initialize Facebook SDK via platform channel
      await _channel.invokeMethod('initialize', {
        'appId': FacebookPixelConfig.facebookAppId,
        'clientToken': FacebookPixelConfig.clientToken,
        'pixelId': FacebookPixelConfig.pixelId,
        'displayName': AppBranding.instance.appName,
        'enableAutoLogAppEvents': FacebookPixelConfig.enableAutoLogAppEvents,
        'enableAdvertiserIdCollection': FacebookPixelConfig.enableAdvertiserIdCollection,
        'enableCodelessEvents': FacebookPixelConfig.enableCodelessEvents,
        'enableDebugLogs': FacebookPixelConfig.debugMode,
      });
      
      _isInitialized = true;
      
      if (kDebugMode) {
        log('✅ Facebook Pixel initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ Facebook Pixel initialization failed: $e');
      }
    }
  }
  
  /// Track a custom event
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
    double? value,
    String? currency,
  }) async {
    if (!_isEnabled || !_isInitialized) return;
    
    try {
      final eventParams = <String, dynamic>{
        ...FacebookPixelConfig.standardParameters,
        ...?parameters,
      };
      
      if (value != null) {
        eventParams['value'] = value.toString();
      }
      
      if (currency != null) {
        eventParams['currency'] = currency;
      }
      
      await _channel.invokeMethod('logEvent', {
        'eventName': eventName,
        'parameters': eventParams,
        'value': value,
        'currency': currency,
      });
      
      if (kDebugMode) {
        log('📊 Facebook Pixel Event: $eventName');
        log('📊 Parameters: $eventParams');
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ Facebook Pixel event tracking failed: $e');
      }
    }
  }
  
  /// Track app launch event
  Future<void> trackAppLaunch() async {
    await trackEvent(
      FacebookPixelConfig.customEvents['app_launch']!,
      parameters: {
        'app_name': AppBranding.instance.appName,
        'platform': defaultTargetPlatform.toString(),
      },
    );
  }
  
  /// Track user login event
  Future<void> trackUserLogin({String? userId, String? method}) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['user_login']!,
      parameters: {
        'user_id': userId,
        'login_method': method ?? 'app',
      },
    );
  }
  
  /// Track user signup event
  Future<void> trackUserSignUp({String? userId, String? method}) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['user_signup']!,
      parameters: {
        'user_id': userId,
        'signup_method': method ?? 'app',
      },
    );
  }
  
  /// Track product view event
  Future<void> trackProductView({
    required String productId,
    required String productName,
    double? price,
    String? category,
  }) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['product_view']!,
      parameters: {
        'content_ids': productId,
        'content_name': productName,
        'content_category': category,
        'content_type': 'product',
      },
      value: price,
    );
  }
  
  /// Track add to cart event
  Future<void> trackAddToCart({
    required String productId,
    required String productName,
    required int quantity,
    double? price,
    String? category,
  }) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['add_to_cart']!,
      parameters: {
        'content_ids': productId,
        'content_name': productName,
        'content_category': category,
        'content_type': 'product',
        'num_items': quantity,
      },
      value: price != null ? price * quantity : null,
    );
  }
  
  /// Track initiate checkout event
  Future<void> trackInitiateCheckout({
    required List<String> productIds,
    double? totalValue,
    int? numItems,
  }) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['initiate_checkout']!,
      parameters: {
        'content_ids': productIds,
        'content_type': 'product',
        'num_items': numItems,
      },
      value: totalValue,
    );
  }
  
  /// Track purchase event
  Future<void> trackPurchase({
    required String orderId,
    required List<String> productIds,
    required double totalValue,
    String? currency,
    int? numItems,
  }) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['purchase']!,
      parameters: {
        'content_ids': productIds,
        'content_type': 'product',
        'num_items': numItems,
        'order_id': orderId,
      },
      value: totalValue,
      currency: currency ?? 'INR',
    );
  }
  
  /// Track search event
  Future<void> trackSearch({
    required String searchString,
    String? category,
  }) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['search']!,
      parameters: {
        'search_string': searchString,
        'content_category': category,
      },
    );
  }
  
  /// Track add to wishlist event
  Future<void> trackAddToWishlist({
    required String productId,
    required String productName,
    double? price,
    String? category,
  }) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['add_to_wishlist']!,
      parameters: {
        'content_ids': productId,
        'content_name': productName,
        'content_category': category,
        'content_type': 'product',
      },
      value: price,
    );
  }
  
  /// Track view category event
  Future<void> trackViewCategory({
    required String categoryName,
    String? categoryId,
  }) async {
    await trackEvent(
      FacebookPixelConfig.customEvents['view_category']!,
      parameters: {
        'content_category': categoryName,
        'content_ids': categoryId,
        'content_type': 'product_group',
      },
    );
  }
  
  /// Enable/Disable tracking
  void setTrackingEnabled(bool enabled) {
    _isEnabled = enabled;
  }
  
  /// Check if tracking is enabled
  bool get isTrackingEnabled => _isEnabled;
  
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Enable/Disable automatic app events logging
  Future<void> setAutoLogAppEventsEnabled(bool enabled) async {
    if (!_isInitialized) return;
    
    try {
      await _channel.invokeMethod('setAutoLogAppEventsEnabled', {
        'enabled': enabled,
      });
      
      if (kDebugMode) {
        log('📊 Auto Log App Events set to: $enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ Failed to set Auto Log App Events: $e');
      }
    }
  }
  
  /// Enable/Disable advertiser ID collection
  Future<void> setAdvertiserIDCollectionEnabled(bool enabled) async {
    if (!_isInitialized) return;
    
    try {
      await _channel.invokeMethod('setAdvertiserIDCollectionEnabled', {
        'enabled': enabled,
      });
      
      if (kDebugMode) {
        log('📊 Advertiser ID Collection set to: $enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ Failed to set Advertiser ID Collection: $e');
      }
    }
  }
  
  /// Enable/Disable advertiser tracking (iOS 14.5+)
  Future<void> setAdvertiserTrackingEnabled(bool enabled) async {
    if (!_isInitialized) return;
    
    try {
      await _channel.invokeMethod('setAdvertiserTrackingEnabled', {
        'enabled': enabled,
      });
      
      if (kDebugMode) {
        log('📊 Advertiser Tracking set to: $enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        log('❌ Failed to set Advertiser Tracking: $e');
      }
    }
  }
} 