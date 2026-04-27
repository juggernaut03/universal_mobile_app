// lib/data/services/cart_validator.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart'; // Add this import for SHA-256
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
  static const String _tempOrderIdPrefKey = 'temp_order_id';
  static const String _customerMobilePrefKey = 'customer_mobile'; // Added to store customer mobile
  
  static const String _saveCartUrl = '${ApiConstants.baseUrl}/save_cart';
  static const String _validateCartUrl = '${ApiConstants.baseUrl}/validate_cart';
  
  // Instance variables to maintain consistency between operations
  String? _currentCartKey;
  String? _currentDeviceId;
  String? _currentTempOrderId;
  String? _customerMobile;
  
  CartValidator({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger() {
    // Load saved cart key and device ID on initialization
    _loadSavedCartInfo();
  }
  
  /// Get the current cart key used for operations
  Future<String?> getCurrentCartKey() async {
    // If we don't have a cart key loaded yet, try to load it
    if (_currentCartKey == null) {
      await _loadSavedCartInfo();
    }
    return _currentCartKey;
  }

  /// Get the current device ID
  Future<String?> getCurrentDeviceId() async {
    // If we don't have a device ID loaded yet, try to load it
    if (_currentDeviceId == null) {
      await _loadSavedCartInfo();
    }
    return _currentDeviceId;
  }
  
  /// Get the current temp order ID
  Future<String?> getCurrentTempOrderId() async {
    // If we don't have a temp order ID loaded yet, try to load it
    if (_currentTempOrderId == null) {
      await _loadSavedCartInfo();
    }
    return _currentTempOrderId;
  }
  // lib/data/services/cart_validator.dart
// Add this method to your existing CartValidator class

/// Save cart specifically for order confirmation with unique identifiers
Future<bool> saveCartForOrderConfirmation(
  List<CartItem> cartItems, 
  String storeCode,
  String accessKey,
) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
    
    // Generate unique identifiers for order confirmation
    final uniqueOrderCartKey = 'ORDER_CONFIRM_${timestamp}_$randomSuffix';
    final uniqueTempOrderId = 'ORDER_TEMP_${timestamp}_$randomSuffix';
    final uniqueDeviceId = 'DEVICE_ORDER_${timestamp}_$randomSuffix';
    
    // Convert cart items to API format
    final List<Map<String, dynamic>> apiItems = cartItems
        .map((item) => _convertCartItemToApi(item))
        .toList();
    
    // Create request body for order confirmation
    final requestBody = {
      'project_code': ApiConstants.projectCode,
      'temp_order_id': uniqueTempOrderId,
      'customer_cart_key': uniqueOrderCartKey,
      'store_code': storeCode,
      'device_id': uniqueDeviceId,
      'access_key': accessKey,
      'cart_items': apiItems,
      'order_status': "Order Confirmed",
    };
    
    _logger.log('Saving cart for order confirmation with unique identifiers:');
    _logger.log('Cart Key: $uniqueOrderCartKey');
    _logger.log('Temp Order ID: $uniqueTempOrderId');
    _logger.log('Items: ${apiItems.length}');
    
    final response = await _client.post(
      Uri.parse(_saveCartUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));
    
    // Check if the response is successful
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      _logger.log('Cart saved for order confirmation: ${responseData['message']}');
      return true;
    } else {
      _logger.error('Failed to save cart for order confirmation: ${response.statusCode} - ${response.body}');
      return false;
    }
  } catch (e) {
    _logger.error('Error saving cart for order confirmation: $e');
    return false;
  }
}

/// Get unique identifiers for order confirmation
Map<String, String> generateUniqueOrderIdentifiers() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
  
  return {
    'cartKey': 'ORDER_CONFIRM_${timestamp}_$randomSuffix',
    'tempOrderId': 'ORDER_TEMP_${timestamp}_$randomSuffix',
    'deviceId': 'DEVICE_ORDER_${timestamp}_$randomSuffix',
  };
}
  /// Initialize cart info from SharedPreferences
  Future<void> _loadSavedCartInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentCartKey = prefs.getString(_cartKeyPrefKey);
      _currentDeviceId = prefs.getString(_deviceIdPrefKey);
      _currentTempOrderId = prefs.getString(_tempOrderIdPrefKey);
      _customerMobile = prefs.getString(_customerMobilePrefKey);
      
      if (_currentCartKey != null) {
        _logger.log('Loaded saved cart key: $_currentCartKey');
      }
      
      // Generate new identifiers if none exist
      if (_currentDeviceId == null) {
        _currentDeviceId = _generateDeviceId();
        await prefs.setString(_deviceIdPrefKey, _currentDeviceId!);
      }
      
      if (_currentTempOrderId == null) {
        _currentTempOrderId = _generateOrderId(_currentDeviceId!);
        await prefs.setString(_tempOrderIdPrefKey, _currentTempOrderId!);
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
  
  /// Save the customer's mobile number and generate a consistent cart key
  Future<void> setCustomerMobile(String mobileNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customerMobilePrefKey, mobileNumber);
      _customerMobile = mobileNumber;
      
      // Generate and save a consistent cart key based on the mobile number
      final cartKey = _generateCartKeyFromMobile(mobileNumber);
      await _saveCartKey(cartKey);
      
      _logger.log('Set customer mobile: $mobileNumber, generated cart key: $cartKey');
    } catch (e) {
      _logger.error('Error setting customer mobile: $e');
    }
  }
  
  /// Save the current temp order ID to persistent storage
  Future<void> _saveTempOrderId(String tempOrderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tempOrderIdPrefKey, tempOrderId);
      _currentTempOrderId = tempOrderId;
    } catch (e) {
      _logger.error('Error saving temp order ID: $e');
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
  
  /// Generate a consistent order ID based on device ID
  String _generateOrderId(String deviceId) {
    // Use a fixed order ID format that will be consistent for this device
    // This ensures we update the same cart entry rather than creating new ones
    return "AND_${deviceId.replaceAll('DEVICE_', '')}";
  }
  
  /// Get consistent order ID
  String _getOrderId() {
    final deviceId = _getDeviceId();
    if (_currentTempOrderId != null) {
      return _currentTempOrderId!;
    }
    
    final tempOrderId = _generateOrderId(deviceId);
    _saveTempOrderId(tempOrderId);
    return tempOrderId;
  }
  
  /// Generate a consistent cart key using SHA-256 hash of mobile number
  String _generateCartKeyFromMobile(String mobileNumber) {
    // Create a SHA-256 hash of the mobile number
    final bytes = utf8.encode(mobileNumber);
    final hash = sha256.convert(bytes);
    
    // Return a cart key with a prefix for identification
    return 'CART_KEY_${hash.toString().substring(0, 16)}';
  }
  
  /// Generate a fallback cart key if no mobile number is available
  String _generateFallbackCartKey() {
    final deviceId = _getDeviceId();
    return 'CART_KEY_${deviceId.replaceAll('DEVICE_', '')}';
  }
  
  /// Get the appropriate cart key based on available information
  String _getCartKey() {
    // If we have a customer mobile number, use it to generate a consistent key
    if (_customerMobile != null && _customerMobile!.isNotEmpty) {
      return _generateCartKeyFromMobile(_customerMobile!);
    }
    
    // If we have a saved cart key, use that
    if (_currentCartKey != null) {
      return _currentCartKey!;
    }
    
    // Otherwise, generate a fallback cart key
    return _generateFallbackCartKey();
  }
  
  /// Save the cart to the server
  Future<bool> saveCart(List<CartItem> cartItems, String storeCode, 
    {bool isOrderConfirmation = false}) async {
    try {
      final deviceId = _getDeviceId();
      String customerCartKey;
      
      if (isOrderConfirmation) {
        // For order confirmation, we still want to use the consistent cart key
        // based on the customer's mobile number to allow for order history tracking
        customerCartKey = _getCartKey();
        _logger.log('Using consistent cart key for order confirmation: $customerCartKey');
      } else {
        // For regular cart operations, use the consistent cart key
        customerCartKey = _getCartKey();
      }
      
      final tempOrderId = _getOrderId();
      
      // Convert cart items to API format
      final List<Map<String, dynamic>> apiItems = cartItems
          .map((item) => _convertCartItemToApi(item))
          .toList();
      
      // Create request body - set status based on operation type
      final requestBody = {
        'project_code': ApiConstants.projectCode,
        'temp_order_id': tempOrderId,
        'customer_cart_key': customerCartKey,
        'store_code': storeCode,
        'device_id': deviceId,
        'cart_items': apiItems,
        'order_status': isOrderConfirmation ? "Order Confirmed" : "In Cart",
      };
      
      _logger.log('Saving cart with ${apiItems.length} items, cart key: $customerCartKey, '
          'temp_order_id: $tempOrderId, order status: ${isOrderConfirmation ? "Order Confirmed" : "In Cart"}');
      
      final response = await _client.post(
        Uri.parse(_saveCartUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      // Check if the response is successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        _logger.log('Cart saved successfully: ${responseData['message']}');
        
        // Store the cart key for future operations (for both regular and order confirmation)
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
      // Use the consistent cart key
      final customerCartKey = _getCartKey();
      
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
      
      // Print full request for Postman testing
      try {
        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        final String prettyJson = encoder.convert(requestBody);
        print('');
        print('==== VALIDATE CART REQUEST ====');
        print('POST $_validateCartUrl');
        print('Content-Type: application/json');
        print('--- BODY (${apiItems.length} items) ---');
        print(prettyJson);
        print('================================');
        print('');
      } catch (e) {
        print('Error printing request body: $e');
      }

      _logger.log('Validating cart with ${apiItems.length} items, cart key: $customerCartKey, temp_order_id: $tempOrderId');
      
      final response = await _client.post(
        Uri.parse(_validateCartUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      // Print full response for Postman comparison
      try {
        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        final dynamic rawDecoded = jsonDecode(response.body);
        final String prettyJson = encoder.convert(rawDecoded);
        print('');
        print('==== VALIDATE CART RESPONSE ====');
        print('Status: ${response.statusCode}');
        print('--- BODY ---');
        print(prettyJson);
        print('================================');
        print('');
      } catch (e) {
        print('Error printing response body: $e');
      }

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
              final action = validatedItem['action'];
              final actionType = validatedItem['action_type'];
              
              bool handled = false;
              
              // NEW LOGIC FOR ACTION FIELDS
              if (action != null && actionType != null) {
                 // Case 1: Insufficient Stock
                 if (actionType == 'insufficient_stock') {
                    // Try to parse quantity
                    final match = RegExp(r'Only (\d+) items').firstMatch(validation.toString());
                    if (match != null) {
                        final availableQty = int.parse(match.group(1)!);
                         result.quantityChangedItems.add(QuantityChangedCartItem(
                            product: cartItem.product,
                            oldQuantity: cartItem.quantity,
                            newQuantity: availableQty,
                            reason: validation.toString(),
                          ));
                          handled = true;
                    }
                 }
                 // Case 2: Price Change
                 else if (actionType.toString().startsWith('price_changed')) {
                    final matchPrice = RegExp(r'update_price\s+([\d\.]+)').firstMatch(action.toString());
                    if (matchPrice != null) {
                         final newPrice = double.tryParse(matchPrice.group(1)!) ?? 0.0;
                         // Verify price actually changed
                         if ((newPrice - cartItem.product.ourPrice).abs() > 0.01) {
                            result.priceChangedItems.add(PriceChangedCartItem(
                                product: cartItem.product,
                                oldPrice: cartItem.product.ourPrice,
                                newPrice: newPrice,
                                quantity: cartItem.quantity,
                            ));
                         }
                         handled = true;
                    }
                 }
              }
              
              if (handled) continue;
              
              // Check for validation text
              if (validation != null && validation.toString().isNotEmpty) {
                // Check for out of stock items
                if (validation.toString().toLowerCase().contains('out of stock')) {
                  result.removedItems.add(RemovedCartItem(
                    product: cartItem.product,
                    reason: validation.toString(),
                    quantity: cartItem.quantity,
                  ));
                  continue;
                } else {
                  // Add as item with issue if not specifically out of stock
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
                 if (!result.priceChangedItems.any((i) => i.product.pCode == pcode)) {
                    result.priceChangedItems.add(PriceChangedCartItem(
                      product: cartItem.product,
                      oldPrice: cartItem.product.ourPrice,
                      newPrice: validatedPrice,
                      quantity: cartItem.quantity,
                    ));
                 }
              }
              
              // Check if quantity is 0 (out of stock)
              final quantity = validatedItem['quantity'] ?? 0;
              if (quantity == 0) {
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
  
  /// Clear the current cart key and all related data (for checkout completion or cart clearing)
  Future<void> clearCartData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKeyPrefKey);
      await prefs.remove(_tempOrderIdPrefKey);
      // Note: We don't clear the customer mobile or device ID to maintain consistency
      // between sessions
      _currentCartKey = null;
      _currentTempOrderId = null;
      _logger.log('Cart data cleared');
    } catch (e) {
      _logger.error('Error clearing cart data: $e');
    }
  }
  
  /// Retry saving the cart (used when first attempt failed)
  Future<bool> retrySaveCart(List<CartItem> cartItems, String storeCode) async {
    try {
      // We'll still use the consistent cart key, but retry the save operation
      // Attempt to save the cart again (will use the same cart key and temp_order_id)
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
  final List<QuantityChangedCartItem> quantityChangedItems = [];
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
      quantityChangedItems.isNotEmpty ||
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

class QuantityChangedCartItem {
  final ProductModel product;
  final int oldQuantity;
  final int newQuantity;
  final String reason;

  QuantityChangedCartItem({
    required this.product,
    required this.oldQuantity,
    required this.newQuantity,
    required this.reason,
  });
}