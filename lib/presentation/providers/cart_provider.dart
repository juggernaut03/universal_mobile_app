// lib/presentation/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/product_model.dart';
import '../../data/models/cart_item.dart';
import '../../data/services/cart_storage_service.dart';
import '../../data/services/cart_validator.dart';
import '../../data/services/cart_session_manager.dart';
import '../../di/service_providers.dart';
import '../../core/utils/logger.dart';
import 'steal_deals_provider.dart';
// FACEBOOK PIXEL IMPORTS
import '../../facebook_pixel/facebook_pixel_provider.dart';
import '../../di/infrastructure_providers.dart';
import '../../domain/entities/cart.dart';
import 'outlet_provider.dart';

export '../../data/models/cart_item.dart' show CartItem;

// CartItem moved to lib/data/models/cart_item.dart and re-exported below, so
// the many files importing it from here keep resolving.

// Provider for CartStorageService

// Provider for cart session manager
// cartSessionManagerProvider moved to lib/di/service_providers.dart

// Cart state notifier with enhanced session management
/// Holds the cart as a domain [Cart].
///
/// The state was `List<CartItem>` mutated in place, with the add/update rules
/// re-implemented in each method. Those rules now live on the entity, which
/// also fixes two of them:
///
///   * quantity was clamped to `maxQuantityAllowed` but not to actual stock,
///     so a cart could hold more than the store could supply;
///   * `quantity.clamp(1, maxQuantityAllowed)` throws ArgumentError when the
///     cap is 0, because Dart's clamp asserts upper >= lower.
///
/// Method signatures still take ProductModel so the 61 existing call sites are
/// unchanged; conversion happens here.
class CartNotifier extends StateNotifier<Cart> {
  // Store a reference to Ref for accessing other providers
  final Ref _ref;
  final CartStorageService _cartStorage;
  late final CartSessionManager _sessionManager;
  late final Logger _logger;

  /// Store the cart belongs to.
  ///
  /// Prices and stock are per-outlet, so a Cart is only meaningful for one
  /// store. Empty until an outlet is chosen, which is also when the cart is
  /// necessarily empty.
  String get _storeCode =>
      _ref.read(selectedOutletProvider).valueOrNull?.storeCode ?? '';
  
  CartNotifier(this._ref, this._cartStorage) : super(const Cart.empty('')) {
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
      state = items.toCart(_storeCode);
      
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
      await _cartStorage.saveCart(state.lines.map(CartItem.fromLine).toList());
    } catch (e) {
      _logger.error('Error saving cart: $e');
    }
  }

  // ENHANCED: Add item to cart with session management
  void addItem(ProductModel product) {
    _markCartAsModifiedAsync();

    final before = state.quantityOf(product.pCode);
    state = state.add(product.toEntity());
    final after = state.quantityOf(product.pCode);

    if (after == before) {
      _logger.log('Cannot add more ${product.productName} — limit reached');
      return;
    }
    _saveCart();
    _logger.log('Cart now holds $after x ${product.productName}');
    if (before == 0) _trackAddToCart(product, 1);
  }

  // ENHANCED: Add item with specific quantity with session management
  void addItemWithQuantity(ProductModel product, int quantity) {
    _markCartAsModifiedAsync();

    final before = state.quantityOf(product.pCode);
    // setQuantity clamps to what is purchasable and removes the line at zero,
    // rather than clamp(1, max) which throws when max is 0.
    state = state.setQuantity(product.toEntity(), quantity);
    final after = state.quantityOf(product.pCode);

    _saveCart();
    _logger.log('Set ${product.productName} to $after');
    if (before == 0 && after > 0) _trackAddToCart(product, after);
  }

  // Update product (used for price changes)
  void updateProduct(ProductModel oldProduct, ProductModel newProduct) {
    final quantity = state.quantityOf(oldProduct.pCode);
    if (quantity == 0) return;

    state = state
        .remove(oldProduct.pCode)
        .setQuantity(newProduct.toEntity(), quantity);
    _saveCart();
    _logger.log('Updated product info for ${newProduct.productName}');
  }

  // ENHANCED: Increment quantity with session management
  void incrementQuantity(ProductModel product) {
    _markCartAsModifiedAsync();

    final before = state.quantityOf(product.pCode);
    if (before == 0) return;

    state = state.setQuantity(product.toEntity(), before + 1);
    final after = state.quantityOf(product.pCode);
    if (after == before) {
      _logger.log('Cannot increment ${product.productName} — limit reached');
      return;
    }
    _saveCart();
    _logger.log('Incremented ${product.productName} to $after');
  }

  // ENHANCED: Decrement quantity with session management
  void decrementQuantity(ProductModel product) {
    _markCartAsModifiedAsync();

    if (state.quantityOf(product.pCode) == 0) return;

    // decrement drops the line when it would reach zero.
    state = state.decrement(product.pCode);
    _saveCart();
    _logger.log('Decremented ${product.productName}');
  }

  // ENHANCED: Remove item with session management
  void removeItem(ProductModel product) {
    _markCartAsModifiedAsync();

    state = state.remove(product.pCode);
    _saveCart();
    _logger.log('Removed ${product.productName} from cart');
  }

  // FIXED: Clear cart with proper session cleanup
  Future<void> clearCart({bool clearCartKeyInStorage = false}) async {
    try {
      // Mark cart as modified for session management
      await _markCartAsModified();
      
      // Clear cart items in state
      state = state.clear();
      
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
    var updated = state;

    for (final product in removeItems) {
      _logger.log('Removing ${product.productName} due to validation');
      updated = updated.remove(product.pCode);
    }

    priceUpdates.forEach((pCode, newPrice) {
      final line = updated.lineFor(pCode);
      if (line == null) return;
      updated = updated.setQuantity(
        line.product.copyWith(sellingPrice: newPrice),
        line.quantity,
      );
      _logger.log('Updated price for ${line.product.name} to ₹$newPrice');
    });

    state = updated;
    _saveCart();
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
      final line = state.lineFor(changed.product.pCode);
      if (line == null) continue;
      state = state.setQuantity(
        line.product.copyWith(sellingPrice: changed.newPrice),
        line.quantity,
      );
    }

    // 3. Handle Quantity Changes
    for (final changed in result.quantityChangedItems) {
      final line = state.lineFor(changed.product.pCode);
      if (line == null) continue;
      // setQuantity removes the line at zero, so the two cases collapse.
      state = state.setQuantity(line.product, changed.newQuantity);
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
      _logger.log('- Items: ${state.lineCount}');
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
      final sessionInfo = await _sessionManager.getSessionInfo();
      
      return {
        ...sessionInfo,
        'cart_items_count': state.lineCount,
        'cart_total': state.subtotal,
        'cart_savings': state.savings,
        'cart_items': state.lines.map((line) => {
          'product_name': line.product.name,
          'quantity': line.quantity,
          'price': line.product.sellingPrice,
          'total': line.total,
        }).toList(),
      };
    } catch (e) {
      _logger.error('Error getting session debug info: $e');
      return {'error': e.toString()};
    }
  }

  // Get cart summary for order placement
  Map<String, dynamic> getCartSummary() {
    // Totals come from the entity now; each of these was its own fold.
    final total = state.subtotal;
    final totalMrp = state.subtotalAtMrp;
    final savings = state.savings;
    final itemCount = state.itemCount;
    
    return {
      'total_items': state.lineCount,
      'total_quantity': itemCount,
      'total_price': total,
      'total_mrp': totalMrp,
      'total_savings': savings,
      'formatted_total': '₹${total.toStringAsFixed(2)}',
      'formatted_savings': '₹${savings.toStringAsFixed(2)}',
      'items': state.lines.map((line) => {
        'pcode': line.product.code,
        'name': line.product.name,
        'quantity': line.quantity,
        'price': line.product.sellingPrice,
        'total': line.total,
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
final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  final cartStorage = ref.watch(cartStorageServiceProvider);
  return CartNotifier(ref, cartStorage);
});

/// The cart's lines as DTOs.
///
/// Compatibility view for the screens still typed to `List<CartItem>`. They
/// read this instead of `cartProvider`, which now holds a domain [Cart].
final cartItemsProvider = Provider<List<CartItem>>((ref) {
  return ref.watch(cartProvider).lines.map(CartItem.fromLine).toList();
});

// Totals are computed on the entity, so there is one definition of each.
final cartTotalProvider =
    Provider<double>((ref) => ref.watch(cartProvider).subtotal);

final cartMrpTotalProvider =
    Provider<double>((ref) => ref.watch(cartProvider).subtotalAtMrp);

final cartSavingsProvider =
    Provider<double>((ref) => ref.watch(cartProvider).savings);

/// Distinct products in the cart.
final cartCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider).lineCount);

/// Total units — the badge number.
final cartItemCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider).itemCount);

// Cart validator provider
final cartValidatorProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  final apiClient = ref.watch(apiClientProvider);
  return CartValidator(logger: logger, apiClient: apiClient);
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
  final slabs = ref.watch(offerSlabsProvider);
  if (slabs.isEmpty) return null;

  // Find first locked slab — that's the next offer to unlock
  for (final slab in slabs) {
    final unlocked = slab.offerStatus.toLowerCase() == 'unlocked';
    if (!unlocked) {
      return OfferSlabStatus(
        slab: slab,
        unlocked: false,
        isNext: true,
        progress: 0.0,
        remaining: 0.0,
      );
    }
  }
  return null; // All slabs unlocked
});

// Full offer slabs status provider - used by offers bottom sheet
final offerSlabsStatusProvider = Provider<List<OfferSlabStatus>>((ref) {
  final slabs = ref.watch(offerSlabsProvider);
  if (slabs.isEmpty) return [];

  bool foundNext = false;
  return slabs.map((slab) {
    // Use offer_status from API as source of truth
    final unlocked = slab.offerStatus.toLowerCase() == 'unlocked';
    final isNext = !unlocked && !foundNext;
    if (isNext) foundNext = true;

    return OfferSlabStatus(
      slab: slab,
      unlocked: unlocked,
      isNext: isNext,
      progress: unlocked ? 1.0 : 0.0,
      remaining: 0.0,
    );
  }).toList();
});

/// Auto-removes offer products from cart when their offer locks back.
/// This provider should be watched from a top-level widget (e.g. home screen).
final offerProductAutoRemovalProvider = Provider<void>((ref) {
  final unlockedCodes = ref.watch(offerProductCodesProvider);
  final allOfferCodes = ref.watch(allOfferProductCodesProvider);
  final cartItems = ref.read(cartItemsProvider);

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