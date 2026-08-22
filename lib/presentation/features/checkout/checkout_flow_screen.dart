// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/delivery_charges_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_timer_provider.dart';
import '../checkout/widgets/checkout_timer_widget.dart';
// FACEBOOK PIXEL IMPORTS
import '../../../facebook_pixel/facebook_pixel_integration.dart';
import '../../../di/infrastructure_providers.dart';
import 'checkout_models.dart';
import 'steps/delivery_method_step.dart';
import 'steps/delivery_address_step.dart';
import 'steps/delivery_time_step.dart';
import 'steps/payment_step.dart';

// Checkout step enum to track progress

class CheckoutFlowScreen extends ConsumerStatefulWidget {
  const CheckoutFlowScreen({
    super.key,
    this.initialStep = CheckoutStep.delivery,
  });

  final CheckoutStep initialStep;

  @override
  ConsumerState<CheckoutFlowScreen> createState() => _CheckoutFlowScreenState();
}

class _CheckoutFlowScreenState extends ConsumerState<CheckoutFlowScreen> {
  late CheckoutStep _currentStep;
  late CheckoutData _checkoutData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _loadCheckoutData();

    // Track checkout initiation with Facebook Pixel and start checkout timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackCheckoutInitiation();
      if (mounted) {
        ref.read(checkoutTimerProvider.notifier).forceResetAndStart();
      }
    });
  }

  void _trackCheckoutInitiation() {
    try {
      final cartItems = ref.read(cartItemsProvider);
      final cartTotal = ref.read(cartTotalProvider);
      final productIds = cartItems.map((item) => item.product.pCode).toList();

      FacebookPixelIntegration.trackCheckoutEvent(
        ref,
        eventType: 'initiate',
        productIds: productIds,
        totalValue: cartTotal,
        numItems: cartItems.length,
      );
    } catch (e) {
      ref.read(loggerProvider).error('Failed to track checkout initiation: $e');
    }
  }

  Future<void> _loadCheckoutData() async {
    setState(() {
      _isLoading = true;
    });

    // Clear any cached checkout data from previous sessions to ensure fresh start
    // This prevents special notes and other data from persisting across orders
    await CheckoutData.clearFromPrefs();
    
    // Load fresh checkout data (will be empty after clearing)
    _checkoutData = await CheckoutData.loadFromPrefs();

    setState(() {
      _isLoading = false;
    });
  }

  void _goToNextStep() {
    setState(() {
      switch (_currentStep) {
        case CheckoutStep.delivery:
          // For self pickup, skip address and go directly to time selection
          if (_checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
            _currentStep = CheckoutStep.time;
          } else {
            _currentStep = CheckoutStep.address;
          }
          break;
        case CheckoutStep.address:
          _currentStep = CheckoutStep.time;
          break;
        case CheckoutStep.time:
          _currentStep = CheckoutStep.payment;
          break;
        case CheckoutStep.payment:
          // This is handled separately
          break;
      }
    });
  }
  
  void _goToStep(CheckoutStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  // Save current step data and proceed to next step
  Future<void> _saveAndProceed() async {
    await _checkoutData.saveToPrefs();
    _goToNextStep();
  }
  
  void _showOrderDetailsBottomSheet(BuildContext context) {
  final cartItems = ref.read(cartItemsProvider);
  final cartTotal = ref.read(cartTotalProvider);
  final cartSavings = ref.read(cartSavingsProvider);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Bottom sheet header with drag handle
              Container(
                height: 24,
                alignment: Alignment.center,
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Order Summary',
                      style: AppTextStyles.h6,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Order items list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          item.product.pcodeImg,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 48,
                              height: 48,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                      title: Text(
                        item.product.productName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.product.packageSize} ${item.product.packageUnit}',
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${(item.product.ourPrice * item.quantity).toStringAsFixed((item.product.ourPrice * item.quantity).truncateToDouble() == (item.product.ourPrice * item.quantity) ? 0 : 2)}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Qty: ${item.quantity}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const Divider(height: 1),
              
              // Order summary with dynamic delivery charges
              Consumer(
                builder: (context, ref, child) {
                  final deliveryChargesState = ref.watch(deliveryChargesProvider);
                  final deliveryCharge = deliveryChargesState.deliveryCharge;
                  final isLoadingDelivery = deliveryChargesState.isLoading;
                  final isFreeDelivery = deliveryChargesState.freeDeliveryEligible;
                  final distance = deliveryChargesState.distance;
                  // See the matching comment in delivery_time_step.dart:
                  // handling/packaging are store-configured flat fees that
                  // free delivery does NOT waive.
                  final distanceCharge = deliveryChargesState.distanceCharge;
                  final handlingFee = deliveryChargesState.handlingFee;
                  final packageFee = deliveryChargesState.packageFee;

                  // Calculate final total with delivery charges
                  final finalTotal = cartTotal + deliveryCharge;
                  
                  return Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Items Subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: AppTextStyles.bodyMedium,
                            ),
                            Text(
                              '₹${cartTotal.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Distance Information (if available)
                        if (distance > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Distance',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                              Text(
                                '${distance.toStringAsFixed(1)} km',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Delivery Fee (Dynamic)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Delivery Fee',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                if (isLoadingDelivery)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              isLoadingDelivery
                                  ? 'Calculating...'
                                  : (isFreeDelivery && distanceCharge <= 0)
                                      ? 'FREE'
                                      : '₹${distanceCharge.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: (isFreeDelivery && distanceCharge <= 0) ? AppColors.accent : null,
                                fontWeight: (isFreeDelivery && distanceCharge <= 0) ? FontWeight.bold : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Handling fee — store-configured flat charge (admin
                        // panel), shown only when the store has one set.
                        if (!isLoadingDelivery && handlingFee > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.build_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Handling Fee',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                              Text(
                                '₹${handlingFee.toStringAsFixed(2)}',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Packaging fee — same idea, shown only when set.
                        if (!isLoadingDelivery && packageFee > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Packaging Fee',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                              Text(
                                '₹${packageFee.toStringAsFixed(2)}',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Savings
                        if (cartSavings > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.savings,
                                    size: 14,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Savings',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                              Text(
                                '₹${cartSavings.toStringAsFixed(2)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Divider before total
                        const Divider(),
                        
                        // Total (including delivery charges)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isLoadingDelivery 
                                  ? '₹${cartTotal.toStringAsFixed(2)}+'
                                  : '₹${finalTotal.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        
                        // Free delivery message for eligible orders
                        if (isFreeDelivery && distance > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Free delivery for this order!',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Savings summary (if any)
                        if (cartSavings > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.savings,
                                  color: Colors.amber[800],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You saved ₹${cartSavings.toStringAsFixed(2)} on this order!',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.amber[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Delivery charge calculation status (if calculating)
                        if (isLoadingDelivery) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Calculating delivery charges based on your address...',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Delivery error (if any)
                        if (deliveryChargesState.error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Colors.orange[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Delivery charges will be calculated at checkout',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Listen for timer expiration
    ref.listen(checkoutTimerExpiredProvider, (previous, hasExpired) {
      if (hasExpired && mounted) {
        _handleTimerExpiration();
      }
    });

    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final shouldPop = await _handleBackNavigation();
          if (shouldPop && context.mounted) {
            context.pop();
          }
        }
      },
      child: WillPopScope(
        onWillPop: _handleBackNavigation,
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            final shouldPop = await _handleBackNavigation();
            if (shouldPop && context.mounted) {
              context.pop();
            }
          },
        ),
        actions: const [
          CheckoutTimerCompactWidget(),
        ],
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Progress bar - modified to show correct progress for self-pickup
          _buildProgressBar(),

          // Order summary
          _buildOrderSummary(),
          
          // Current step content
          Expanded(
            child: _buildCurrentStep(),
          ),
        ],
      ),
        ),
      ),
    );
  }

  // Handle back navigation for iOS and Android
  Future<bool> _handleBackNavigation() async {
    if (_currentStep == CheckoutStep.delivery) {
      // Exit checkout entirely
      return true; // Allow default back navigation
    } else {
      // Navigate to previous step with proper logic for self-pickup
      if (_checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
        // Self-pickup flow: delivery -> time -> payment
        if (_currentStep == CheckoutStep.time) {
          setState(() {
            _currentStep = CheckoutStep.delivery;
          });
        } else if (_currentStep == CheckoutStep.payment) {
          setState(() {
            _currentStep = CheckoutStep.time;
          });
        }
      } else {
        // Home delivery flow: delivery -> address -> time -> payment
        setState(() {
          _currentStep = CheckoutStep.values[_currentStep.index - 1];
        });
      }
      return false; // Prevent default back navigation
    }
  }

  // Helper to get appropriate app bar title based on current step
  String _getAppBarTitle() {
    switch (_currentStep) {
      case CheckoutStep.delivery:
        return 'Checkout';
      case CheckoutStep.address:
        return 'Delivery Address';
      case CheckoutStep.time:
        return 'Delivery Time';
      case CheckoutStep.payment:
        return 'Payment';
    }
  }

  // Build progress bar showing current step
  Widget _buildProgressBar() {
    // Determine steps to display based on delivery method
    List<CheckoutStep> stepsToShow = [];
    
    if (_checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
      // For self-pickup, show delivery, time, and payment steps (skip address)
      stepsToShow = [CheckoutStep.delivery, CheckoutStep.time, CheckoutStep.payment];
    } else {
      // For home delivery, show all steps
      stepsToShow = CheckoutStep.values;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: List.generate(stepsToShow.length, (index) {
          final step = stepsToShow[index];
          final isCompleted = step.index < _currentStep.index;
          final isCurrent = step.index == _currentStep.index;
          
          return Expanded(
            child: Row(
              children: [
                // Circle indicator
                GestureDetector(
                  onTap: isCompleted ? () => _goToStep(step) : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted || isCurrent
                          ? AppColors.primary
                          : Colors.grey[300],
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              _getStepNumber(step, stepsToShow).toString(),
                              style: TextStyle(
                                color: isCurrent
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                
                // Connector line (except after the last step)
                if (index < stepsToShow.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted
                          ? AppColors.primary
                          : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
  
  // Helper to get step number for display in progress bar
  int _getStepNumber(CheckoutStep step, List<CheckoutStep> stepsToShow) {
    return stepsToShow.indexOf(step) + 1;
  }

  // Build order summary section
  Widget _buildOrderSummary() {
  // Subscription kept deliberately: the binding was unused but the
  // watch is what rebuilds this on change.
  ref.watch(cartItemsProvider);
  // Subscription kept deliberately: the binding was unused but the
  // watch is what rebuilds this on change.
  ref.watch(cartTotalProvider);
  // Subscription kept deliberately: the binding was unused but the
  // watch is what rebuilds this on change.
  ref.watch(cartSavingsProvider);
  
  // Only show "View Order details" in payment step (step 4)
  if (_currentStep == CheckoutStep.payment) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              // Show detailed order summary in a modal bottom sheet
              _showOrderDetailsBottomSheet(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Text(
                    'View Order details',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // For other steps, return empty container
  return const SizedBox.shrink();
}

  // Build current step content based on _currentStep
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case CheckoutStep.delivery:
        return DeliveryMethodStep(
          checkoutData: _checkoutData,
          onContinue: _saveAndProceed,
          // Added new callback to handle direct navigation for self-pickup
          onSelfPickupSelected: () {
            _checkoutData.deliveryMethod = DeliveryMethod.selfPickup;
            _saveAndProceed();
          },
        );
      case CheckoutStep.address:
        return DeliveryAddressStep(
          checkoutData: _checkoutData,
          onContinue: _saveAndProceed,
        );
      case CheckoutStep.time:
        return DeliveryTimeStep(
          checkoutData: _checkoutData,
          onContinue: _saveAndProceed,
        );
      case CheckoutStep.payment:
        // Pass appropriate store details for self-pickup
        return PaymentStep(
          checkoutData: _checkoutData,
        );
    }
  }

  void _handleTimerExpiration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Session Expired',
            style: TextStyle(
              color: Colors.red.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Your order session has expired—no stress! We’ll take you back to your cart to continue shopping.',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToCart();
              },
              child: Text(
                'Continue to Cart',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToCart() {
    if (mounted) {
      // Navigate to cart screen - cart data is preserved automatically
      context.go('/cart');
    }
  }
}

// STEP 1: Delivery Method Step
