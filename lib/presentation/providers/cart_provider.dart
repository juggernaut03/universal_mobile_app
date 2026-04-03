// lib/presentation/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/product_model.dart';
import '../../data/services/cart_storage_service.dart';
import '../../data/services/cart_validator.dart';
import '../../data/services/cart_session_manager.dart';
import '../../core/utils/logger.dart';
import 'launch_flow_provider.dart';
import 'steal_deals_provider.dart';
// FACEBOOK PIXEL IMPORTS
import '../../facebook_pixel/facebook_pixel_integration.dart';
import '../../facebook_pixel/facebook_pixel_provider.dart';

// Cart item model
class CartItem {
  final ProductModel product;
  final int quantity;
 
  CartItem({
    required this.product,
    required this.quantity,
  });

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  // Calculate total price for this item
  double get totalPrice => product.ourPrice * quantity;
  
  // Calculate total MRP for this item
  double get totalMrp => product.productMrp * quantity;
  
  // Calculate savings for this item
  double get savings => totalMrp - totalPrice;
}

// Provider for CartStorageService
final cartStorageServiceProvider = Provider<CartStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final logger = ref.watch(loggerProvider);
  return CartStorageService(prefs: prefs, logger: logger);
});

// Provider for cart session manager
final cartSessionManagerProvider = Provider<CartSessionManager>((ref) {
  final logger = ref.watch(loggerProvider);
  return CartSessionManager(logger: logger);
});

// Cart state notifier with enhanced session management
class CartNotifier extends StateNotifier<List<CartItem>> {
  // Store a reference to Ref for accessing other providers
  final Ref _ref;
  final CartStorageService _cartStorage;
  late final CartSessionManager _sessionManager;
  late final Logger _logger;
  
  CartNotifier(this._ref, this._cartStorage) : super([]) {
    // Initialize session manager and logger
    _sessionManager = _ref.read(cartSessionManagerProvider);
    _logger = _ref.read(loggerProvider);
    
    // Load cart from persistent storage on initialization
    _loadCart();
  }

  // FIXED: Load cart with proper session initialization
  Future<void> _loadCart() async {
    try {
      final items = await _cartStorage.loadCart();
      state = items;
      
      // FIXED: Ensure we have a valid session when cart is loaded
      if (items.isNotEmpty) {
        final sessionValid = await _sessionManager.isCartSessionValid();
        if (!sessionValid) {
          _logger.log('Cart loaded but session invalid - creating new session');
          await _sessionManager.createNewOrderSession();
        } else {
          await _cartStorage.refreshCartSession();
        }
      } else {
        // If cart is empty, ensure we have a fresh session ready
        final sessionValid = await _sessionManager.isCartSessionValid();
        if (!sessionValid) {
          await _sessionManager.createNewOrderSession();
        }
      }
      
      _logger.log('Loaded ${items.length} items from persistent cart storage');
    } catch (e) {
      _logger.error('Error loading cart: $e');
    }
  }
  
  // Save current cart state to persistent storage
  Future<void> _saveCart() async {
    try {
      await _cartStorage.saveCart(state);
    } catch (e) {
      _logger.error('Error saving cart: $e');
    }
  }

  // ENHANCED: Add item to cart with session management
  void addItem(ProductModel product) {
    // Mark cart as modified for session management
    _markCartAsModifiedAsync();
    
    final index = state.indexWhere((item) => item.product.pCode == product.pCode);
    if (index >= 0) {
      // Product exists, increment quantity if below max allowed
      final existingItem = state[index];
      if (existingItem.quantity < product.maxQuantityAllowed) {
        final updatedItems = [...state];
        updatedItems[index] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
        );
        state = updatedItems;
        _saveCart(); // Save cart after update
        _logger.log('Incremented quantity for ${product.productName} to ${existingItem.quantity + 1}');
      } else {
        _logger.log('Cannot add more ${product.productName} - max quantity reached');
      }
    } else {
      // Product doesn't exist, add it
      state = [...state, CartItem(product: product, quantity: 1)];
      _saveCart(); // Save cart after update
      _logger.log('Added new item to cart: ${product.productName}');
      
      // Track add to cart with Facebook Pixel
      _trackAddToCart(product, 1);
    }
  }

  // ENHANCED: Add item with specific quantity with session management
  void addItemWithQuantity(ProductModel product, int quantity) {
    // Mark cart as modified for session management
    _markCartAsModifiedAsync();
    
    final index = state.indexWhere((item) => item.product.pCode == product.pCode);
    if (index >= 0) {
      // Product exists, update with new quantity (limited by max allowed)
      final existingItem = state[index];
      final actualQuantity = quantity.clamp(1, product.maxQuantityAllowed);
      
      final updatedItems = [...state];
      updatedItems[index] = existingItem.copyWith(
        product: product,
        quantity: actualQuantity,
      );
      state = updatedItems;
      _logger.log('Updated ${product.productName} quantity to $actualQuantity');
    } else {
      // Product doesn't exist, add it with the specified quantity
      final actualQuantity = quantity.clamp(1, product.maxQuantityAllowed);
      state = [...state, CartItem(product: product, quantity: actualQuantity)];
      _logger.log('Added ${product.productName} with quantity $actualQuantity');
      
      // Track add to cart with Facebook Pixel
      _trackAddToCart(product, actualQuantity);
    }
    _saveCart(); // Save cart after update
  }

  // Update product (used for price changes)
  void updateProduct(ProductModel oldProduct, ProductModel newProduct) {
    final index = state.indexWhere((item) => item.product.pCode == oldProduct.pCode);
    if (index >= 0) {
      final existingItem = state[index];
      final updatedItems = [...state];
      updatedItems[index] = existingItem.copyWith(
        product: newProduct,
      );
      state = updatedItems;
      _saveCart(); // Save cart after update
      _logger.log('Updated product info for ${newProduct.productName}');
    }
  }

  // ENHANCED: Increment quantity with session management
  void incrementQuantity(ProductModel product) {
    // Mark cart as modified for session management
    _markCartAsModifiedAsync();
    
    final index = state.indexWhere((item) => item.product.pCode == product.pCode);
    if (index >= 0) {
      final existingItem = state[index];
      if (existingItem.quantity < product.maxQuantityAllowed) {
        final updatedItems = [...state];
        updatedItems[index] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
        );
        state = updatedItems;
        _saveCart(); // Save cart after update
        _logger.log('Incremented ${product.productName} to ${existingItem.quantity + 1}');
      } else {
        _logger.log('Cannot increment ${product.productName} - max quantity reached');
      }
    }
  }

  // ENHANCED: Decrement quantity with session management
  void decrementQuantity(ProductModel product) {
    // Mark cart as modified for session management
    _markCartAsModifiedAsync();
    
    final index = state.indexWhere((item) => item.product.pCode == product.pCode);
    if (index >= 0) {
      final existingItem = state[index];
      if (existingItem.quantity > 1) {
        final updatedItems = [...state];
        updatedItems[index] = existingItem.copyWith(
          quantity: existingItem.quantity - 1,
        );
        state = updatedItems;
        _saveCart(); // Save cart after update
        _logger.log('Decremented ${product.productName} to ${existingItem.quantity - 1}');
      } else {
        // Remove item if quantity becomes 0
        removeItem(product);
      }
    }
  }

  // ENHANCED: Remove item with session management
  void removeItem(ProductModel product) {
    // Mark cart as modified for session management
    _markCartAsModifiedAsync();
    
    state = state.where((item) => item.product.pCode != product.pCode).toList();
    _saveCart(); // Save cart after update
    _logger.log('Removed ${product.productName} from cart');
  }

  // FIXED: Clear cart with proper session cleanup
  Future<void> clearCart({bool clearCartKeyInStorage = false}) async {
    try {
      // Mark cart as modified for session management
      await _markCartAsModified();
      
      // Clear cart items in state
      state = [];
      
      // Clear cart data from persistent storage
      await _cartStorage.clearCart();
      
      // FIXED: Always create new session after cart clear to prepare for next order
      await _sessionManager.createNewOrderSession();
      
      if (clearCartKeyInStorage) {
        try {
          final cartValidator = _ref.read(cartValidatorProvider);
          await cartValidator.clearCartData();
          _logger.log('Cart and cart key completely cleared');
        } catch (e) {
          _logger.error('Error clearing cart key: $e');
        }
      }
      
      _logger.log('Cart cleared and new session created for next order');
      
    } catch (e) {
      _logger.error('Error clearing cart: $e');
    }
  }
  
  // Apply validation changes automatically
  void applyValidationChanges({
    required List<ProductModel> removeItems,
    required Map<String, double> priceUpdates,
  }) {
    // Create a new list to hold updated items
    List<CartItem> updatedCart = [];
    
    // Process each item in the cart
    for (final item in state) {
      // Check if this item should be removed (out of stock)
      if (removeItems.any((product) => product.pCode == item.product.pCode)) {
        // Skip this item (effectively removing it)
        _logger.log('Removing ${item.product.productName} due to validation');
        continue;
      }
      
      // Check if this item needs a price update
      if (priceUpdates.containsKey(item.product.pCode)) {
        final newPrice = priceUpdates[item.product.pCode]!;
        // Create updated product with new price
        final updatedProduct = item.product.copyWith(ourPrice: newPrice);
        // Add to updated cart with the new product but same quantity
        updatedCart.add(CartItem(
          product: updatedProduct,
          quantity: item.quantity,
        ));
        _logger.log('Updated price for ${item.product.productName} to ₹$newPrice');
      } else {
        // No changes needed, keep as is
        updatedCart.add(item);
      }
    }
    
    // Update the state with the new cart
    state = updatedCart;
    _saveCart(); // Save cart after update
    _logger.log('Applied validation changes to cart');
  }
  
  // Apply validation result auto-updates
  void applyValidationResult(CartValidationResult result) {
    if (!result.hasChanges) return;
    
    // 1. Handle Removed Items
    for (final removed in result.removedItems) {
      removeItem(removed.product);
    }
    
    // 2. Handle Price Changes
    for (final changed in result.priceChangedItems) {
      final index = state.indexWhere((item) => item.product.pCode == changed.product.pCode);
      if (index >= 0) {
        final existingItem = state[index];
        final updatedItems = [...state];
        updatedItems[index] = existingItem.copyWith(
          product: existingItem.product.copyWith(ourPrice: changed.newPrice),
        );
        state = updatedItems;
      }
    }
    
    // 3. Handle Quantity Changes
    for (final changed in result.quantityChangedItems) {
      final index = state.indexWhere((item) => item.product.pCode == changed.product.pCode);
       if (index >= 0) {
          if (changed.newQuantity > 0) {
               final existingItem = state[index];
               final updatedItems = [...state];
               updatedItems[index] = existingItem.copyWith(
                  quantity: changed.newQuantity
               );
               state = updatedItems;
          } else {
              removeItem(changed.product);
          }
       }
    }
    
    _saveCart();
    _logger.log('Applied auto-updates from validation result');
  }
  
  // Get the expiration time of the cart session in days
  int get sessionExpirationDays => _cartStorage.sessionExpirationDays;
  
  // Get the remaining session time in milliseconds
  int getRemainingSessionTime() {
    return _cartStorage.getRemainingSessionTime();
  }
  
  // Refresh the cart session (extend expiration)
  Future<bool> refreshSession() async {
    return await _cartStorage.refreshCartSession();
  }

  // ENHANCED SESSION MANAGEMENT METHODS

  // Mark cart as modified (handles session management)
  Future<void> _markCartAsModified() async {
    try {
      await _sessionManager.updateCartModification();
      
      // Check if session needs to be reset
      final isSessionValid = await _sessionManager.isCartSessionValid();
      if (!isSessionValid) {
        _logger.log('Cart session invalid - resetting session due to cart modification');
        await _sessionManager.resetCartSession();
      }
      
    } catch (e) {
      _logger.error('Error marking cart as modified: $e');
    }
  }

  // Async version for non-async methods
  void _markCartAsModifiedAsync() {
    // Run async operation without waiting
    Future.microtask(() async {
      await _markCartAsModified();
    });
  }

  // FIXED: Mark order as processing with proper session validation
  Future<void> markOrderAsProcessing() async {
    try {
      // Ensure we have valid session before marking as processing
      final sessionValid = await _sessionManager.isCartSessionValid();
      if (!sessionValid) {
        _logger.warning('Session invalid when marking as processing - creating new session');
        await _sessionManager.createNewOrderSession();
      }
      
      final prefs = await SharedPreferences.getInstance();
      final tempOrderId = prefs.getString('temp_order_id');
      
      if (tempOrderId != null) {
        await _sessionManager.markOrderAsProcessing(tempOrderId);
        _logger.log('Order marked as processing: $tempOrderId');
      } else {
        _logger.warning('No temp order ID found when marking as processing');
        // Force create new session if missing temp order ID
        await _sessionManager.createNewOrderSession();
      }
    } catch (e) {
      _logger.error('Error marking order as processing: $e');
    }
  }

  // Mark order as payment processing
  Future<void> markOrderAsPaymentProcessing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tempOrderId = prefs.getString('temp_order_id');
      
      if (tempOrderId != null) {
        await _sessionManager.markOrderAsPaymentProcessing(tempOrderId);
        _logger.log('Order marked as payment processing: $tempOrderId');
      } else {
        _logger.warning('No temp order ID found when marking as payment processing');
      }
    } catch (e) {
      _logger.error('Error marking order as payment processing: $e');
    }
  }

  // FIXED: Mark order as completed (automatically creates new session)
  Future<void> markOrderAsCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tempOrderId = prefs.getString('temp_order_id');
      
      if (tempOrderId != null) {
        await _sessionManager.markOrderAsCompleted(tempOrderId);
        _logger.log('Order marked as completed: $tempOrderId');
        _logger.log('New session automatically created for next order');
      } else {
        _logger.warning('No temp order ID found when marking as completed');
        // Create new session anyway
        await _sessionManager.createNewOrderSession();
      }
    } catch (e) {
      _logger.error('Error marking order as completed: $e');
    }
  }

  // FIXED: Mark order as failed (automatically creates new session)
  Future<void> markOrderAsFailed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tempOrderId = prefs.getString('temp_order_id');
      
      if (tempOrderId != null) {
        await _sessionManager.markOrderAsFailed(tempOrderId);
        _logger.log('Order marked as failed: $tempOrderId');
        _logger.log('New session automatically created for retry');
      } else {
        _logger.warning('No temp order ID found when marking as failed');
        // Create new session anyway
        await _sessionManager.createNewOrderSession();
      }
    } catch (e) {
      _logger.error('Error marking order as failed: $e');
    }
  }

  // Reset cart session manually
  Future<void> resetCartSession() async {
    try {
      await _sessionManager.resetCartSession();
      _logger.log('Cart session manually reset');
    } catch (e) {
      _logger.error('Error resetting cart session: $e');
    }
  }

  // Get current session state
  Future<String> getSessionState() async {
    try {
      return await _sessionManager.getOrderProcessingState();
    } catch (e) {
      _logger.error('Error getting session state: $e');
      return 'unknown';
    }
  }

  // Check if session is valid
  Future<bool> isSessionValid() async {
    try {
      return await _sessionManager.isCartSessionValid();
    } catch (e) {
      _logger.error('Error checking session validity: $e');
      return false;
    }
  }

  // Force refresh cart session
  Future<void> forceRefreshSession() async {
    try {
      await _sessionManager.forceCleanupAndCreateNew();
      _logger.log('Cart session force refreshed with completely new identifiers');
    } catch (e) {
      _logger.error('Error force refreshing session: $e');
    }
  }

  // FIXED: Prepare cart for new order placement
  Future<Map<String, String?>> prepareForNewOrder() async {
    try {
      _logger.log('=== PREPARING CART FOR NEW ORDER ===');
      
      // Ensure cart has items
      if (state.isEmpty) {
        _logger.warning('Cannot prepare for order - cart is empty');
        return {
          'temp_order_id': null,
          'cart_key': null,
          'device_id': null,
        };
      }
      
      // Create completely new session for this order
      await _sessionManager.createNewOrderSession();
      
      // Get the fresh identifiers
      final prefs = await SharedPreferences.getInstance();
      final tempOrderId = prefs.getString('temp_order_id');
      final cartKey = prefs.getString('cart_key');
      final deviceId = prefs.getString('device_id');
      
      _logger.log('Cart prepared for new order:');
      _logger.log('- Items: ${state.length}');
      _logger.log('- Fresh Temp Order ID: $tempOrderId');
      _logger.log('- Fresh Cart Key: $cartKey');
      _logger.log('- Device ID: $deviceId');
      
      return {
        'temp_order_id': tempOrderId,
        'cart_key': cartKey,
        'device_id': deviceId,
      };
    } catch (e) {
      _logger.error('Error preparing cart for new order: $e');
      return {
        'temp_order_id': null,
        'cart_key': null,
        'device_id': null,
      };
    }
  }

  // Check if cart is ready for order placement
  Future<bool> isReadyForOrderPlacement() async {
    try {
      // Check if cart has items
      if (state.isEmpty) {
        _logger.log('Cart not ready - no items');
        return false;
      }
      
      // Check if session is valid
      final sessionValid = await _sessionManager.isCartSessionValid();
      if (!sessionValid) {
        _logger.log('Cart not ready - invalid session');
        return false;
      }
      
      // Check session state
      final sessionState = await _sessionManager.getOrderProcessingState();
      if (sessionState == CartSessionManager.stateProcessing ||
          sessionState == CartSessionManager.statePaymentProcessing ||
          sessionState == CartSessionManager.stateCompleted) {
        _logger.log('Cart not ready - order already in progress ($sessionState)');
        return false;
      }
      
      _logger.log('Cart is ready for order placement');
      return true;
    } catch (e) {
      _logger.error('Error checking if cart is ready: $e');
      return false;
    }
  }

  // FIXED: Enhanced session debug info
  Future<Map<String, dynamic>> getSessionDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionInfo = await _sessionManager.getSessionInfo();
      
      return {
        ...sessionInfo,
        'cart_items_count': state.length,
        'cart_total': state.fold(0.0, (sum, item) => sum + item.totalPrice),
        'cart_savings': state.fold(0.0, (sum, item) => sum + item.savings),
        'cart_items': state.map((item) => {
          'product_name': item.product.productName,
          'quantity': item.quantity,
          'price': item.product.ourPrice,
          'total': item.totalPrice,
        }).toList(),
      };
    } catch (e) {
      _logger.error('Error getting session debug info: $e');
      return {'error': e.toString()};
    }
  }

  // Get cart summary for order placement
  Map<String, dynamic> getCartSummary() {
    final total = state.fold(0.0, (sum, item) => sum + item.totalPrice);
    final totalMrp = state.fold(0.0, (sum, item) => sum + item.totalMrp);
    final savings = totalMrp - total;
    final itemCount = state.fold(0, (sum, item) => sum + item.quantity);
    
    return {
      'total_items': state.length,
      'total_quantity': itemCount,
      'total_price': total,
      'total_mrp': totalMrp,
      'total_savings': savings,
      'formatted_total': '₹${total.toStringAsFixed(2)}',
      'formatted_savings': '₹${savings.toStringAsFixed(2)}',
      'items': state.map((item) => {
        'pcode': item.product.pCode,
        'name': item.product.productName,
        'quantity': item.quantity,
        'price': item.product.ourPrice,
        'total': item.totalPrice,
      }).toList(),
    };
  }
  
  // Track add to cart events with Facebook Pixel
  void _trackAddToCart(ProductModel product, int quantity) {
    try {
      // Use the Facebook Pixel service directly since we don't have WidgetRef here
      final facebookPixel = _ref.read(facebookPixelProvider);
      facebookPixel.trackAddToCart(
        productId: product.pCode,
        productName: product.productName,
        quantity: quantity,
        price: product.ourPrice,
        category: product.categoryId,
      );
    } catch (e) {
      _logger.error('Failed to track add to cart event: $e');
    }
  }
}

// Cart provider - updated to pass Ref and CartStorageService to CartNotifier
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final cartStorage = ref.watch(cartStorageServiceProvider);
  return CartNotifier(ref, cartStorage);
});

// Cart total provider
final cartTotalProvider = Provider<double>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.fold(0, (total, item) => total + item.totalPrice);
});

// Cart MRP total provider
final cartMrpTotalProvider = Provider<double>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.fold(0, (total, item) => total + item.totalMrp);
});

// Cart savings provider
final cartSavingsProvider = Provider<double>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.fold(0, (total, item) => total + item.savings);
});

// Cart count provider
final cartCountProvider = Provider<int>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.length;
});

// Cart item count provider (total quantity)
final cartItemCountProvider = Provider<int>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.fold(0, (total, item) => total + item.quantity);
});

// Cart validator provider
final cartValidatorProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return CartValidator(logger: logger);
});

// Helper providers for cart session management

// Provider to get current session state
final cartSessionStateProvider = FutureProvider<String>((ref) async {
  final cartNotifier = ref.watch(cartProvider.notifier);
  return await cartNotifier.getSessionState();
});

// Provider to check if session is valid
final cartSessionValidityProvider = FutureProvider<bool>((ref) async {
  final cartNotifier = ref.watch(cartProvider.notifier);
  return await cartNotifier.isSessionValid();
});

// Provider for session debug info
final cartSessionDebugProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final cartNotifier = ref.watch(cartProvider.notifier);
  return await cartNotifier.getSessionDebugInfo();
});

// Provider to check if cart is empty
final isCartEmptyProvider = Provider<bool>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.isEmpty;
});

// Provider to check if cart is ready for order placement
final cartReadyForOrderProvider = FutureProvider<bool>((ref) async {
  final cartNotifier = ref.watch(cartProvider.notifier);
  return await cartNotifier.isReadyForOrderPlacement();
});

// Provider to get cart summary
final cartSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final cartItems = ref.watch(cartProvider);
  final cartNotifier = ref.watch(cartProvider.notifier);
  
  if (cartItems.isEmpty) {
    return {
      'total': 0.0,
      'savings': 0.0,
      'count': 0,
      'item_count': 0,
      'is_empty': true,
      'formatted_total': '₹0.00',
      'formatted_savings': '₹0.00',
    };
  }
  
  return cartNotifier.getCartSummary();
});

// Provider for cart preparation for new order
final cartOrderPreparationProvider = FutureProvider<Map<String, String?>>((ref) async {
  final cartNotifier = ref.watch(cartProvider.notifier);
  return await cartNotifier.prepareForNewOrder();
});

// ─── Offer Slab System (API-driven) ───

class OfferSlab {
  final double threshold; // min_order_value
  final double discount;
  final String offerHeadingText; // offer_heading_text from API
  final String offerName; // offer_name from API
  final String offerConditionText; // offer_condition_text from API
  final String offerStatus; // offer_status from API
  final String progressFillColor; // offer_progress_fill_color from API
  final String lockedBadgeColor;
  final String unlockedBadgeColor;

  const OfferSlab({
    required this.threshold,
    required this.discount,
    this.offerHeadingText = '',
    this.offerName = '',
    this.offerConditionText = '',
    this.offerStatus = '',
    this.progressFillColor = '#4CAF50',
    this.lockedBadgeColor = '#CCCCCC',
    this.unlockedBadgeColor = '#4CAF50',
  });
}

class OfferSlabStatus {
  final OfferSlab slab;
  final bool unlocked;
  final bool isNext;
  final double progress;
  final double remaining;
  const OfferSlabStatus({
    required this.slab,
    required this.unlocked,
    required this.isNext,
    required this.progress,
    required this.remaining,
  });
}

// Provider that builds offer slabs from API data (stealDealsOffersProvider)
final offerSlabsProvider = Provider<List<OfferSlab>>((ref) {
  final offersAsync = ref.watch(stealDealsOffersProvider);
  final offers = offersAsync.valueOrNull;

  if (offers == null || offers.isEmpty) {
    return [];
  }

  return offers.map((offer) {
    return OfferSlab(
      threshold: offer.minOrderValue,
      discount: double.tryParse(
              offer.offer['offer_coupon_value']?.toString() ?? '0') ??
          0,
      offerHeadingText: offer.offerHeadingText,
      offerName: offer.offerName,
      offerConditionText: offer.offerConditionText,
      offerStatus: offer.offerStatus,
      progressFillColor: offer.progressFillColor,
      lockedBadgeColor: offer.lockedBadgeColor,
      unlockedBadgeColor: offer.unlockedBadgeColor,
    );
  }).toList();
});

// Next offer slab provider - used by persistent cart bar teaser
final nextOfferSlabProvider = Provider<OfferSlabStatus?>((ref) {
  final cartTotal = ref.watch(cartTotalProvider);
  final slabs = ref.watch(offerSlabsProvider);

  if (slabs.isEmpty) return null;

  for (int i = 0; i < slabs.length; i++) {
    final slab = slabs[i];
    if (cartTotal < slab.threshold) {
      final prevThreshold = i > 0 ? slabs[i - 1].threshold : 0.0;
      final range = slab.threshold - prevThreshold;
      final progress = range > 0 ? ((cartTotal - prevThreshold) / range).clamp(0.0, 1.0) : 0.0;
      final remaining = slab.threshold - cartTotal;
      return OfferSlabStatus(
        slab: slab,
        unlocked: false,
        isNext: true,
        progress: progress,
        remaining: remaining,
      );
    }
  }
  return null; // All slabs unlocked
});

// Full offer slabs status provider - used by offers bottom sheet
final offerSlabsStatusProvider = Provider<List<OfferSlabStatus>>((ref) {
  final cartTotal = ref.watch(cartTotalProvider);
  final slabs = ref.watch(offerSlabsProvider);

  if (slabs.isEmpty) return [];

  bool foundNext = false;
  return slabs.asMap().entries.map((entry) {
    final i = entry.key;
    final slab = entry.value;
    final unlocked = cartTotal >= slab.threshold;
    final isNext = !unlocked && !foundNext;
    if (isNext) foundNext = true;

    final prevThreshold = i > 0 ? slabs[i - 1].threshold : 0.0;
    final range = slab.threshold - prevThreshold;
    double progress = 0.0;
    if (unlocked) {
      progress = 1.0;
    } else if (isNext && range > 0) {
      progress = ((cartTotal - prevThreshold) / range).clamp(0.0, 1.0);
    }
    final remaining = unlocked ? 0.0 : slab.threshold - cartTotal;

    return OfferSlabStatus(
      slab: slab,
      unlocked: unlocked,
      isNext: isNext,
      progress: progress,
      remaining: remaining,
    );
  }).toList();
});

/// Auto-removes offer products from cart when their offer locks back.
/// This provider should be watched from a top-level widget (e.g. home screen).
final offerProductAutoRemovalProvider = Provider<void>((ref) {
  final unlockedCodes = ref.watch(offerProductCodesProvider);
  final allOfferCodes = ref.watch(allOfferProductCodesProvider);
  final cartItems = ref.read(cartProvider);

  // Find cart items that are offer products but no longer unlocked
  final toRemove = cartItems.where((item) {
    final pCode = item.product.pCode;
    // It's an offer product (in any offer) but not in unlocked set
    return allOfferCodes.contains(pCode) && !unlockedCodes.contains(pCode);
  }).toList();

  if (toRemove.isNotEmpty) {
    // Schedule removal after current frame to avoid modification during build
    Future.microtask(() {
      for (final item in toRemove) {
        ref.read(cartProvider.notifier).removeItem(item.product);
      }
    });
  }
});