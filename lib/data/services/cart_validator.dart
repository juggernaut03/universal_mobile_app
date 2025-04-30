// lib/data/services/cart_validator.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:patelmart/data/models/product_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../presentation/providers/cart_provider.dart';

/// CartValidator handles saving and validating cart items with the server
/// before proceeding to checkout
class CartValidator {
  final http.Client _client;
  final Logger _logger;
  
  // Keys for storing cart information
  static const String _cartKeyPrefKey = 'current_cart_key';
  static const String _deviceIdPrefKey = 'device_id';
  
  static const String _saveCartUrl = '${ApiConstants.baseUrl}/save_cart';
  static const String _validateCartUrl = '${ApiConstants.baseUrl}/validate_cart';
  
  // Instance variables to maintain consistency between operations
  String? _currentCartKey;
  String? _currentDeviceId;
  
  CartValidator({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger() {
    // Load saved cart key and device ID on initialization
    _loadSavedCartInfo();
  }
   Future<String?> getCurrentCartKey() async {
  // If we don't have a cart key loaded yet, try to load it
  if (_currentCartKey == null) {
    await _loadSavedCartInfo();
  }
  return _currentCartKey;
}

// Get the current device ID
Future<String?> getCurrentDeviceId() async {
  // If we don't have a device ID loaded yet, try to load it
  if (_currentDeviceId == null) {
    await _loadSavedCartInfo();
  }
  return _currentDeviceId;
}
  /// Initialize cart info from SharedPreferences
  Future<void> _loadSavedCartInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentCartKey = prefs.getString(_cartKeyPrefKey);
      _currentDeviceId = prefs.getString(_deviceIdPrefKey);
      
      if (_currentCartKey != null) {
        _logger.log('Loaded saved cart key: $_currentCartKey');
      }
      
      // Generate new identifiers if none exist
      if (_currentDeviceId == null) {
        _currentDeviceId = _generateDeviceId();
        await prefs.setString(_deviceIdPrefKey, _currentDeviceId!);
      }
    } catch (e) {
      _logger.error('Error loading saved cart info: $e');
    }
  }
  
  /// Save the current cart key to persistent storage
  Future<void> _saveCartKey(String cartKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartKeyPrefKey, cartKey);
      _currentCartKey = cartKey;
    } catch (e) {
      _logger.error('Error saving cart key: $e');
    }
  }

  /// Convert internal CartItem to API format
  Map<String, dynamic> _convertCartItemToApi(CartItem item) {
    return {
      'pcode': item.product.pCode,
      'product_name': item.product.productName,
      'product_mrp': item.product.productMrp,
      'selling_price': item.product.ourPrice,
      'package_size': item.product.packageSize,
      'package_unit': item.product.packageUnit,
      'stock_message': "Yes",
      'price_alert_message': "Yes",
      'quantity': item.quantity,
      'product_image_link': item.product.pcodeImg,
    };
  }

  /// Generate a unique device ID for API request
  String _generateDeviceId() {
    // In a real app, this would use device_info_plus to get an actual device ID
    return 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Get the current device ID or generate a new one
  String _getDeviceId() {
    return _currentDeviceId ?? _generateDeviceId();
  }
  
  /// Get consistent order ID
  String _getOrderId() {
    // Use a fixed order ID format that will be consistent for this device
    // This ensures we update the same cart entry rather than creating new ones
    return "AND_${_getDeviceId().replaceAll('DEVICE_', '')}";
  }
  
  /// Generate a new cart key
  String _generateCartKey() {
    return 'CART_KEY_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Save the cart to the server
  Future<bool> saveCart(List<CartItem> cartItems, String storeCode) async {
    try {
      // Use the existing cart key or generate a new one
      final customerCartKey = _currentCartKey ?? _generateCartKey();
      final deviceId = _getDeviceId();
      final tempOrderId = _getOrderId();
      
      // Convert cart items to API format
      final List<Map<String, dynamic>> apiItems = cartItems
          .map((item) => _convertCartItemToApi(item))
          .toList();
      
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'temp_order_id': tempOrderId,
        'customer_cart_key': customerCartKey,
        'store_code': storeCode,
        'device_id': deviceId,
        'cart_items': apiItems,
      };
      
      _logger.log('Saving cart with ${apiItems.length} items, cart key: $customerCartKey');
      
      print('SAVE CART REQUEST: ${jsonEncode(requestBody)}');
      
      final response = await _client.post(
        Uri.parse(_saveCartUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      print('SAVE CART RESPONSE [${response.statusCode}]: ${response.body}');
      
      // Check if the response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        _logger.log('Cart saved successfully: ${responseData['message']}');
        
        // Store the cart key for future operations
        await _saveCartKey(customerCartKey);
        
        return true;
      } else {
        _logger.error('Failed to save cart: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('Error saving cart: $e');
      return false;
    }
  }
  
  /// Validate the cart with the server
  Future<CartValidationResult?> validateCart(List<CartItem> cartItems, String storeCode) async {
    try {
      // Use the same cart key that was used for saving
      final customerCartKey = _currentCartKey;
      
      if (customerCartKey == null) {
        _logger.error('Cannot validate cart: No cart has been saved yet');
        return CartValidationResult(
          isValid: false,
          validationMessage: 'Cart must be saved before validation',
          isSaveError: true,
        );
      }
      
      final deviceId = _getDeviceId();
      final tempOrderId = _getOrderId();
      
      // Convert cart items to API format
      final List<Map<String, dynamic>> apiItems = cartItems
          .map((item) => _convertCartItemToApi(item))
          .toList();
      
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'temp_order_id': tempOrderId,
        'customer_cart_key': customerCartKey,
        'store_code': storeCode,
        'device_id': deviceId,
        'cart_items': apiItems,
      };
      
      _logger.log('Validating cart with ${apiItems.length} items, cart key: $customerCartKey');
      
      print('VALIDATE CART REQUEST: ${jsonEncode(requestBody)}');
      
      final response = await _client.post(
        Uri.parse(_validateCartUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      print('VALIDATE CART RESPONSE [${response.statusCode}]: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse response
        final responseData = jsonDecode(response.body);
        
        // Parse the validation message
        String validationMessage = responseData['message'] ?? 'Cart validation completed';
        
        // Check if this is an invalid cart response
        bool isValid = true;
        if (validationMessage.contains("Not Valid Cart")) {
          isValid = false;
        }
        
        // Create validation result object - override isValid based on server response
        final result = CartValidationResult(
          isValid: isValid, // Set to false if message contains "Not Valid Cart"
          validationMessage: validationMessage,
          // Store the raw response for potential retries
          rawResponse: responseData,
        );
        
        // Process validated items if available
        if (responseData.containsKey('validated_cart_items')) {
          final List<dynamic> validatedItems = responseData['validated_cart_items'];
          
          for (final validatedItem in validatedItems) {
            final pcode = validatedItem['pcode'];
            
            // Find matching cart item
            final cartItemIndex = cartItems.indexWhere(
              (item) => item.product.pCode == pcode
            );
            
            if (cartItemIndex >= 0) {
              final cartItem = cartItems[cartItemIndex];
              final validation = validatedItem['validation_txt'];
              
              // Check for validation text
              if (validation != null && validation.toString().isNotEmpty) {
                print('Item has validation text: $validation');
                
                // Check for out of stock items
                if (validation.toString().toLowerCase().contains('out of stock')) {
                  print('Item is out of stock');
                  result.removedItems.add(RemovedCartItem(
                    product: cartItem.product,
                    reason: validation.toString(),
                    quantity: cartItem.quantity,
                  ));
                  continue;
                } else {
                  // Add as item with issue if not specifically out of stock
                  print('Item has other issue');
                  result.itemsWithIssues.add(CartItemWithIssue(
                    product: cartItem.product,
                    issue: validation.toString(),
                    quantity: cartItem.quantity,
                  ));
                }
              }
              
              // Check for price changes
              final validatedPrice = _toDouble(validatedItem['selling_price']);
              if ((validatedPrice - cartItem.product.ourPrice).abs() > 0.01) {
                print('Item price changed from ${cartItem.product.ourPrice} to $validatedPrice');
                result.priceChangedItems.add(PriceChangedCartItem(
                  product: cartItem.product,
                  oldPrice: cartItem.product.ourPrice,
                  newPrice: validatedPrice,
                  quantity: cartItem.quantity,
                ));
              }
              
              // Check if quantity is 0 (out of stock)
              final quantity = validatedItem['quantity'] ?? 0;
              if (quantity == 0) {
                print('Item quantity is 0');
                if (!result.removedItems.any((item) => item.product.pCode == pcode)) {
                  result.removedItems.add(RemovedCartItem(
                    product: cartItem.product,
                    reason: validation?.toString() ?? 'Item is out of stock',
                    quantity: cartItem.quantity,
                  ));
                }
              }
            }
          }
        }
        
        // For generic "Not Valid Cart" with no specific issues, create some artificial changes
        // when we have received multiple "Not Valid Cart" responses in a row
        if (!isValid && result.removedItems.isEmpty && 
            result.priceChangedItems.isEmpty && result.itemsWithIssues.isEmpty) {
          
          result.forcedHasChanges = true;
          
          // Add a fake issue for generic case - server isn't providing specific details
          if (cartItems.isNotEmpty) {
            // Mark the first item as needing attention (this will trigger UI feedback)
            final firstItem = cartItems.first;
            result.genericValidationItem = GenericValidationItem(
              product: firstItem.product,
              quantity: firstItem.quantity,
            );
          }
        }
        
        _logger.log('Cart validation completed: ${result.validationMessage}');
        return result;
      } else {
        _logger.error('Failed to validate cart: ${response.statusCode} - ${response.body}');
        // Return a validation result with a failure message
        return CartValidationResult(
          isValid: false,
          validationMessage: 'Failed to validate cart: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.error('Error validating cart: $e');
      return CartValidationResult(
        isValid: false,
        validationMessage: 'Error validating cart: $e',
      );
    }
  }
  
  // Helper to safely convert values to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }
  
  /// Process cart validation and save in one call
  Future<CartValidationResult?> processCartValidation(List<CartItem> cartItems, String storeCode) async {
    try {
      // First save the cart
      final saveSuccess = await saveCart(cartItems, storeCode);
      if (!saveSuccess) {
        _logger.error('Failed to save cart before validation');
        return CartValidationResult(
          isValid: false,
          validationMessage: 'Failed to save cart to server',
          isSaveError: true,  // Flag this as a save error
        );
      }
      
      _logger.log('Cart saved successfully, proceeding with validation');
      
      // Then validate the cart using the same cart key
      final validationResult = await validateCart(cartItems, storeCode);
      if (validationResult == null) {
        _logger.error('Cart validation returned null');
        return CartValidationResult(
          isValid: false,
          validationMessage: 'Failed to validate cart with server',
        );
      }
      
      _logger.log('Cart validation completed successfully');
      return validationResult;
    } catch (e) {
      _logger.error('Error processing cart validation: $e');
      return CartValidationResult(
        isValid: false,
        validationMessage: 'Error: $e',
      );
    }
  }
  
  /// Clear the current cart key (for checkout completion or cart clearing)
  Future<void> clearCartKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKeyPrefKey);
      _currentCartKey = null;
      _logger.log('Cart key cleared');
    } catch (e) {
      _logger.error('Error clearing cart key: $e');
    }
  }
  
  /// Retry saving the cart (used when first attempt failed)
  Future<bool> retrySaveCart(List<CartItem> cartItems, String storeCode) async {
    print('Retrying cart save operation');
    try {
      // Generate a new cart key but keep the same order ID to update the entry
      _currentCartKey = _generateCartKey();
      
      // Attempt to save the cart again (will use the same temp_order_id)
      final saveSuccess = await saveCart(cartItems, storeCode);
      return saveSuccess;
    } catch (e) {
      _logger.error('Error retrying cart save: $e');
      return false;
    }
  }
}

/// Result models for cart validation
class CartValidationResult {
  final bool isValid;
  final String validationMessage;
  final List<RemovedCartItem> removedItems = [];
  final List<PriceChangedCartItem> priceChangedItems = [];
  final List<CartItemWithIssue> itemsWithIssues = [];
  final Map<String, dynamic>? rawResponse;
  final bool isSaveError;
  bool forcedHasChanges = false;
  bool maxRetriesReached;
  GenericValidationItem? genericValidationItem;
  
  CartValidationResult({
    required this.isValid,
    required this.validationMessage,
    this.rawResponse,
    this.isSaveError = false,
    this.maxRetriesReached = false,
  });
  
  bool get hasChanges => 
      removedItems.isNotEmpty || 
      priceChangedItems.isNotEmpty || 
      itemsWithIssues.isNotEmpty ||
      forcedHasChanges ||
      genericValidationItem != null ||
      !isValid;
      
  bool get requiresServerRetry => isSaveError;
}

class RemovedCartItem {
  final ProductModel product;
  final String reason;
  final int quantity;
  
  RemovedCartItem({
    required this.product,
    required this.reason,
    required this.quantity,
  });
}

class PriceChangedCartItem {
  final ProductModel product;
  final double oldPrice;
  final double newPrice;
  final int quantity;
  
  PriceChangedCartItem({
    required this.product,
    required this.oldPrice,
    required this.newPrice,
    required this.quantity,
  });
  
  double get priceDifference => newPrice - oldPrice;
  bool get isPriceIncreased => newPrice > oldPrice;
}

class CartItemWithIssue {
  final ProductModel product;
  final String issue;
  final int quantity;
  
  CartItemWithIssue({
    required this.product,
    required this.issue,
    required this.quantity,
  });
}

class GenericValidationItem {
  final ProductModel product;
  final int quantity;
  
  GenericValidationItem({
    required this.product,
    required this.quantity,
  });
}