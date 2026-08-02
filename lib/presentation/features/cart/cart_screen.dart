// lib/presentation/features/cart/cart_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:patelmart/core/utils/app_snackbar.dart';
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

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  /// The router for this screen, captured while the element is still active.
  ///
  /// `context.push`/`context.go` resolve GoRouter through the element tree, so
  /// navigating after an `await` — which the checkout flow does at every step —
  /// would hit the same deactivated-ancestor hazard. GoRouter itself is
  /// app-level, so the captured reference stays valid.
  ///
  /// Calls through this are deliberately NOT wrapped in a `context.mounted`
  /// check. It outlives this widget, so the guard protects nothing and instead
  /// silently swallows the action: guarding the push to `/checkout-flow` turned
  /// "checkout opens" into "the button does nothing" whenever the cart route
  /// had been torn down — which is what happens right after an order.
  GoRouter? _router;

  /// Navigator for this screen, captured for the same reason again.
  ///
  /// `showDialog(context: context)` resolves the Navigator through the element
  /// tree, so the validation dialog — which is only ever shown after awaiting
  /// the validation call — needs a context that is guaranteed still active.
  /// [NavigatorState.context] is exactly that.
  NavigatorState? _navigator;

  /// Last checkout-button state written to the debug log, so rebuilds that
  /// change nothing stay quiet. Debug-only.
  String? _lastLoggedButtonState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
    _navigator = Navigator.of(context, rootNavigator: true);
  }

  @override
  void initState() {
    super.initState();

    // A guest who tapped "Proceed to checkout" was sent to login and has landed
    // back here. Resume where they left off instead of making them find the
    // button again — and go through _proceedToCheckout, so the cart is still
    // validated before checkout opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!ref.read(pendingCheckoutProvider)) return;

      final signedIn = await ref.read(authRepositoryProvider).isSignedIn();
      if (!mounted) return;

      // Clear it either way: an abandoned login must not leave the cart primed
      // to launch checkout on some unrelated later visit.
      ref.read(pendingCheckoutProvider.notifier).state = false;
      if (signedIn) {
        _proceedToCheckout(ref);
      }
    });
  }

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
  Widget build(BuildContext context) {
    // Auto-remove offer products when their offer locks back
    ref.watch(offerProductAutoRemovalProvider);

    final cartItems = ref.watch(cartItemsProvider);
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
                  showAppSnackBar(
                    SnackBar(
                      content: Text(
                        'You have $cartCount item${cartCount > 1 ? 's' : ''} in your cart (₹${cartTotal.toStringAsFixed(cartTotal.truncateToDouble() == cartTotal ? 0 : 2)})',
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
                  showAppSnackBar(
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
              showAppSnackBar(
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
    final currentCartItems = List<CartItem>.from(ref.read(cartItemsProvider));
    
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
                  showAppSnackBar(
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

    // Why the button is disabled is otherwise invisible: `canCheckout` folds
    // together minimum order value, stock, outlet trading state and an empty
    // cart, and a disabled ElevatedButton looks identical whichever one it is.
    //
    // Logged only when the answer changes — build() runs on every cart and
    // provider tick, and a line per rebuild would bury the flow trace below.
    if (kDebugMode) {
      final state = '$canCheckout|$isLoading|$cartTotal|$minimumOrderValue';
      if (state != _lastLoggedButtonState) {
        _lastLoggedButtonState = state;
        print('[CHECKOUT BTN] enabled=${!isLoading && canCheckout} '
            '| canCheckout=$canCheckout | isLoading=$isLoading '
            '| cartTotal=$cartTotal | minOrder=$minimumOrderValue '
            '| validationState=$cartValidationState');
      }
    }

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
                if (kDebugMode) {
                  print('\n[CHECKOUT] ===== PROCEED TO CHECKOUT TAPPED =====');
                }
                // Refresh cart session before checkout to extend it
                ref.read(cartProvider.notifier).refreshSession();

                // Reset retry count before starting checkout
                ref.read(validationRetryCountProvider.notifier).state = 0;
                _proceedToCheckout(ref);
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
  
  Future<void> _proceedToCheckout(WidgetRef ref) async {
    // Every `return` below is a silent dead end from the shopper's side — the
    // button just stops doing anything. Each one announces itself so the log
    // says which gate closed.
    if (kDebugMode) {
      print('[CHECKOUT] _proceedToCheckout entered '
          '| widgetMounted=$mounted '
          '| router=${_router != null} | navigator=${_navigator != null}');
    }

    final cartItems = ref.read(cartItemsProvider);
    if (cartItems.isEmpty) {
      if (kDebugMode) print('[CHECKOUT] STOP: cart is empty');
      showAppSnackBar(
        const SnackBar(
          content: Text('Your cart is empty. Add items to proceed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (kDebugMode) print('[CHECKOUT] cart has ${cartItems.length} line(s)');

    // Sign-in is checked here, BEFORE validation, because validation is itself
    // an authenticated call — POST /api/cart/save-cart is `protect`-ed. Running
    // it first meant a guest's checkout died on "Access denied. No token
    // provided." inside the cart-validation dialog, which offers only UPDATE
    // CART and CANCEL and never mentions signing in. The auth check used to sit
    // in _continueToCheckout, one step too late to help.
    final isSignedIn = await ref.read(authRepositoryProvider).isSignedIn();
    if (kDebugMode) print('[CHECKOUT] isSignedIn=$isSignedIn');
    if (!isSignedIn) {
      // Come back to the cart rather than straight to /checkout-flow: checkout
      // does not validate the cart itself, so jumping there would skip stock
      // and price checks entirely. pendingCheckoutProvider resumes the journey.
      if (kDebugMode) {
        print('[CHECKOUT] STOP: not signed in — pushing login '
            '(router=${_router != null})');
      }
      ref.read(pendingCheckoutProvider.notifier).state = true;
      _router?.push('/auth/login?redirectRoute=/cart');
      return;
    }

    final selectedOutletAsync = ref.read(selectedOutletProvider);
    final cartValidationNotifier = ref.read(cartValidationStateProvider.notifier);

    // Get current retry count
    final retryCount = ref.read(validationRetryCountProvider);
    
    // Get the store code from the selected outlet. Validation prices and
    // stock-checks against a specific store, so guessing one here would clear
    // a cart against another tenant's inventory and let checkout proceed on it.
    final storeCode = selectedOutletAsync.value?.storeCode;
    if (kDebugMode) {
      print('[CHECKOUT] storeCode=${storeCode ?? "<null>"} '
          '| retryCount=$retryCount (ceiling 2)');
    }
    if (storeCode == null || storeCode.isEmpty) {
      if (kDebugMode) print('[CHECKOUT] STOP: no store selected');
      showAppSnackBar(
        const SnackBar(
          content: Text('Select a store before checking out.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // No "Validating your cart…" toast here any more.
    //
    // It was redundant — the checkout button already watches
    // cartValidationStateProvider and renders its own spinner while validation
    // runs — and it was actively harmful: this single cosmetic line was where
    // checkout died. showSnackBar throws when any Scaffold registered with the
    // messenger has been deactivated, and that exception propagated straight
    // out of this method, so the shopper tapped Proceed and nothing happened.
    //
    // The remaining SnackBars in this flow go through showAppSnackBar, which
    // cannot throw. See lib/core/utils/app_snackbar.dart.

    // Validate the cart
    final validationResult = await cartValidationNotifier.validateCart(
      cartItems, 
      storeCode,
      retryCount,
    );
    
    // Increment retry count for next time
    ref.read(validationRetryCountProvider.notifier).state = retryCount + 1;
    
    // Remove any existing snackbars
    hideAppSnackBar();

    // The navigator captured while this screen was active. Everything below
    // runs after awaiting validation, so this screen's own `context` may
    // belong to a deactivated element — resolving the Navigator through it is
    // what threw "Looking up a deactivated widget's ancestor is unsafe" and
    // left the shopper unable to proceed to checkout at all.
    //
    // The navigator outlives this route, and its `mounted` check is the real
    // one: unlike `State.mounted` it is false precisely when its context can
    // no longer be used.
    final navigator = _navigator;

    if (kDebugMode) {
      print('[CHECKOUT] validation returned '
          '${validationResult == null ? "NULL (error)" : "result"} '
          '| navigatorMounted=${navigator?.mounted}');
      if (validationResult != null) {
        print('[CHECKOUT]   isValid=${validationResult.isValid} '
            '| hasChanges=${validationResult.hasChanges} '
            '| maxRetriesReached=${validationResult.maxRetriesReached} '
            '| isSaveError=${validationResult.isSaveError}');
        print('[CHECKOUT]   removed=${validationResult.removedItems.length} '
            'qtyChanged=${validationResult.quantityChangedItems.length} '
            'priceChanged=${validationResult.priceChangedItems.length} '
            'issues=${validationResult.itemsWithIssues.length}');
        print('[CHECKOUT]   message="${validationResult.validationMessage}"');
      }
    }

    // Check if we have a result and the navigator is still usable
    if (validationResult != null && navigator != null && navigator.mounted) {
      // Check if max retries reached
      if (validationResult.maxRetriesReached) {
        if (kDebugMode) print('[CHECKOUT] STOP: retry ceiling reached');
        _handleValidationRetriesExhausted(ref);
        return;
      }

      // Always show validation dialog if the validation result indicates issues or changes
      if (validationResult.hasChanges || !validationResult.isValid) {
        if (kDebugMode) print('[CHECKOUT] showing Quick Update dialog');
        // Show validation dialog for changes
        showDialog(
          context: navigator.context,
          barrierDismissible: false,
          builder: (dialogContext) => CartValidationDialog(
            result: validationResult,
            // The dialog's second button. It reads as CONTINUE when the server
            // called the cart valid (a price change alone is), and as CANCEL
            // otherwise — either way it closes, which is the only way out of a
            // barrierDismissible:false dialog.
            onContinue: () {
              // Only proceed if validation was ultimately successful
              if (validationResult.isValid) {
                Navigator.pop(dialogContext);
                _continueToCheckout(ref);
              } else {
                Navigator.pop(dialogContext);
                // Backing out ends this checkout attempt, so the retry budget
                // goes back to full — otherwise two cancels would leave the
                // next genuine attempt to trip the retry ceiling immediately.
                ref.read(validationRetryCountProvider.notifier).state = 0;
                showAppSnackBar(
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
              _autoUpdateCartBasedOnValidation(ref, validationResult);
            },
          ),
        );
      } else {
        // Both hasChanges is false AND isValid is true - safe to proceed
        if (kDebugMode) {
          print('[CHECKOUT] cart is clean — continuing to checkout');
        }
        _continueToCheckout(ref);
      }
    } else {
      // Error occurred during validation
      final errorMessage = cartValidationNotifier.errorMessage ?? 'Failed to validate cart';
      if (kDebugMode) {
        print('[CHECKOUT] STOP: no usable result '
            '(result=${validationResult != null}, '
            'navigator=${navigator != null}, '
            'navigatorMounted=${navigator?.mounted}) — "$errorMessage"');
      }
      showAppSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// Stop after the automatic fix-and-retry cycle has run out of attempts.
  ///
  /// This used to "take more drastic action": halve the quantity of every line
  /// over 2, or clear the cart and re-add only its first item, then reset the
  /// retry counter and re-enter checkout. A shopper who hit a validation issue
  /// the app could not map therefore watched the cart shrink on each pass, with
  /// no prompt and no way to stop it.
  ///
  /// Retries are the app's business; the cart is the shopper's. So the cycle
  /// just ends here — the cart is left exactly as it is, and the counter is
  /// cleared so a manual retry starts fresh.
  void _handleValidationRetriesExhausted(WidgetRef ref) {
    ref.read(validationRetryCountProvider.notifier).state = 0;

    showAppSnackBar(
      SnackBar(
        content: const Text(
          "We couldn't confirm some items. Please review your cart and try again.",
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  Future<void> _continueToCheckout(WidgetRef ref) async {
    // Reset retry count since we're proceeding
    ref.read(validationRetryCountProvider.notifier).state = 0;

    // Re-checked rather than assumed: _proceedToCheckout gates on sign-in, but
    // validation is a network round trip and the session can expire during it
    // (ApiClient forces a logout on any 401). Sending an unauthenticated
    // shopper into /checkout-flow would just bounce off its own route guard.
    final isLoggedIn = await ref.read(authRepositoryProvider).isSignedIn();

    if (kDebugMode) {
      print('[CHECKOUT] _continueToCheckout | isLoggedIn=$isLoggedIn '
          '| router=${_router != null}');
    }

    if (isLoggedIn) {
      // User is logged in, proceed to the new checkout flow
      if (kDebugMode) print('[CHECKOUT] ==> pushing /checkout-flow');
      _router?.push('/checkout-flow');
    } else {
      // Session died mid-checkout. Return to the cart after login so the
      // cart is re-validated instead of entering checkout unchecked.
      if (kDebugMode) {
        print('[CHECKOUT] session lost during validation ==> pushing login');
      }
      ref.read(pendingCheckoutProvider.notifier).state = true;
      _router?.push('/auth/login?redirectRoute=/cart');
    }
  }
  
  Future<void> _autoUpdateCartBasedOnValidation(
    WidgetRef ref,
    CartValidationResult result,
  ) async {
    final cartNotifier = ref.read(cartProvider.notifier);
    final selectedOutletAsync = ref.read(selectedOutletProvider);
    // Only reached from _proceedToCheckout, which has already refused to run
    // without an outlet — so this is a guard against a future second caller,
    // not a state a shopper can reach today.
    final storeCode = selectedOutletAsync.value?.storeCode;
    if (storeCode == null || storeCode.isEmpty) return;

    // Track the changes we made
    bool madeChanges = false;
    
    // Check if this is a save error that requires a retry
    if (result.isSaveError) {
      // Show retry in progress
      showAppSnackBar(
        const SnackBar(
          content: Text('Retrying cart save operation...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Retry saving the cart
       final cartValidator = ref.read(validator.cartValidatorProvider);
       final saveSuccess = await cartValidator.retrySaveCart(
        ref.read(cartItemsProvider), 
        storeCode
      );
      
      if (saveSuccess) {
        showAppSnackBar(
          const SnackBar(
            content: Text('Cart updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Reset retry count and try proceeding again
        ref.read(validationRetryCountProvider.notifier).state = 0;

        // Try proceeding with checkout again after the successful retry.
        // Unguarded for the same reason as the pushes above: _proceedToCheckout
        // works off the captured handles, so a `context.mounted` check here
        // only silently cancels the retry the shopper just asked for.
        _proceedToCheckout(ref);
        return;
      } else {
        // Show what the server actually objected to. "Failed to update cart.
        // Please try again." was a dead end: retrying changes nothing when
        // the cause is a rejected field or an expired session, and it gave
        // the shopper nothing to act on and us nothing to debug.
        final reason = cartValidator.lastSaveError;
        showAppSnackBar(
          SnackBar(
            content: Text(
              reason != null && reason.isNotEmpty
                  ? "Couldn't update cart: $reason"
                  : 'Failed to update cart. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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
        showAppSnackBar(
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
    
    // 2. Process server-capped quantities (low stock / per-order maximum).
    //
    // Previously unhandled, which is what made the dialog loop: the server
    // capped an item, nothing applied the cap, so `madeChanges` stayed false
    // and the cart was re-sent unchanged on every retry.
    final Map<String, int> quantityUpdates = {};
    if (result.quantityChangedItems.isNotEmpty) {
      for (final item in result.quantityChangedItems) {
        quantityUpdates[item.product.pCode] = item.newQuantity;
        madeChanges = true;
      }

      final count = result.quantityChangedItems.length;
      showAppSnackBar(
        SnackBar(
          content: Text(
            'Quantity updated for $count ${count == 1 ? 'item' : 'items'} (limited stock)'
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // 3. Process price changes
    if (result.priceChangedItems.isNotEmpty) {
      for (final item in result.priceChangedItems) {
        // Map the product code to its new price
        priceUpdates[item.product.pCode] = item.newPrice;
        madeChanges = true;
      }
      
      // Show notification for price updates
      if (context.mounted && result.priceChangedItems.isNotEmpty) {
        final count = result.priceChangedItems.length;
        showAppSnackBar(
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
    
    // 4. Process generic validation issues if we didn't make other changes
    if (!madeChanges && result.genericValidationItem != null) {
      final item = result.genericValidationItem!;
      
      // Try updating the quantity before the more drastic measures
      if (item.quantity > 1) {
        // Reduce quantity by 1
        cartNotifier.removeItem(item.product);
        cartNotifier.addItemWithQuantity(item.product, item.quantity - 1);
        
        showAppSnackBar(
          SnackBar(
            content: Text(
              'Reduced quantity for ${item.product.productName} to address validation issues'
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        madeChanges = true;
      } else {
        // If quantity is already 1, mark for removal
        itemsToRemove.add(item.product);
        
        showAppSnackBar(
          SnackBar(
            content: Text(
              'Removed ${item.product.productName} to address validation issues'
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        madeChanges = true;
      }
    }
    
    // 5. Apply all changes in one operation if we made some
    if (itemsToRemove.isNotEmpty ||
        priceUpdates.isNotEmpty ||
        quantityUpdates.isNotEmpty) {
      // Apply the validation changes to the cart
      cartNotifier.applyValidationChanges(
        removeItems: itemsToRemove,
        priceUpdates: priceUpdates,
        quantityUpdates: quantityUpdates,
      );

      madeChanges = true;
    }

    // 6. Nothing we know how to fix automatically. Hand the cart back to the
    //    shopper rather than mutating it behind their back — the old branch
    //    here halved every quantity, or cleared the cart down to its first
    //    line, and then re-entered checkout, so an unrecognised server
    //    complaint silently ate the cart one dialog at a time.
    if (!madeChanges && !result.isValid) {
      ref.read(validationRetryCountProvider.notifier).state = 0;
      showAppSnackBar(
        SnackBar(
          content: Text(
            result.validationMessage.isNotEmpty
                ? result.validationMessage
                : 'Some items are unavailable. Please adjust your cart and try again.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // 7. Re-run checkout with the corrected cart.
    //
    // Deliberately does NOT reset validationRetryCountProvider. Resetting it
    // disarmed the only bound on this recursion (_proceedToCheckout -> dialog
    // -> here -> _proceedToCheckout), so a condition the server kept rejecting
    // looped forever. The counter now survives the retry, and
    // _continueToCheckout clears it once checkout is actually reached.
    if (madeChanges) {
      await Future.delayed(const Duration(milliseconds: 300));

      // Unguarded: _proceedToCheckout uses the captured handles, so gating the
      // retry on this widget's own liveness would silently abandon the cart
      // the shopper just corrected.
      _proceedToCheckout(ref);
    }
  }

}