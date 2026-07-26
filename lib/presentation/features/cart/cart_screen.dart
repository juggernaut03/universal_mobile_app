// lib/presentation/features/cart/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../presentation/widgets/back_button_wrapper.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/cart_validator.dart';
import '../../providers/cart_provider.dart';
import '../../providers/cart_validator_provider.dart';
import '../../providers/outlet_provider.dart';
import 'widgets/cart_item_widget.dart';
import 'widgets/tabbed_offers_widget.dart';
import 'widgets/cart_validation_dialog.dart';
import 'package:patelmart/presentation/providers/cart_validator_provider.dart' as validator;
import '../../../di/auth_providers.dart';
import '../../../di/infrastructure_providers.dart';
import '../../providers/cart_validation_policy_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({Key? key}) : super(key: key);

  // Custom back navigation handler - matches the pattern from category screen
  Future<bool> _handleBackPress(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on CartScreen - navigating to home');
    
    try {
      // Navigate to home using go
      context.go('/home');
      
      // Return false to prevent default back navigation
      return false;
    } catch (e) {
      logger.error('Error handling back navigation: $e');
      // If go fails, try push as fallback
      if (context.mounted) {
        context.pushReplacement('/home');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-remove offer products when their offer locks back
    ref.watch(offerProductAutoRemovalProvider);

    final cartItems = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final cartSavings = ref.watch(cartSavingsProvider);
    final cartValidationState = ref.watch(cartValidationStateProvider);
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    
    // Minimum order value comes from the outlet. There is no default: a cart
    // cannot be judged before its store is known, and the previous fallback of
    // 499.0 was a threshold invented in this widget.
    final minimumOrderValue =
        selectedOutletAsync.valueOrNull?.minOrderAmount.toDouble() ?? 0.0;

    // Checkout eligibility now comes from the single CartValidationPolicy,
    // which also covers stock, outlet trading state and an empty cart — none of
    // which this screen used to check.
    final canCheckout = ref.watch(canCheckoutProvider);
    
    // Back in stock items (mock data for demonstration)
    final backInStockItems = 2;
    
    // Saved for later items (mock data for demonstration)
    final savedItems = 1;
    
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted on CartScreen - going to home');
          
          // Navigate to home
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: () => _handleBackPress(context, ref),
        child: BackButtonWrapper(
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildEnhancedAppBar(context, ref),
            body: Column(
              children: [
                // Add the Cart Session Info Widget for visual feedback on session state
                
                // Cart Summary section
                _buildCartSummary(context, cartSavings, cartTotal),
                
                // Divider
                const Divider(height: 1),
                
                // Main content - scrollable
                Expanded(
                  child: cartItems.isEmpty
                      ? _buildEmptyCart(context)
                      : _buildCartContent(context, ref, cartItems, backInStockItems, savedItems),
                ),
                
                // Checkout button
                if (cartItems.isNotEmpty)
                  _buildCheckoutButton(
                    context, 
                    ref,
                    canCheckout: canCheckout, 
                    cartTotal: cartTotal,
                    cartValidationState: cartValidationState,
                    minimumOrderValue: minimumOrderValue,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final logger = ref.read(loggerProvider);
    
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          logger.log('Cart back button pressed');
          // Use the same navigation logic as the hardware back button
          _handleBackPress(context, ref);
        },
      ),
      title: const Text(
        'Cart',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: true,
      actions: [
        // Favorites/Wishlist icon
        IconButton(
          icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
          onPressed: () {
            logger.log('Favorites button pressed from cart');
            context.push('/favorites');
          },
          tooltip: 'View Favorites',
        ),
        
        // Simplified Cart icon with only quantity badge
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              onPressed: () {
                // Already in cart screen, show current cart status
                if (cartCount > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You have ${cartCount} item${cartCount > 1 ? 's' : ''} in your cart (₹${cartTotal.toStringAsFixed(cartTotal.truncateToDouble() == cartTotal ? 0 : 2)})',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your cart is empty'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.grey,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              tooltip: 'Cart Summary',
            ),
            
            // Simple quantity badge - only shows count
            if (cartCount > 0)
              Positioned(
                top: 4,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    cartCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(width: 8),
      ],
    );
  }

  /// Format cart total for display in badge
  String _formatCartTotal(double total) {
    if (total >= 1000) {
      // Show in K format for values >= 1000
      return '${(total / 1000).toStringAsFixed(total % 1000 == 0 ? 0 : 1)}K';
    } else {
      // Show full amount for values < 1000
      return total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2);
    }
  }

  Widget _buildCartSummary(BuildContext context, double savings, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        children: [
          // Savings and total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Savings ₹${savings.toStringAsFixed(savings.truncateToDouble() == savings ? 0 : 2)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Cart Total ₹${total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2)}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Offer note
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All offers will be applied on checkout',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.neutral400,
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: AppTextStyles.h5,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to your cart to proceed with checkout',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Continue Shopping',
              style: AppTextStyles.buttonMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(
    BuildContext context, 
    WidgetRef ref,
    List<CartItem> cartItems, 
    int backInStockItems,
    int savedItems,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80), // Space for checkout button
      child: Column(
        children: [
          // Offers section at the top - tabbed layout
          const RepaintBoundary(
            child: TabbedOffersWidget(),
          ),

          // Cart items
          ...cartItems.map((item) => CartItemWidget(
            cartItem: item,
            onIncrementQuantity: () {
              ref.read(cartProvider.notifier).incrementQuantity(item.product);
            },
            onDecrementQuantity: () {
              ref.read(cartProvider.notifier).decrementQuantity(item.product);
            },
            onRemove: () {
              ref.read(cartProvider.notifier).removeItem(item.product);
              
              // Show confirmation of item removal
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.product.productName} removed from cart'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      // Add the item back to cart
                      ref.read(cartProvider.notifier).addItemWithQuantity(
                        item.product, 
                        item.quantity
                      );
                    },
                  ),
                ),
              );
            },
          )),
          
          // Remove all button
          if (cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    _showClearCartDialog(context, ref);
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 18,
                  ),
                  label: Text(
                    'Remove all',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ),
          
          const Divider(),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    // Store the current cart items in case the user decides to undo
    final currentCartItems = List<CartItem>.from(ref.read(cartProvider));
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Cart'),
          content: const Text('Are you sure you want to remove all items from your cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                // Clear the cart
                ref.read(cartProvider.notifier).clearCart();
                Navigator.of(context).pop();
                
                // Show confirmation with UNDO option
                if (currentCartItems.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Cart cleared'),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () {
                          // Restore all items
                          for (final item in currentCartItems) {
                            ref.read(cartProvider.notifier).addItemWithQuantity(
                              item.product,
                              item.quantity,
                            );
                          }
                        },
                      ),
                    ),
                  );
                }
              },
              child: const Text('CLEAR'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    WidgetRef ref, {
    required bool canCheckout,
    required double cartTotal,
    required CartValidationState cartValidationState,
    required double minimumOrderValue,
  }) {
    final isLoading = cartValidationState == CartValidationState.loading;
    
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show min order message if needed
          if (!canCheckout)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Add items worth ₹${(minimumOrderValue - cartTotal).toStringAsFixed((minimumOrderValue - cartTotal).truncateToDouble() == (minimumOrderValue - cartTotal) ? 0 : 2)} more to place order',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading || !canCheckout ? null : () {
                // Refresh cart session before checkout to extend it
                ref.read(cartProvider.notifier).refreshSession();
                
                // Reset retry count before starting checkout
                ref.read(validationRetryCountProvider.notifier).state = 0;
                _proceedToCheckout(context, ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: canCheckout ? AppColors.primary : AppColors.neutral300,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading 
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'PROCEED TO CHECKOUT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _proceedToCheckout(BuildContext context, WidgetRef ref) async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty. Add items to proceed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final selectedOutletAsync = ref.read(selectedOutletProvider);
    final cartValidationNotifier = ref.read(cartValidationStateProvider.notifier);
    
    // Get current retry count
    final retryCount = ref.read(validationRetryCountProvider);
    
    // Get the store code from the selected outlet
    final storeCode = selectedOutletAsync.value?.storeCode ?? 'KLW'; // Default store code
    
    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validating your cart...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    
    // Validate the cart
    final validationResult = await cartValidationNotifier.validateCart(
      cartItems, 
      storeCode,
      retryCount,
    );
    
    // Increment retry count for next time
    ref.read(validationRetryCountProvider.notifier).state = retryCount + 1;
    
    // Remove any existing snackbars
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    
    // Check if we have a result and the context is still valid
    if (validationResult != null && context.mounted) {
      // Check if max retries reached
      if (validationResult.maxRetriesReached) {
        await _handleMaxRetriesReached(context, ref);
        return;
      }
      
      // Always show validation dialog if the validation result indicates issues or changes
      if (validationResult.hasChanges || !validationResult.isValid) {
        // Show validation dialog for changes
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => CartValidationDialog(
            result: validationResult,
            onContinue: () {
              // Only proceed if validation was ultimately successful
              if (validationResult.isValid) {
                Navigator.pop(dialogContext);
                _continueToCheckout(context, ref);
              } else {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please update your cart before proceeding'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            onUpdateCart: () {
              // Close dialog and update cart based on validation
              Navigator.pop(dialogContext);
              _autoUpdateCartBasedOnValidation(context, ref, validationResult);
            },
          ),
        );
      } else {
        // Both hasChanges is false AND isValid is true - safe to proceed
        _continueToCheckout(context, ref);
      }
    } else {
      if (context.mounted) {
        // Error occurred during validation
        final errorMessage = cartValidationNotifier.errorMessage ?? 'Failed to validate cart';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Handle the case when we've reached maximum retries
  Future<void> _handleMaxRetriesReached(BuildContext context, WidgetRef ref) async {
    final cartNotifier = ref.read(cartProvider.notifier);
    
    // Take more drastic action - remove items or reduce quantities
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;
    
    // Start with reducing quantities of all items
    bool madeChanges = false;
    
    // 1. For items with quantities > 2, reduce by half
    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];
      if (item.quantity > 2) {
        final newQuantity = item.quantity ~/ 2;
        
        // Remove and add back with reduced quantity
        cartNotifier.removeItem(item.product);
        cartNotifier.addItemWithQuantity(item.product, newQuantity);
        madeChanges = true;
      }
    }
    
    // 2. If we have more than 1 item in the cart, remove all but first
    if (!madeChanges && cartItems.length > 1) {
      final firstItem = cartItems.first;
      cartNotifier.clearCart();
      cartNotifier.addItemWithQuantity(firstItem.product, firstItem.quantity);
      madeChanges = true;
    }
    
    // 3. If still not made changes and only 1 item, reduce quantity to 1
    if (!madeChanges && cartItems.length == 1 && cartItems[0].quantity > 1) {
      final item = cartItems[0];
      cartNotifier.removeItem(item.product);
      cartNotifier.addItemWithQuantity(item.product, 1);
      madeChanges = true;
    }
    
    // Notify user
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart has been modified to help with validation issues'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Reset retry count and try again with the modified cart
      ref.read(validationRetryCountProvider.notifier).state = 0;
      await Future.delayed(const Duration(milliseconds: 500));
      if (context.mounted) {
        _proceedToCheckout(context, ref);
      }
    }
  }
  
  void _continueToCheckout(BuildContext context, WidgetRef ref) async {
    // Reset retry count since we're proceeding
    ref.read(validationRetryCountProvider.notifier).state = 0;
    
    // Check if user is logged in
    final isLoggedIn = await ref.read(authRepositoryProvider).isSignedIn();
    
    if (context.mounted) {
      if (isLoggedIn) {
        // User is logged in, proceed to the new checkout flow
       context.push('/checkout-flow');
      } else {
        // User is not logged in, show login screen with redirect
        context.push(
          '/auth/login',
          extra: {'redirectRoute': '/checkout-flow'},
        );
      }
    }
  }
  
  void _autoUpdateCartBasedOnValidation(
    BuildContext context, 
    WidgetRef ref, 
    CartValidationResult result
  ) async {
    final cartNotifier = ref.read(cartProvider.notifier);
    final selectedOutletAsync = ref.read(selectedOutletProvider);
    final storeCode = selectedOutletAsync.value?.storeCode ?? 'KLW'; // Default store code
    
    // Track the changes we made
    bool madeChanges = false;
    
    // Check if this is a save error that requires a retry
    if (result.isSaveError) {
      // Show retry in progress
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retrying cart save operation...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // Retry saving the cart
       final cartValidator = ref.read(validator.cartValidatorProvider);
       final saveSuccess = await cartValidator.retrySaveCart(
        ref.read(cartProvider), 
        storeCode
      );
      
      if (saveSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cart updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Reset retry count and try proceeding again
          ref.read(validationRetryCountProvider.notifier).state = 0;
          
          // Try proceeding with checkout again after successful retry
          if (context.mounted) {
            _proceedToCheckout(context, ref);
          }
        }
        return;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update cart. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }
    
    // Gather items to remove and prices to update
    final List<ProductModel> itemsToRemove = [];
    final Map<String, double> priceUpdates = {};
    
    // 1. Process items that need to be removed
    if (result.removedItems.isNotEmpty) {
      for (final item in result.removedItems) {
        // Add to the items to remove list
        itemsToRemove.add(item.product);
        madeChanges = true;
      }
      
      // Show a single notification for all removed items
      if (context.mounted && result.removedItems.isNotEmpty) {
        final count = result.removedItems.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count ${count == 1 ? 'item' : 'items'} removed (out of stock)'
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    
    // 2. Process price changes
    if (result.priceChangedItems.isNotEmpty) {
      for (final item in result.priceChangedItems) {
        // Map the product code to its new price
        priceUpdates[item.product.pCode] = item.newPrice;
        madeChanges = true;
      }
      
      // Show notification for price updates
      if (context.mounted && result.priceChangedItems.isNotEmpty) {
        final count = result.priceChangedItems.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prices updated for $count ${count == 1 ? 'item' : 'items'}'
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    
    // 3. Process generic validation issues if we didn't make other changes
    if (!madeChanges && result.genericValidationItem != null) {
      final item = result.genericValidationItem!;
      
      // Try updating the quantity before the more drastic measures
      if (item.quantity > 1) {
        // Reduce quantity by 1
        cartNotifier.removeItem(item.product);
        cartNotifier.addItemWithQuantity(item.product, item.quantity - 1);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reduced quantity for ${item.product.productName} to address validation issues'
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        madeChanges = true;
      } else {
        // If quantity is already 1, mark for removal
        itemsToRemove.add(item.product);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Removed ${item.product.productName} to address validation issues'
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        madeChanges = true;
      }
    }
    
    // 4. Apply all changes in one operation if we made some
    if (itemsToRemove.isNotEmpty || priceUpdates.isNotEmpty) {
      // Apply the validation changes to the cart
      cartNotifier.applyValidationChanges(
        removeItems: itemsToRemove,
        priceUpdates: priceUpdates,
      );
      
      madeChanges = true;
    }
    
    // 5. Final case: if we still didn't make changes and the cart is invalid, 
    // take more drastic action by calling the max retries handler
    if (!madeChanges && !result.isValid) {
      await _handleMaxRetriesReached(context, ref);
      return;
    }
    
    // 6. Reset retry count since we made changes
    if (madeChanges) {
      ref.read(validationRetryCountProvider.notifier).state = 0;
      
      // If we made changes, try to checkout again after a short delay
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (context.mounted) {
        _proceedToCheckout(context, ref);
      }
    }
  }
  
  void _showMinOrderModal(BuildContext context, double minimumOrderValue) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Minimum Order Value Required',
                style: AppTextStyles.h5,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your cart value is under ₹${minimumOrderValue.toStringAsFixed(minimumOrderValue.truncateToDouble() == minimumOrderValue ? 0 : 2)}. Please add more items to proceed with checkout.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Close modal and navigate to home/products
                  Navigator.pop(context);
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'CONTINUE SHOPPING',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Just close the modal
                  Navigator.pop(context);
                },
                child: Text(
                  'CLOSE',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}