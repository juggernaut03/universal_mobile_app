// lib/data/services/cart_storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import '../../presentation/providers/cart_provider.dart';
import '../models/product_model.dart';

/// Service responsible for saving and loading cart data from persistent storage
class CartStorageService {
  final SharedPreferences _prefs;
  final Logger _logger;
  
  // Keys for storing cart data
  static const String _cartItemsKey = 'cart_items';
  static const String _cartTimestampKey = 'cart_timestamp';
  
  // Session expiration time (10 days in milliseconds)
  static const int _sessionExpirationTime = 10 * 24 * 60 * 60 * 1000; // 10 days

  CartStorageService({
    required SharedPreferences prefs,
    Logger? logger,
  }) : 
    _prefs = prefs,
    _logger = logger ?? Logger();

  /// Save the current cart items to persistent storage
  Future<bool> saveCart(List<CartItem> cartItems) async {
    try {
      // Convert cart items to JSON
      final cartItemsJson = cartItems.map((item) => {
        'productId': item.product.pCode,
        'quantity': item.quantity,
        'product': item.product.toJson(),
      }).toList();
      
      // Save cart items
      final success = await _prefs.setString(
        _cartItemsKey, 
        jsonEncode(cartItemsJson)
      );
      
      // Save timestamp of last cart update
      if (success) {
        await _prefs.setInt(
          _cartTimestampKey, 
          DateTime.now().millisecondsSinceEpoch
        );
        _logger.log('Cart saved successfully with ${cartItems.length} items');
      }
      
      return success;
    } catch (e) {
      _logger.error('Error saving cart: $e');
      return false;
    }
  }

  /// Load cart items from persistent storage
  /// Returns empty list if cart is expired or not found
  Future<List<CartItem>> loadCart() async {
    try {
      // Check if cart data exists and session is still valid
      if (!_isCartSessionValid()) {
        _logger.log('Cart session expired or not found');
        return [];
      }
      
      // Load cart items
      final cartJson = _prefs.getString(_cartItemsKey);
      if (cartJson == null || cartJson.isEmpty) {
        _logger.log('No cart data found');
        return [];
      }
      
      // Parse JSON to cart items
      final List<dynamic> itemsJson = jsonDecode(cartJson);
      final List<CartItem> cartItems = [];
      
      for (final itemJson in itemsJson) {
        try {
          final productJson = itemJson['product'];
          if (productJson != null) {
            final product = ProductModel.fromJson(productJson);
            final quantity = itemJson['quantity'] as int? ?? 1;
            
            cartItems.add(CartItem(
              product: product,
              quantity: quantity,
            ));
          }
        } catch (e) {
          _logger.error('Error parsing cart item: $e');
          // Continue with next item on error
        }
      }
      
      _logger.log('Loaded ${cartItems.length} items from cart');
      return cartItems;
    } catch (e) {
      _logger.error('Error loading cart: $e');
      return [];
    }
  }

  /// Clear the cart data from persistent storage
  Future<bool> clearCart() async {
    try {
      await _prefs.remove(_cartItemsKey);
      await _prefs.remove(_cartTimestampKey);
      _logger.log('Cart cleared successfully');
      return true;
    } catch (e) {
      _logger.error('Error clearing cart: $e');
      return false;
    }
  }

  /// Check if the cart session is still valid
  bool _isCartSessionValid() {
    final lastUpdateTime = _prefs.getInt(_cartTimestampKey);
    if (lastUpdateTime == null) return false;
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsed = currentTime - lastUpdateTime;
    
    // Session is valid if less than expiration time has passed
    return elapsed < _sessionExpirationTime;
  }
  
  /// Get the session expiration time in days
  int get sessionExpirationDays => _sessionExpirationTime ~/ (24 * 60 * 60 * 1000);
  
  /// Refresh the cart session timestamp (extend session)
  Future<bool> refreshCartSession() async {
    try {
      final success = await _prefs.setInt(
        _cartTimestampKey, 
        DateTime.now().millisecondsSinceEpoch
      );
      
      if (success) {
        _logger.log('Cart session refreshed successfully');
      }
      
      return success;
    } catch (e) {
      _logger.error('Error refreshing cart session: $e');
      return false;
    }
  }
  
  /// Get the remaining session time in milliseconds
  int getRemainingSessionTime() {
    final lastUpdateTime = _prefs.getInt(_cartTimestampKey);
    if (lastUpdateTime == null) return 0;
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsed = currentTime - lastUpdateTime;
    
    return _sessionExpirationTime - elapsed;
  }
}