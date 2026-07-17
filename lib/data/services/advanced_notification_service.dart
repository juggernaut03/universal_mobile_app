// lib/data/services/advanced_notification_service.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../presentation/providers/cart_provider.dart';
import '../../presentation/providers/auth_providers.dart';
import '../models/product_model.dart';

// Provider for the advanced notification service
final advancedNotificationServiceProvider = Provider<AdvancedNotificationService>((ref) {
  return AdvancedNotificationService(ref: ref);
});

// Notification types enum
enum NotificationType {
  productRestocked,
  productPriceDrop,
  categoryUpdate,
  cartAbandonment,
  flashSale,
  personalized,
  orderUpdate,
}

// Notification preference model
class NotificationPreferences {
  final bool productRestocked;
  final bool priceDrops;
  final bool categoryUpdates;
  final bool cartReminders;
  final bool flashSales;
  final bool personalizedOffers;
  final bool orderUpdates;
  final List<String> subscribedCategories;
  final List<String> wishlistedProducts;

  NotificationPreferences({
    this.productRestocked = true,
    this.priceDrops = true,
    this.categoryUpdates = true,
    this.cartReminders = true,
    this.flashSales = true,
    this.personalizedOffers = true,
    this.orderUpdates = true,
    this.subscribedCategories = const [],
    this.wishlistedProducts = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'productRestocked': productRestocked,
      'priceDrops': priceDrops,
      'categoryUpdates': categoryUpdates,
      'cartReminders': cartReminders,
      'flashSales': flashSales,
      'personalizedOffers': personalizedOffers,
      'orderUpdates': orderUpdates,
      'subscribedCategories': subscribedCategories,
      'wishlistedProducts': wishlistedProducts,
    };
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      productRestocked: json['productRestocked'] ?? true,
      priceDrops: json['priceDrops'] ?? true,
      categoryUpdates: json['categoryUpdates'] ?? true,
      cartReminders: json['cartReminders'] ?? true,
      flashSales: json['flashSales'] ?? true,
      personalizedOffers: json['personalizedOffers'] ?? true,
      orderUpdates: json['orderUpdates'] ?? true,
      subscribedCategories: List<String>.from(json['subscribedCategories'] ?? []),
      wishlistedProducts: List<String>.from(json['wishlistedProducts'] ?? []),
    );
  }

  NotificationPreferences copyWith({
    bool? productRestocked,
    bool? priceDrops,
    bool? categoryUpdates,
    bool? cartReminders,
    bool? flashSales,
    bool? personalizedOffers,
    bool? orderUpdates,
    List<String>? subscribedCategories,
    List<String>? wishlistedProducts,
  }) {
    return NotificationPreferences(
      productRestocked: productRestocked ?? this.productRestocked,
      priceDrops: priceDrops ?? this.priceDrops,
      categoryUpdates: categoryUpdates ?? this.categoryUpdates,
      cartReminders: cartReminders ?? this.cartReminders,
      flashSales: flashSales ?? this.flashSales,
      personalizedOffers: personalizedOffers ?? this.personalizedOffers,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      subscribedCategories: subscribedCategories ?? this.subscribedCategories,
      wishlistedProducts: wishlistedProducts ?? this.wishlistedProducts,
    );
  }
}

class AdvancedNotificationService {
  final Ref _ref;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final http.Client _client = http.Client();
  
  static const String _preferencesKey = 'notification_preferences';
  static const String _cartAbandonmentTimerKey = 'cart_abandonment_timer';
  static const String _lastCartUpdateKey = 'last_cart_update';

  AdvancedNotificationService({required Ref ref}) : _ref = ref;

  Logger get _logger => _ref.read(loggerProvider);

  /// Initialize advanced notification features
  Future<void> initialize() async {
    try {
      _logger.log('Initializing advanced notification service');
      
      // Load user preferences
      await _loadNotificationPreferences();
      
      // Setup cart abandonment tracking
      _setupCartAbandonmentTracking();
      
      // Subscribe to relevant topics based on user preferences
      await _subscribeToTopics();
      
      // Send user profile to server for personalized notifications
      await _syncUserProfileWithServer();
      
      _logger.log('Advanced notification service initialized successfully');
    } catch (e) {
      _logger.error('Error initializing advanced notification service: $e');
    }
  }

  /// Subscribe to specific product notifications
  Future<void> subscribeToProduct(String productCode) async {
    try {
      await _firebaseMessaging.subscribeToTopic('product_$productCode');
      
      // Update local preferences
      final prefs = await _getNotificationPreferences();
      final updatedWishlist = [...prefs.wishlistedProducts];
      if (!updatedWishlist.contains(productCode)) {
        updatedWishlist.add(productCode);
      }
      
      await _saveNotificationPreferences(
        prefs.copyWith(wishlistedProducts: updatedWishlist)
      );
      
      // Sync with server
      await _syncProductSubscriptionWithServer(productCode, subscribe: true);
      
      _logger.log('Subscribed to product notifications: $productCode');
    } catch (e) {
      _logger.error('Error subscribing to product $productCode: $e');
    }
  }

  /// Unsubscribe from specific product notifications
  Future<void> unsubscribeFromProduct(String productCode) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('product_$productCode');
      
      // Update local preferences
      final prefs = await _getNotificationPreferences();
      final updatedWishlist = prefs.wishlistedProducts
          .where((code) => code != productCode)
          .toList();
      
      await _saveNotificationPreferences(
        prefs.copyWith(wishlistedProducts: updatedWishlist)
      );
      
      // Sync with server
      await _syncProductSubscriptionWithServer(productCode, subscribe: false);
      
      _logger.log('Unsubscribed from product notifications: $productCode');
    } catch (e) {
      _logger.error('Error unsubscribing from product $productCode: $e');
    }
  }

  /// Subscribe to category notifications
  Future<void> subscribeToCategory(String categoryId) async {
    try {
      await _firebaseMessaging.subscribeToTopic('category_$categoryId');
      
      // Update local preferences
      final prefs = await _getNotificationPreferences();
      final updatedCategories = [...prefs.subscribedCategories];
      if (!updatedCategories.contains(categoryId)) {
        updatedCategories.add(categoryId);
      }
      
      await _saveNotificationPreferences(
        prefs.copyWith(subscribedCategories: updatedCategories)
      );
      
      _logger.log('Subscribed to category notifications: $categoryId');
    } catch (e) {
      _logger.error('Error subscribing to category $categoryId: $e');
    }
  }

  /// Unsubscribe from category notifications
  Future<void> unsubscribeFromCategory(String categoryId) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('category_$categoryId');
      
      // Update local preferences
      final prefs = await _getNotificationPreferences();
      final updatedCategories = prefs.subscribedCategories
          .where((id) => id != categoryId)
          .toList();
      
      await _saveNotificationPreferences(
        prefs.copyWith(subscribedCategories: updatedCategories)
      );
      
      _logger.log('Unsubscribed from category notifications: $categoryId');
    } catch (e) {
      _logger.error('Error unsubscribing from category $categoryId: $e');
    }
  }

  /// Track cart abandonment
  void _setupCartAbandonmentTracking() {
    // Listen to cart changes
    _ref.listen<List<CartItem>>(cartProvider, (previous, next) {
      _handleCartChange(previous, next);
    });
  }

  /// Handle cart changes for abandonment tracking
  Future<void> _handleCartChange(List<CartItem>? previous, List<CartItem> current) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      if (current.isNotEmpty) {
        // Cart has items - update last activity
        await prefs.setString(_lastCartUpdateKey, now.toIso8601String());
        
        // Cancel any existing abandonment timer
        await prefs.remove(_cartAbandonmentTimerKey);
        
        // Schedule abandonment notification for 1 hour later
        final reminderTime = now.add(const Duration(hours: 1));
        await prefs.setString(_cartAbandonmentTimerKey, reminderTime.toIso8601String());
        
        // Also schedule for 24 hours later
        _scheduleCartAbandonmentReminder(current);
      } else {
        // Cart is empty - clear timers
        await prefs.remove(_cartAbandonmentTimerKey);
        await prefs.remove(_lastCartUpdateKey);
      }
    } catch (e) {
      _logger.error('Error handling cart change: $e');
    }
  }

  /// Schedule cart abandonment reminder
  Future<void> _scheduleCartAbandonmentReminder(List<CartItem> cartItems) async {
    try {
      final userProfile = await _ref.read(authRepositoryProvider).getUserProfile();
      if (userProfile == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      // Prepare cart data for the reminder
      final cartData = cartItems.map((item) => {
        'productId': item.product.pCode,
        'productName': item.product.productName,
        'quantity': item.quantity,
        'price': item.product.ourPrice,
      }).toList();

      // The universal backend has no cart-reminder scheduler; keep the local
      // bookkeeping only (fail-soft no-op).
      _logger.log('Cart abandonment reminder skipped (${cartData.length} items) — no server endpoint');
    } catch (e) {
      _logger.error('Error scheduling cart abandonment reminder: $e');
    }
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(NotificationPreferences preferences) async {
    try {
      await _saveNotificationPreferences(preferences);
      
      // Re-subscribe to topics based on new preferences
      await _subscribeToTopics();
      
      // Sync with server
      await _syncUserProfileWithServer();
      
      _logger.log('Notification preferences updated');
    } catch (e) {
      _logger.error('Error updating notification preferences: $e');
    }
  }

  /// Get current notification preferences
  Future<NotificationPreferences> _getNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString(_preferencesKey);
      
      if (prefsJson != null) {
        return NotificationPreferences.fromJson(jsonDecode(prefsJson));
      }
      
      return NotificationPreferences();
    } catch (e) {
      _logger.error('Error loading notification preferences: $e');
      return NotificationPreferences();
    }
  }

  /// Save notification preferences
  Future<void> _saveNotificationPreferences(NotificationPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferencesKey, jsonEncode(preferences.toJson()));
    } catch (e) {
      _logger.error('Error saving notification preferences: $e');
    }
  }

  /// Load notification preferences on startup
  Future<void> _loadNotificationPreferences() async {
    // This method is called during initialization to load saved preferences
    await _getNotificationPreferences();
  }

  /// Subscribe to topics based on user preferences
  Future<void> _subscribeToTopics() async {
    try {
      final prefs = await _getNotificationPreferences();
      
      // Subscribe to general topics based on preferences
      if (prefs.flashSales) {
        await _firebaseMessaging.subscribeToTopic('flash_sales');
      } else {
        await _firebaseMessaging.unsubscribeFromTopic('flash_sales');
      }
      
      if (prefs.orderUpdates) {
        await _firebaseMessaging.subscribeToTopic('order_updates');
      } else {
        await _firebaseMessaging.unsubscribeFromTopic('order_updates');
      }
      
      if (prefs.personalizedOffers) {
        await _firebaseMessaging.subscribeToTopic('personalized_offers');
      } else {
        await _firebaseMessaging.unsubscribeFromTopic('personalized_offers');
      }
      
      // Subscribe to category topics
      for (final categoryId in prefs.subscribedCategories) {
        await _firebaseMessaging.subscribeToTopic('category_$categoryId');
      }
      
      // Subscribe to product topics
      for (final productCode in prefs.wishlistedProducts) {
        await _firebaseMessaging.subscribeToTopic('product_$productCode');
      }
      
      _logger.log('Successfully subscribed to notification topics');
    } catch (e) {
      _logger.error('Error subscribing to topics: $e');
    }
  }

  /// Sync user profile with server for personalized notifications
  Future<void> _syncUserProfileWithServer() async {
    try {
      final userProfile = await _ref.read(authRepositoryProvider).getUserProfile();
      if (userProfile == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      // No profile-sync endpoint on the universal backend — preferences stay
      // local; FCM topic subscriptions still apply (fail-soft no-op).
      _logger.log('Notification profile sync skipped — no server endpoint');
    } catch (e) {
      _logger.error('Error syncing user profile: $e');
    }
  }

  /// Sync product subscription with server
  Future<void> _syncProductSubscriptionWithServer(String productCode, {required bool subscribe}) async {
    try {
      final userProfile = await _ref.read(authRepositoryProvider).getUserProfile();
      if (userProfile == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      // No product-subscription endpoint on the universal backend — the FCM
      // topic subscription above is the effective mechanism (fail-soft no-op).
      _logger.log('Product subscription server sync skipped: $productCode ($subscribe)');
    } catch (e) {
      _logger.error('Error syncing product subscription: $e');
    }
  }

  /// Check if user is subscribed to a product
  Future<bool> isSubscribedToProduct(String productCode) async {
    try {
      final prefs = await _getNotificationPreferences();
      return prefs.wishlistedProducts.contains(productCode);
    } catch (e) {
      _logger.error('Error checking product subscription: $e');
      return false;
    }
  }

  /// Check if user is subscribed to a category
  Future<bool> isSubscribedToCategory(String categoryId) async {
    try {
      final prefs = await _getNotificationPreferences();
      return prefs.subscribedCategories.contains(categoryId);
    } catch (e) {
      _logger.error('Error checking category subscription: $e');
      return false;
    }
  }

  /// Send immediate notification for testing
  Future<void> sendTestNotification(NotificationType type, {Map<String, dynamic>? data}) async {
    try {
      final userProfile = await _ref.read(authRepositoryProvider).getUserProfile();
      if (userProfile == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      // No test-notification endpoint on the universal backend (no-op).
      _logger.log('Test notification skipped: $type — no server endpoint');
    } catch (e) {
      _logger.error('Error sending test notification: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}