// lib/data/services/cart_validator.dart
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:patelmart/data/models/product_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/cart_item.dart';

/// CartValidator pushes the local cart to the universal backend and validates
/// it against live stock/prices before checkout.
///
/// The universal backend keys the server cart by the logged-in customer's
/// mobile (from the JWT) — the legacy temp_order_id / customer_cart_key /
/// device_id machinery is kept only as inert compatibility accessors.
class CartValidator {
  final ApiClient? _apiClient;
  final Logger _logger;

  // Legacy keys kept so old installs' stored values can still be read/cleared
  static const String _cartKeyPrefKey = 'current_cart_key';
  static const String _deviceIdPrefKey = 'device_id';
  static const String _tempOrderIdPrefKey = 'temp_order_id';
  static const String _customerMobilePrefKey = 'customer_mobile';

  String? _currentDeviceId;
  String? _customerMobile;

  String? _lastSaveError;

  /// Why the last [saveCart] failed, in the server's own words.
  ///
  /// ApiClient throws an ApiException carrying the backend's `error` string on
  /// a 4xx, and saveCart used to swallow it whole and return a bare `false` —
  /// so every distinct cause (a rejected field, an expired session, a timeout)
  /// surfaced to the shopper as the same "Failed to update cart. Please try
  /// again.", with nothing in the UI to tell them or us apart.
  String? get lastSaveError => _lastSaveError;

  CartValidator({
    ApiClient? apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  // ---------------------------------------------------------------------
  // Legacy compatibility accessors (no longer sent to the API)
  // ---------------------------------------------------------------------

  Future<String?> getCurrentCartKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cartKeyPrefKey);
  }

  Future<String?> getCurrentDeviceId() async {
    if (_currentDeviceId != null) return _currentDeviceId;
    final prefs = await SharedPreferences.getInstance();
    _currentDeviceId = prefs.getString(_deviceIdPrefKey) ??
        'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_deviceIdPrefKey, _currentDeviceId!);
    return _currentDeviceId;
  }

  Future<String?> getCurrentTempOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tempOrderIdPrefKey);
  }

  Future<void> setCustomerMobile(String mobileNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerMobilePrefKey, mobileNumber);
    _customerMobile = mobileNumber;
    _logger.log('Set customer mobile: $_customerMobile');
  }

  Map<String, String> generateUniqueOrderIdentifiers() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
    return {
      'cartKey': 'ORDER_CONFIRM_${timestamp}_$randomSuffix',
      'tempOrderId': 'ORDER_TEMP_${timestamp}_$randomSuffix',
      'deviceId': 'DEVICE_ORDER_${timestamp}_$randomSuffix',
    };
  }

  // ---------------------------------------------------------------------
  // Universal backend cart operations
  // ---------------------------------------------------------------------

  /// Convert internal CartItem to the /api/cart item shape
  Map<String, dynamic> _convertCartItemToApi(CartItem item, String storeCode) {
    return {
      'p_code': item.product.pCode,
      'product_name': item.product.productName,
      'quantity': item.quantity,
      'unit_price': item.product.ourPrice,
      'total_price': item.product.ourPrice * item.quantity,
      'package_size': item.product.packageSize,
      'package_unit': item.product.packageUnit,
      'brand_name': item.product.brandName,
      'pcode_img': item.product.pcodeImg,
      'store_code': storeCode,
    };
  }

  /// Save the cart to the server (POST /api/cart/save-cart, JWT-scoped).
  Future<bool> saveCart(List<CartItem> cartItems, String storeCode,
      {bool isOrderConfirmation = false}) async {
    _lastSaveError = null;
    try {
      if (_apiClient == null) {
        _logger.error('CartValidator has no ApiClient — cannot save cart');
        _lastSaveError = 'Cart service unavailable';
        return false;
      }
      if (cartItems.isEmpty) {
        _logger.log('saveCart called with empty cart — skipping');
        return true;
      }

      final items = cartItems
          .map((item) => _convertCartItemToApi(item, storeCode))
          .toList();

      _logger.log('Saving cart with ${items.length} items for store $storeCode');

      final response = await _apiClient.postWithAuth(
        ApiConstants.cartSave,
        body: {
          'store_code': storeCode,
          'items': items,
        },
      );

      final success = response is Map && response['success'] == true;
      if (success) {
        _logger.log('Cart saved successfully');
      } else {
        _logger.error('Failed to save cart: $response');
        _lastSaveError = response is Map
            ? (response['error'] ?? response['message'])?.toString()
            : null;
      }
      return success;
    } on ApiException catch (e) {
      // The backend says exactly which item and field it rejected. Keep that —
      // it is the difference between "try again" and a fix the shopper can act
      // on, and between a reproducible bug report and a shrug.
      _logger.error('Error saving cart: ${e.message} (HTTP ${e.statusCode})');
      _lastSaveError = e.message;
      return false;
    } catch (e) {
      _logger.error('Error saving cart: $e');
      _lastSaveError = e.toString();
      return false;
    }
  }

  /// Kept for order-confirmation call sites; the server cart is always
  /// keyed by the customer, so this is a plain save now.
  Future<bool> saveCartForOrderConfirmation(
    List<CartItem> cartItems,
    String storeCode,
    String accessKey,
  ) async {
    return saveCart(cartItems, storeCode, isOrderConfirmation: true);
  }

  /// Validate the cart with the server (POST /api/cart/validate-cart).
  /// Always re-saves first so the server cart mirrors the local cart.
  Future<CartValidationResult?> validateCart(
      List<CartItem> cartItems, String storeCode) async {
    try {
      if (_apiClient == null) {
        return CartValidationResult(
          isValid: false,
          validationMessage: 'Cart service unavailable',
          isSaveError: true,
        );
      }

      final saved = await saveCart(cartItems, storeCode);
      if (!saved) {
        return CartValidationResult(
          isValid: false,
          validationMessage: _lastSaveError ?? 'Failed to save cart to server',
          isSaveError: true,
        );
      }

      final response = await _apiClient.postWithAuth(
        ApiConstants.cartValidate,
        body: {
          'store_code': storeCode,
          // autoFix stays off: the app shows the changes to the user, fixes
          // the LOCAL cart via applyValidationResult, then re-saves.
          'autoFix': false,
        },
      );

      if (response is! Map) {
        return CartValidationResult(
          isValid: false,
          validationMessage: 'Unexpected validation response',
        );
      }

      final validation = response['validation'] is Map
          ? response['validation'] as Map
          : {};
      final bool isValid = validation['valid'] == true;
      final String message =
          (response['message'] ?? 'Cart validation completed').toString();

      final result = CartValidationResult(
        isValid: isValid,
        validationMessage: message,
        rawResponse: Map<String, dynamic>.from(response),
      );

      CartItem? findItem(dynamic pCode) {
        final code = pCode?.toString() ?? '';
        for (final item in cartItems) {
          if (item.product.pCode == code) return item;
        }
        return null;
      }

      double toDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        return double.tryParse(value.toString()) ?? 0.0;
      }

      // Items with stock problems (removed / quantity capped)
      final invalidItems = validation['invalidItems'];
      if (invalidItems is List) {
        for (final issue in invalidItems) {
          if (issue is! Map) continue;
          final cartItem = findItem(issue['p_code']);
          if (cartItem == null) continue;

          final actionType = (issue['actionType'] ?? '').toString();
          final msg = (issue['message'] ?? '').toString();

          switch (actionType) {
            case 'out_of_stock':
            case 'product_not_found':
              result.removedItems.add(RemovedCartItem(
                product: cartItem.product,
                reason: msg.isNotEmpty ? msg : 'Product is out of stock',
                quantity: cartItem.quantity,
              ));
              break;
            case 'insufficient_stock':
            case 'max_quantity_exceeded':
              final available = issue['available_quantity'];
              final newQuantity = available is int
                  ? available
                  : int.tryParse(available?.toString() ?? '') ?? 0;
              if (newQuantity <= 0) {
                result.removedItems.add(RemovedCartItem(
                  product: cartItem.product,
                  reason: msg,
                  quantity: cartItem.quantity,
                ));
              } else {
                result.quantityChangedItems.add(QuantityChangedCartItem(
                  product: cartItem.product,
                  oldQuantity: cartItem.quantity,
                  newQuantity: newQuantity,
                  reason: msg,
                ));
              }
              break;
            default:
              result.itemsWithIssues.add(CartItemWithIssue(
                product: cartItem.product,
                issue: msg.isNotEmpty ? msg : 'Please review this item',
                quantity: cartItem.quantity,
              ));
          }

          // An invalid item may also carry a price change
          final price = issue['price'];
          if (price is Map && price['changed'] == true) {
            final newPrice = toDouble(price['new']);
            if (newPrice > 0 &&
                (newPrice - cartItem.product.ourPrice).abs() > 0.01 &&
                !result.priceChangedItems
                    .any((i) => i.product.pCode == cartItem.product.pCode)) {
              result.priceChangedItems.add(PriceChangedCartItem(
                product: cartItem.product,
                oldPrice: cartItem.product.ourPrice,
                newPrice: newPrice,
                quantity: cartItem.quantity,
              ));
            }
          }
        }
      }

      // Items whose price changed (stock fine)
      final updatedItems = validation['updatedItems'];
      if (updatedItems is List) {
        for (final update in updatedItems) {
          if (update is! Map) continue;
          final cartItem = findItem(update['p_code']);
          if (cartItem == null) continue;

          final price = update['price'];
          final newPrice =
              price is Map ? toDouble(price['new']) : toDouble(update['current_price']);
          if (newPrice > 0 &&
              (newPrice - cartItem.product.ourPrice).abs() > 0.01 &&
              !result.priceChangedItems
                  .any((i) => i.product.pCode == cartItem.product.pCode)) {
            result.priceChangedItems.add(PriceChangedCartItem(
              product: cartItem.product,
              oldPrice: cartItem.product.ourPrice,
              newPrice: newPrice,
              quantity: cartItem.quantity,
            ));
          }
        }
      }

      _logger.log(
          'Cart validation completed: valid=$isValid, removed=${result.removedItems.length}, '
          'qtyChanged=${result.quantityChangedItems.length}, priceChanged=${result.priceChangedItems.length}');
      return result;
    } catch (e) {
      _logger.error('Error validating cart: $e');
      return CartValidationResult(
        isValid: false,
        validationMessage: 'Error validating cart: $e',
      );
    }
  }

  /// Process cart validation and save in one call
  Future<CartValidationResult?> processCartValidation(
      List<CartItem> cartItems, String storeCode) async {
    // validateCart already re-saves first
    return validateCart(cartItems, storeCode);
  }

  /// Clear locally stored legacy cart identifiers (checkout completion or
  /// cart clearing). The server cart is replaced on the next save.
  Future<void> clearCartData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKeyPrefKey);
      await prefs.remove(_tempOrderIdPrefKey);
      _logger.log('Cart data cleared');
    } catch (e) {
      _logger.error('Error clearing cart data: $e');
    }
  }

  /// Clear the server-side cart for this customer/store.
  Future<void> clearServerCart(String storeCode) async {
    try {
      if (_apiClient == null) return;
      await _apiClient.postWithAuth(
        ApiConstants.cartClear,
        body: {'store_code': storeCode},
      );
      _logger.log('Server cart cleared for store $storeCode');
    } catch (e) {
      _logger.error('Error clearing server cart: $e');
    }
  }

  /// Retry saving the cart (used when first attempt failed)
  Future<bool> retrySaveCart(List<CartItem> cartItems, String storeCode) async {
    return saveCart(cartItems, storeCode);
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
