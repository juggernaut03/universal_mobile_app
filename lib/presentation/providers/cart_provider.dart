// lib/presentation/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/product_model.dart';
import '../../data/services/cart_storage_service.dart';
import '../../data/services/cart_validator.dart';
import '../../core/utils/logger.dart';
import 'launch_flow_provider.dart';

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

// Cart state notifier
class CartNotifier extends StateNotifier<List<CartItem>> {
  // Store a reference to Ref for accessing other providers
  final Ref _ref;
  final CartStorageService _cartStorage;
  
  CartNotifier(this._ref, this._cartStorage) : super([]) {
    // Load cart from persistent storage on initialization
    _loadCart();
  }

  // Load cart from persistent storage
  Future<void> _loadCart() async {
    try {
      final items = await _cartStorage.loadCart();
      state = items;
      
      // Refresh the cart session timestamp each time cart is loaded
      if (items.isNotEmpty) {
        await _cartStorage.refreshCartSession();
      }
      
      final logger = _ref.read(loggerProvider);
      logger.log('Loaded ${items.length} items from persistent cart storage');
    } catch (e) {
      final logger = _ref.read(loggerProvider);
      logger.error('Error loading cart: $e');
    }
  }
  
  // Save current cart state to persistent storage
  Future<void> _saveCart() async {
    try {
      await _cartStorage.saveCart(state);
    } catch (e) {
      final logger = _ref.read(loggerProvider);
      logger.error('Error saving cart: $e');
    }
  }

  // Add item to cart
  void addItem(ProductModel product) {
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
      }
    } else {
      // Product doesn't exist, add it
      state = [...state, CartItem(product: product, quantity: 1)];
      _saveCart(); // Save cart after update
    }
  }

  // Add item with specific quantity (used for cart updates)
  void addItemWithQuantity(ProductModel product, int quantity) {
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
    } else {
      // Product doesn't exist, add it with the specified quantity
      final actualQuantity = quantity.clamp(1, product.maxQuantityAllowed);
      state = [...state, CartItem(product: product, quantity: actualQuantity)];
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
    }
  }

  // Increment quantity
  void incrementQuantity(ProductModel product) {
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
      }
    }
  }

  // Decrement quantity
  void decrementQuantity(ProductModel product) {
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
      } else {
        // Remove item if quantity becomes 0
        removeItem(product);
      }
    }
  }

  // Remove item from cart
  void removeItem(ProductModel product) {
    state = state.where((item) => item.product.pCode != product.pCode).toList();
    _saveCart(); // Save cart after update
  }

  // Clear cart and optionally clear cart key in storage
  Future<void> clearCart({bool clearCartKeyInStorage = false}) async {
    // Clear cart items in state
    state = [];
    
    // Clear cart data from persistent storage
    await _cartStorage.clearCart();
    
    // If requested, also clear the cart key in storage
    if (clearCartKeyInStorage) {
      try {
        // Access the CartValidator through ref
        final cartValidator = _ref.read(cartValidatorProvider);
        await cartValidator.clearCartData();
        
        // Log the complete cart clearing
        final logger = _ref.read(loggerProvider);
        logger.log('Cart and cart key completely cleared');
      } catch (e) {
        // Log error but don't fail the cart clearing operation
        final logger = _ref.read(loggerProvider);
        logger.error('Error clearing cart key: $e');
      }
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
      } else {
        // No changes needed, keep as is
        updatedCart.add(item);
      }
    }
    
    // Update the state with the new cart
    state = updatedCart;
    _saveCart(); // Save cart after update
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

// Cart validator provider
final cartValidatorProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return CartValidator(logger: logger);
});