// lib/presentation/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';

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

// Cart state notifier
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

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
      }
    } else {
      // Product doesn't exist, add it
      state = [...state, CartItem(product: product, quantity: 1)];
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
      } else {
        // Remove item if quantity becomes 0
        removeItem(product);
      }
    }
  }

  // Remove item from cart
  void removeItem(ProductModel product) {
    state = state.where((item) => item.product.pCode != product.pCode).toList();
  }

  // Clear cart
  void clearCart() {
    state = [];
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
  }
}

// Cart provider
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
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