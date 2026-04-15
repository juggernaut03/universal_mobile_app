// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/utils/input_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/data/models/auth_models.dart';
import 'package:patelmart/data/models/delivery_slot_model.dart';
import 'package:patelmart/data/models/payment_method_model.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/data/services/payment_service.dart';
import 'package:patelmart/presentation/features/checkout/enhanced_payment_flow.dart';
import 'package:patelmart/presentation/features/outlet_status/outlet_status_banner.dart';
import 'package:patelmart/presentation/providers/address_provider.dart';
import 'package:patelmart/presentation/providers/cart_validator_provider.dart';
import 'package:patelmart/presentation/providers/delivery_charges_provider.dart';
import 'package:patelmart/presentation/providers/delivery_slot_provider.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import 'package:patelmart/presentation/providers/order_providers.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/outlet_status_provider.dart';
import 'package:patelmart/presentation/providers/payment_method_provider.dart';
import 'package:patelmart/presentation/providers/reorder_provider.dart';
import 'package:patelmart/utils/payment_data_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/outlet_model.dart';
import '../../../core/auth/centralized_auth_manager.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_timer_provider.dart';
import '../checkout/widgets/checkout_timer_widget.dart';
import 'package:patelmart/presentation/features/account/address_book_screen.dart' as address;
// FACEBOOK PIXEL IMPORTS
import '../../../facebook_pixel/facebook_pixel_integration.dart';

// Checkout step enum to track progress
enum CheckoutStep {
  delivery,
  address,
  time,
  payment,
}

// Delivery method enum
enum DeliveryMethod {
  homeDelivery,
  selfPickup,
}

// Checkout data model to store user selections
class CheckoutData {
  DeliveryMethod? deliveryMethod;
  Address? selectedAddress;
  DateTime? deliveryDate;
  String? deliveryTimeSlot;
  String? specialInstructions;
  String? paymentMethod;
  String? pickupName;

  CheckoutData({
    this.deliveryMethod,
    this.selectedAddress,
    this.deliveryDate,
    this.deliveryTimeSlot,
    this.specialInstructions,
    this.paymentMethod,
    this.pickupName,
  });

  Map<String, dynamic> toJson() {
    return {
      'deliveryMethod': deliveryMethod?.index,
      'selectedAddress': selectedAddress?.toJson(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'deliveryTimeSlot': deliveryTimeSlot,
      'specialInstructions': specialInstructions,
      'paymentMethod': paymentMethod,
      'pickupName': pickupName,
    };
  }

  factory CheckoutData.fromJson(Map<String, dynamic> json) {
    return CheckoutData(
      deliveryMethod: json['deliveryMethod'] != null
          ? DeliveryMethod.values[json['deliveryMethod']]
          : null,
      selectedAddress: json['selectedAddress'] != null
          ? Address.fromJson(json['selectedAddress'])
          : null,
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.parse(json['deliveryDate'])
          : null,
      deliveryTimeSlot: json['deliveryTimeSlot'],
      specialInstructions: json['specialInstructions'],
      paymentMethod: json['paymentMethod'],
      pickupName: json['pickupName'],
    );
  }

  // Save checkout data to SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(toJson());
    await prefs.setString('checkout_data', jsonData);
  }

  // Load checkout data from SharedPreferences
  static Future<CheckoutData> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString('checkout_data');
    if (jsonData != null) {
      return CheckoutData.fromJson(jsonDecode(jsonData));
    }
    return CheckoutData();
  }

  // Clear checkout data from SharedPreferences
  static Future<void> clearFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkout_data');
  }
}

// Main checkout flow screen that handles all steps
class CheckoutFlowScreen extends ConsumerStatefulWidget {
  const CheckoutFlowScreen({
    Key? key,
    this.initialStep = CheckoutStep.delivery,
  }) : super(key: key);

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
      final cartItems = ref.read(cartProvider);
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
  final cartItems = ref.read(cartProvider);
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
                                  : isFreeDelivery
                                      ? 'FREE'
                                      : '₹${deliveryCharge.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isFreeDelivery ? AppColors.accent : null,
                                fontWeight: isFreeDelivery ? FontWeight.bold : null,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
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
  final cartItems = ref.watch(cartProvider);
  final cartTotal = ref.watch(cartTotalProvider);
  final cartSavings = ref.watch(cartSavingsProvider);
  
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
                  const Icon(
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
class DeliveryMethodStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;
  final VoidCallback onContinue;
  final VoidCallback? onSelfPickupSelected;

  const DeliveryMethodStep({
    Key? key,
    required this.checkoutData,
    required this.onContinue,
    this.onSelfPickupSelected,
  }) : super(key: key);

  @override
  ConsumerState<DeliveryMethodStep> createState() => _DeliveryMethodStepState();
}

class _DeliveryMethodStepState extends ConsumerState<DeliveryMethodStep> {
  DeliveryMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.checkoutData.deliveryMethod;
  }

  void _selectDeliveryMethod(DeliveryMethod method) {
    setState(() {
      _selectedMethod = method;
    });
    widget.checkoutData.deliveryMethod = method;
    
    // Note: We no longer skip directly to payment for self-pickup
    // User will now select a pickup time slot in the next step
  }

  @override
  Widget build(BuildContext context) {
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);
    
    return outletStatusAsync.when(
      data: (status) => _buildContent(context, status),
      loading: () => _buildLoadingState(),
      error: (error, stackTrace) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildContent(BuildContext context, status) {
    // If status is null, show error
    if (status == null) {
      return _buildErrorState('Unable to load store information');
    }

    // If store is completely unavailable
    if (!status.isEnabled) {
      return _buildStoreClosedState(status.statusMessage);
    }

    // If no delivery methods are available
    if (!status.hasAnyServiceAvailable) {
      return _buildNoServicesState(status.statusMessage);
    }

    // Auto-select if only one method is available
    if (status.hasDeliveryOnly && _selectedMethod != DeliveryMethod.homeDelivery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectDeliveryMethod(DeliveryMethod.homeDelivery);
      });
    } else if (status.hasPickupOnly && _selectedMethod != DeliveryMethod.selfPickup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectDeliveryMethod(DeliveryMethod.selfPickup);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outlet Status Banner
        const OutletStatusBanner(showOnlyIfUnavailable: false),
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Choose Delivery Method',
            style: AppTextStyles.h5,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'How do you want to receive your order?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Home Delivery Option (only if available)
        if (status.homeDeliveryAvailable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildDeliveryOption(
              title: 'Home Delivery',
              subtitle: 'Delivered to your doorstep',
              icon: Icons.home,
              method: DeliveryMethod.homeDelivery,
              isEnabled: true,
            ),
          ),
        
        if (status.homeDeliveryAvailable && status.selfPickupAvailable)
          const SizedBox(height: 16),
        
        // Self Pickup Option (only if available)
        if (status.selfPickupAvailable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildDeliveryOption(
              title: 'Self Pickup',
              subtitle: 'Collect from our store',
              icon: Icons.store,
              method: DeliveryMethod.selfPickup,
              isEnabled: true,
            ),
          ),
        
        const Spacer(),
        
        // Order Total Section
        _buildOrderTotal(),
        
        // Continue Button - Shown for both delivery methods
        Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: MediaQuery.of(context).padding.bottom + 16.0,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedMethod == null ? null : widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('CONTINUE'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required DeliveryMethod method,
    required bool isEnabled,
  }) {
    final isSelected = _selectedMethod == method;
    
    return InkWell(
      onTap: isEnabled ? () => _selectDeliveryMethod(method) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isEnabled 
                ? (isSelected ? AppColors.primary : Colors.grey[300]!)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isEnabled
              ? (isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white)
              : Colors.grey[100],
        ),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              backgroundColor: isEnabled
                  ? (isSelected ? AppColors.primary : Colors.grey[200])
                  : Colors.grey[300],
              radius: 24,
              child: Icon(
                icon,
                color: isEnabled
                    ? (isSelected ? Colors.white : Colors.grey[600])
                    : Colors.grey[500],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isEnabled ? null : Colors.grey[600],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isEnabled ? AppColors.textSecondary : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio button
            Radio<DeliveryMethod>(
              value: method,
              groupValue: _selectedMethod,
              activeColor: AppColors.primary,
              onChanged: isEnabled ? (value) {
                if (value != null) {
                  _selectDeliveryMethod(value);
                }
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTotal() {
    final cartTotal = ref.watch(cartTotalProvider);
    final cartSavings = ref.watch(cartSavingsProvider);
    
    final deliveryFee = _selectedMethod == DeliveryMethod.homeDelivery ? 0.0 : 0.0;
    // You could set a delivery fee based on business rules
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Total',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${cartTotal.toStringAsFixed(2)}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee:',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(2)}' : 'calculate checkout',
                style: AppTextStyles.bodySmall.copyWith(
                  color: deliveryFee > 0 ? null : AppColors.primary,
                  fontWeight: deliveryFee > 0 ? null : FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'You save: ₹${cartSavings.toStringAsFixed(2)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading delivery options...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Store Information',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(refreshOutletStatusProvider)();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreClosedState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Store Temporarily Closed',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message.isNotEmpty ? message : 'This store is currently not accepting orders.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // OutlinedButton.icon(
                //   onPressed: () {
                //     ref.read(refreshOutletStatusProvider)();
                //   },
                //   icon: const Icon(Icons.refresh),
                //   label: const Text('Refresh'),
                // ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
              onPressed: () => context.go('/location-change'),
              icon: const Icon(Icons.store),
              label: const Text('Change Store'),
                 ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoServicesState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining_outlined,
              size: 64,
              color: AppColors.warning,
            ),
            const SizedBox(height: 16),
            Text(
              'No Delivery Services Available',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.warning,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message.isNotEmpty ? message : 'Neither home delivery nor store pickup is currently available.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(refreshOutletStatusProvider)();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/location-change');
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('Change Store'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// STEP 2: Delivery Address Step
// Enhanced DeliveryAddressStep with improved empty state handling
// and better integration with the address book

// Replace the entire DeliveryAddressStep class in your checkout_flow_screen.dart

class DeliveryAddressStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;
  final VoidCallback onContinue;

  const DeliveryAddressStep({
    Key? key,
    required this.checkoutData,
    required this.onContinue,
  }) : super(key: key);

  @override
  ConsumerState<DeliveryAddressStep> createState() => _DeliveryAddressStepState();
}

class _DeliveryAddressStepState extends ConsumerState<DeliveryAddressStep> {
  Address? _selectedAddress;
  bool _isLoading = true;
  List<Address> _addresses = [];

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.checkoutData.selectedAddress;
    _loadAddresses();
  }

  // Add this method to handle page lifecycle
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload addresses when returning to this page
    if (mounted) {
      _loadAddresses();
    }
  }

  // Add this import at the top of your file


Future<void> _loadAddresses() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Wait for auth state to be ready before loading addresses
    final authManager = ref.read(centralizedAuthManagerProvider);
    final isLoggedIn = await authManager.isLoggedIn();
    
    if (!isLoggedIn) {
      ref.read(loggerProvider).warning('User not logged in, cannot load addresses');
      _addresses = [];
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Add a small delay to ensure auth state has fully propagated
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Method 1: Use ref.read() to get the future directly
    _addresses = await ref.read(address.addressListProvider.future);
    
    // OR Method 2: Refresh and then read
    // ref.refresh(addressListProvider);
    // _addresses = await ref.read(addressListProvider.future);
    
    ref.read(loggerProvider).log('Loaded ${_addresses.length} addresses in checkout');
    
    // If we have a previously selected address, find it in the list
    if (widget.checkoutData.selectedAddress != null) {
      final matchingAddress = _addresses.firstWhere(
        (address) => address.id == widget.checkoutData.selectedAddress!.id,
        orElse: () => _addresses.isNotEmpty ? _addresses.first : widget.checkoutData.selectedAddress!,
      );
      _selectedAddress = matchingAddress;
    } else if (_addresses.isNotEmpty) {
      // If no previously selected address, select the first one
      _selectedAddress = _addresses.first;
    }
    
    // Update the checkout data
    widget.checkoutData.selectedAddress = _selectedAddress;
  } catch (e) {
    ref.read(loggerProvider).error('Error loading addresses: $e');
    // Handle error loading addresses
    _addresses = [];
  }

  setState(() {
    _isLoading = false;
  });
}

void _selectAddress(Address address) {
  setState(() {
    _selectedAddress = address;
  });
  widget.checkoutData.selectedAddress = address;
  
  // Calculate delivery charges when an address is selected
  ref.read(deliveryChargesProvider.notifier).calculateDeliveryCharges(
    userAddress: address,
  );
}

@override
Widget build(BuildContext context) {
  // Watch for address refresh trigger - THIS IS THE KEY FIX
  ref.listen(addressRefreshProvider, (previous, next) {
    if (mounted && previous != next) {
      ref.read(loggerProvider).log('Address refresh triggered, reloading addresses');
      _loadAddresses();
    }
  });

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Delivery Address',
          style: AppTextStyles.h5,
        ),
      ),
      
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          'Select delivery address',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
      
      const SizedBox(height: 16),
      
      if (_isLoading)
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        )
      else if (_addresses.isEmpty)
        Expanded(
          child: _buildNoAddressesView(),
        )
      else
        Expanded(
          child: _buildAddressList(),
        ),
        
      // Order Total Section
      _buildOrderTotal(),
      
      // Continue Button
      Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          bottom: MediaQuery.of(context).padding.bottom + 16.0,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedAddress == null ? null : widget.onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('CONTINUE'),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildNoAddressesView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Empty state icon
        Icon(
          Icons.location_off,
          size: 72,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          'No addresses found',
          style: AppTextStyles.h6,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'Please add a delivery address to continue',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // Navigate to add address screen with return route information
            context.push('/add-address', extra: {'returnToCheckout': true});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('ADD ADDRESS'),
        ),
      ],
    );
  }

  Widget _buildAddressList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _addresses.length + 1, // +1 for the "Add Address" button
      itemBuilder: (context, index) {
        if (index == _addresses.length) {
          // Last item is "Add Address" button
          return Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: OutlinedButton.icon(
              onPressed: () {
                // Navigate to add address screen with return route information
                context.push('/add-address', extra: {'returnToCheckout': true});
              },
              icon: const Icon(Icons.add),
              label: const Text('ADD NEW ADDRESS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          );
        }
        
        final address = _addresses[index];
        final isSelected = _selectedAddress?.id == address.id;
        
        return _buildAddressCard(address, isSelected);
      },
    );
  }

  Widget _buildAddressCard(Address address, bool isSelected) {
    return Consumer(
      builder: (context, ref, child) {
        // Get delivery distance information if available
        final deliveryChargesState = ref.watch(deliveryChargesProvider);
        final hasDistanceInfo = isSelected && deliveryChargesState.distance > 0;
        final distanceValue = deliveryChargesState.distance;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => _selectAddress(address),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Icon
                      CircleAvatar(
                        backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
                        child: Icon(
                          Icons.location_on,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 18,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Address Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address.fullName,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${address.deliveryAddrLine1}, ${address.deliveryAddrLine2}, ${address.deliveryAddrCity} - ${address.deliveryAddrPincode}',
                              style: AppTextStyles.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (address.landmark.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Landmark: ${address.landmark}',
                                style: AppTextStyles.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'PIN: ${address.deliveryAddrPincode}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mobile: ${address.mobileNumber}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            
                            if (address.isDefault == 'Yes') ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'DEFAULT ADDRESS',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Radio button
                      Radio<String>(
                        value: address.id,
                        groupValue: _selectedAddress?.id,
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          if (value != null) {
                            _selectAddress(address);
                          }
                        },
                      ),
                    ],
                  ),
                  
                  // Show distance information if available and selected
                  if (hasDistanceInfo) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Distance from store: ${distanceValue.toStringAsFixed(1)} km',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    
                    // Show delivery fee info based on the distance
                    if (deliveryChargesState.deliveryCharge > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Fee: ₹${deliveryChargesState.deliveryCharge.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Free Delivery!',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Show loading indicator when calculating
                    if (deliveryChargesState.isLoading) ...[
                      const SizedBox(height: 8),
                      Row(
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
                          Text(
                            'Calculating delivery charges...',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderTotal() {
  return Consumer(
    builder: (context, ref, _) {
      final cartTotal = ref.watch(cartTotalProvider);
      final cartSavings = ref.watch(cartSavingsProvider);
      
      // Get delivery charges from provider
      final deliveryChargesState = ref.watch(deliveryChargesProvider);
      final deliveryCharge = deliveryChargesState.deliveryCharge;
      final isLoading = deliveryChargesState.isLoading;
      final isFreeDelivery = deliveryChargesState.freeDeliveryEligible;
      final distance = deliveryChargesState.distance;
      
      // Calculate final total with delivery charges
      final finalTotal = cartTotal + deliveryCharge;
      
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cart subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Subtotal',
                  style: AppTextStyles.bodyMedium,
                ),
                Text(
                  '₹${cartTotal.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            
            // Distance information - NEW ADDITION
            if (distance > 0) ...[
              const SizedBox(height: 8),
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
                        'Distance:',
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
            ],
            
            // Delivery fee
            const SizedBox(height: 8),
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
                      'Delivery Fee:',
                      style: AppTextStyles.bodyMedium,
                    ),
                    if (isLoading)
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
                  isLoading 
                    ? 'Calculating...'
                    : isFreeDelivery
                      ? 'FREE'
                      : '₹${deliveryCharge.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isFreeDelivery ? Colors.green : null,
                    fontWeight: isFreeDelivery ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            
            // Savings
            if (cartSavings > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.savings,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'You Save:',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                  Text(
                    '₹${cartSavings.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
            
            const Divider(height: 24),
            
            // Total
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
                  '₹${finalTotal.toStringAsFixed(2)}',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Free delivery for this order',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
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
  );
}
}
// STEP 3: Delivery Time Step
// Replace the DeliveryTimeStep class in your checkout_flow_screen.dart with this updated version

class DeliveryTimeStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;
  final VoidCallback onContinue;

  const DeliveryTimeStep({
    Key? key,
    required this.checkoutData,
    required this.onContinue,
  }) : super(key: key);

  @override
  ConsumerState<DeliveryTimeStep> createState() => _DeliveryTimeStepState();
}

class _DeliveryTimeStepState extends ConsumerState<DeliveryTimeStep> {
  DateTime? _selectedDate;
  DeliverySlot? _selectedSlot;
  List<DateTime> _availableDates = [];
  Map<String, List<DeliverySlot>> _timeSlots = {};
  bool _isLoadingSlots = false;
  bool _isLoadingDates = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.checkoutData.deliveryDate;
    
    // Load data asynchronously
    _loadData();
    
    // Ensure delivery charges are calculated on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only calculate if we have a selected address in checkout data
      if (widget.checkoutData.selectedAddress != null) {
        ref.read(deliveryChargesProvider.notifier).calculateDeliveryCharges(
          userAddress: widget.checkoutData.selectedAddress!,
        );
      }
    });
  }

  Future<void> _loadData() async {
    // Load available dates first
    await _loadAvailableDates();
    
    // Then load delivery slots
    await _loadDeliverySlots();
  }

  Future<void> _loadAvailableDates() async {
    setState(() {
      _isLoadingDates = true;
    });

    try {
      // Fetch delivery dates from API
      final dateStrings = await ref.read(deliveryDatesProvider.future);
      
      // Parse dd/MM/yyyy format to DateTime
      final parsedDates = <DateTime>[];
      for (final dateStr in dateStrings) {
        try {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            parsedDates.add(DateTime(year, month, day));
          }
        } catch (e) {
          ref.read(loggerProvider).error('Error parsing date $dateStr: $e');
        }
      }
      
      if (parsedDates.isNotEmpty) {
        _availableDates = parsedDates;
        ref.read(loggerProvider).log('Loaded ${_availableDates.length} delivery dates from API');
      } else {
        // Fallback to local generation if no dates returned
        _initializeAvailableDates();
        ref.read(loggerProvider).log('Using fallback dates (API returned no dates)');
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error loading delivery dates from API: $e');
      // Fallback to local generation on error
      _initializeAvailableDates();
    }
    
    // If we don't have a selected date yet, select the first available one
    if (_selectedDate == null && _availableDates.isNotEmpty) {
      _selectedDate = _availableDates.first;
      widget.checkoutData.deliveryDate = _selectedDate;
    }
    
    setState(() {
      _isLoadingDates = false;
    });
  }

  void _initializeAvailableDates() {
    // Generate dates for the next 3 days (fallback)
    final now = DateTime.now();
    _availableDates = List.generate(3, (index) {
      return DateTime(now.year, now.month, now.day + index);
    });
  }

  Future<void> _loadDeliverySlots() async {
    setState(() {
      _isLoadingSlots = true;
    });

    try {
      // Determine which slots to load based on delivery method
      final isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
      
      // Get appropriate delivery slots from API
      final slots = isSelfPickup
          ? await ref.read(selfPickupDeliverySlotsProvider.future)
          : await ref.read(deliverySlotsProvider.future);
      
      // Organize slots by date (for now, same slots available for all dates)
      _timeSlots.clear();
      for (final date in _availableDates) {
        final key = _formatDateKey(date);
        _timeSlots[key] = List.from(slots);
      }
      
      // If we don't have a selected slot yet, select the first available one
      if (_selectedSlot == null && slots.isNotEmpty) {
        final dateSlotsKey = _formatDateKey(_selectedDate!);
        if (_timeSlots.containsKey(dateSlotsKey) && _timeSlots[dateSlotsKey]!.isNotEmpty) {
          _selectedSlot = _timeSlots[dateSlotsKey]!.first;
          widget.checkoutData.deliveryTimeSlot = _selectedSlot!.displayText;
        }
      } else if (widget.checkoutData.deliveryTimeSlot != null) {
        // Try to find the previously selected slot
        final previousSlotText = widget.checkoutData.deliveryTimeSlot!;
        for (final slot in slots) {
          if (slot.displayText == previousSlotText) {
            _selectedSlot = slot;
            break;
          }
        }
      }
      
      final slotType = isSelfPickup ? 'self-pickup' : 'delivery';
      ref.read(loggerProvider).log('Loaded ${slots.length} $slotType slots from API');
    } catch (e) {
      ref.read(loggerProvider).error('Error loading delivery slots: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load delivery slots. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadDeliverySlots,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}_${date.month}_${date.day}';
  }

  String _formatDateDisplay(DateTime date) {
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    
    if (date.year == now.year && date.month == now.month && date.day == now.day + 1) {
      return 'Tomorrow';
    }
    
    // May 01, 2025 format
    return '${_getMonthName(date.month)} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      
      // Reset time slot if the date changes
      final key = _formatDateKey(date);
      if (_timeSlots.containsKey(key) && _timeSlots[key]!.isNotEmpty) {
        _selectedSlot = _timeSlots[key]!.first;
      } else {
        _selectedSlot = null;
      }
    });
    
    // Update checkout data
    widget.checkoutData.deliveryDate = date;
    widget.checkoutData.deliveryTimeSlot = _selectedSlot?.displayText;
  }

  void _selectTimeSlot(DeliverySlot slot) {
    setState(() {
      _selectedSlot = slot;
    });
    widget.checkoutData.deliveryTimeSlot = slot.displayText;
  }

  @override
  Widget build(BuildContext context) {
    final isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isSelfPickup ? 'Choose Pickup Time' : 'Choose Delivery Time',
            style: AppTextStyles.h5,
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            isSelfPickup ? 'Select pickup time slot' : 'Select delivery time slot',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Date tabs
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _isLoadingDates
            ? ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: index < 2 ? 12.0 : 0),
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  );
                },
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableDates.length,
                itemBuilder: (context, index) {
                  final date = _availableDates[index];
                  final isSelected = _selectedDate?.day == date.day && 
                                    _selectedDate?.month == date.month &&
                                    _selectedDate?.year == date.year;
                  
                  return Padding(
                    padding: EdgeInsets.only(right: index < _availableDates.length - 1 ? 12.0 : 0),
                    child: InkWell(
                      onTap: () => _selectDate(date),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            _formatDateDisplay(date),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
        
        const SizedBox(height: 24),
        
        // Time slots
        Expanded(
          child: _buildTimeSlots(),
        ),
        
        // Order Total Section
        _buildOrderTotal(),
        
        // Continue Button
        Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: MediaQuery.of(context).padding.bottom + 16.0,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: Consumer(
              builder: (context, ref, child) {
                final deliveryChargesState = ref.watch(deliveryChargesProvider);
                final isCalculating = deliveryChargesState.isLoading;
                
                return ElevatedButton(
                  onPressed: (_selectedSlot == null || isCalculating || _isLoadingSlots || _isLoadingDates) 
                    ? null 
                    : widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: (isCalculating || _isLoadingSlots || _isLoadingDates)
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('CONTINUE'),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlots() {
    if (_selectedDate == null) {
      return const Center(
        child: Text('Please select a date first'),
      );
    }
    
    if (_isLoadingSlots) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading delivery slots...'),
          ],
        ),
      );
    }
    
    final key = _formatDateKey(_selectedDate!);
    final slots = _timeSlots[key] ?? [];
    
    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No time slots available',
              style: AppTextStyles.h6,
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a different date or try again later',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDeliverySlots,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Show date heading
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateDisplay(_selectedDate!),
                style: AppTextStyles.h6,
              ),
              if (_isLoadingSlots)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Time slot grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.isSmall(context) ? 2 : 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final isSelected = _selectedSlot?.id == slot.id;
              
              return InkWell(
                onTap: () => _selectTimeSlot(slot),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot.displayText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Available',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.green[700],
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTotal() {
    return Consumer(
      builder: (context, ref, _) {
        final cartTotal = ref.watch(cartTotalProvider);
        final cartSavings = ref.watch(cartSavingsProvider);
        
        // Get delivery charges from provider
        final deliveryChargesState = ref.watch(deliveryChargesProvider);
        final deliveryCharge = deliveryChargesState.deliveryCharge;
        final isLoading = deliveryChargesState.isLoading;
        final isFreeDelivery = deliveryChargesState.freeDeliveryEligible;
        final distance = deliveryChargesState.distance;
        
        // Calculate final total with delivery charges
        final finalTotal = cartTotal + deliveryCharge;
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Cart subtotal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Subtotal',
                    style: AppTextStyles.bodyMedium,
                  ),
                  Text(
                    '₹${cartTotal.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              
              // Distance information
              if (distance > 0) ...[
                const SizedBox(height: 8),
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
                          'Distance:',
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
              ],
              
              // Delivery fee
              const SizedBox(height: 8),
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
                        'Delivery Fee:',
                        style: AppTextStyles.bodyMedium,
                      ),
                      if (isLoading)
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
                    isLoading 
                      ? 'Calculating...'
                      : isFreeDelivery
                        ? 'FREE'
                        : '₹${deliveryCharge.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isFreeDelivery ? Colors.green : null,
                      fontWeight: isFreeDelivery ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
              
              // Savings
              if (cartSavings > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.savings,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'You Save:',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                    Text(
                      '₹${cartSavings.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
              
              const Divider(height: 24),
              
              // Total
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
                    '₹${finalTotal.toStringAsFixed(2)}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Free delivery for this order',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
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
    );
  }
}
// STEP 4: Payment Step
// Updated PaymentStep implementation for the CheckoutFlowScreen

// STEP 4: Updated Payment Step with API Integration
// Replace the existing PaymentStep class in your checkout_flow_screen.dart with this updated version

class PaymentStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;

  const PaymentStep({
    Key? key,
    required this.checkoutData,
  }) : super(key: key);

  @override
  ConsumerState<PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<PaymentStep> {
  PaymentMethod? _selectedPaymentMethod;
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _pickupNameController = TextEditingController();
  bool _isPlacingOrder = false;
  bool _showSuccessDialog = false;

  @override
  void initState() {
    super.initState();
    _instructionsController.text = widget.checkoutData.specialInstructions ?? '';
    _pickupNameController.text = widget.checkoutData.pickupName ?? '';

    // Reset the order state when initializing the payment step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.initial;
      ref.read(orderErrorMessageProvider.notifier).state = null;

      // Try to restore previously selected payment method
      _restoreSelectedPaymentMethod();
    });
  }

  @override
  void dispose() {
    // Stop checkout timer when leaving checkout
    ref.read(checkoutTimerProvider.notifier).stopTimer();
    _instructionsController.dispose();
    _pickupNameController.dispose();
    super.dispose();
  }

  void _restoreSelectedPaymentMethod() {
    // If we have a previously selected payment method in checkoutData, try to restore it
    if (widget.checkoutData.paymentMethod != null) {
      final paymentMethodsAsync = ref.read(paymentMethodsProvider);
      paymentMethodsAsync.whenData((methods) {
        // Try to find the method by name
        final previousMethod = methods.firstWhere(
          (method) => method.paymentModeName == widget.checkoutData.paymentMethod ||
                      method.displayName == widget.checkoutData.paymentMethod,
          orElse: () => methods.isNotEmpty ? methods.first : PaymentMethod(
            id: '',
            idPaymentMode: 0,
            paymentModeName: 'Unknown',
          ),
        );
        
        if (previousMethod.idPaymentMode > 0) {
          setState(() {
            _selectedPaymentMethod = previousMethod;
          });
          ref.read(selectedPaymentMethodProvider.notifier).state = previousMethod;
        }
      });
    }
  }

  void _selectPaymentMethod(PaymentMethod method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
    
    // Update providers
    ref.read(selectedPaymentMethodProvider.notifier).state = method;
    widget.checkoutData.paymentMethod = method.paymentModeName;
    
    final logger = ref.read(loggerProvider);
    logger.log('Selected payment method: ${method.displayName} (${method.paymentModeName})');
  }

  // Validate cart and ensure we have required data
  bool _validateOrderData() {
    // Check payment method
    if (_selectedPaymentMethod == null) {
      _showErrorSnackBar('Please select a payment method');
      return false;
    }
    
    // Check if we have a delivery address (for home delivery)
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery &&
        widget.checkoutData.selectedAddress == null) {
      _showErrorSnackBar('Please select a delivery address');
      return false;
    }

    // Validate address fields for home delivery (critical for online payment)
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery &&
        widget.checkoutData.selectedAddress != null) {
      final address = widget.checkoutData.selectedAddress!;

      // Check that address has required fields for payment
      if (address.mobileNumber.isEmpty || address.mobileNumber.trim().isEmpty) {
        _showErrorSnackBar('Address is missing mobile number. Please select a different address or update this one.');
        return false;
      }



      if (address.fullName.isEmpty || address.fullName.trim().isEmpty) {
        _showErrorSnackBar('Address is missing recipient name. Please select a different address or update this one.');
        return false;
      }
    }

    // Check if we have delivery date and time slot (for home delivery)
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery) {
      if (widget.checkoutData.deliveryDate == null) {
        _showErrorSnackBar('Please select a delivery date');
        return false;
      }
      if (widget.checkoutData.deliveryTimeSlot == null ||
          widget.checkoutData.deliveryTimeSlot!.isEmpty) {
        _showErrorSnackBar('Please select a delivery time slot');
        return false;
      }
    }

    // Check pickup name for self-pickup
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
      if (widget.checkoutData.pickupName == null || widget.checkoutData.pickupName!.trim().isEmpty) {
        _showErrorSnackBar('Please enter your pickup name');
        return false;
      }
    }
    
    // Check cart not empty
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      _showErrorSnackBar('Your cart is empty');
      return false;
    }
    
    // Check outlet selected
    final selectedOutlet = ref.read(selectedOutletProvider).value;
    if (selectedOutlet == null) {
      _showErrorSnackBar('No store selected');
      return false;
    }
    
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _buildSpecialNotes(UserProfile? userProfile) {
    final List<String> notes = [];

    // Add typed special instructions if provided
    final instructions = _instructionsController.text.trim();
    if (instructions.isNotEmpty) {
      notes.add(instructions);
    }

    // For self-pickup, add pickup name info
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
      final pickupName = widget.checkoutData.pickupName?.trim().isNotEmpty == true
          ? widget.checkoutData.pickupName!
          : (userProfile?.mobile ?? '');
      notes.add('Pickup Name: $pickupName');
    }

    // Add profile name (using mobile since no explicit name field exists)
    final profileName = userProfile?.mobile ?? '';
    if (profileName.isNotEmpty) {
      notes.add('Profile Name: $profileName');
    }

    // Add mobile number
    final mobile = userProfile?.mobile ?? '';
    if (mobile.isNotEmpty) {
      notes.add('Mobile: $mobile');
    }

    // Join with " | " separator
    return notes.join(' | ');
  }





// Complete _placeOrder method for PaymentStep class in checkout_flow_screen.dart
// This works with the updated OrderService that handles payment failures
// Replace your existing _placeOrder method entirely with this one

// Complete _placeOrder method for PaymentStep class in checkout_flow_screen.dart
// Replace your existing _placeOrder method with this version that uses your current implementation

Future<void> _placeOrder() async {
  // Save instructions
  widget.checkoutData.specialInstructions = _instructionsController.text;
  
  // Save all checkout data
  await widget.checkoutData.saveToPrefs();
  
  // Validate order data
  if (!_validateOrderData()) {
    return;
  }
  
  setState(() {
    _isPlacingOrder = true;
  });
  
  try {
    // Access logger through provider
    final logger = ref.read(loggerProvider);
    
    logger.log('🚀 === COMPLETE PAYMENT FLOW WITH FAILURE HANDLING STARTED === 🚀');
    logger.log('Payment Method: ${_selectedPaymentMethod!.paymentModeName}');
    logger.log('Delivery Method: ${widget.checkoutData.deliveryMethod}');
    
    // STEP 0: Prepare fresh session and identifiers for new order
    logger.log('=== STEP 0: PREPARING FRESH SESSION FOR NEW ORDER ===');
    
    final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
    
    // Ensure we have a fresh session ready for this new order
    final sessionReady = await enhancedCartValidator.ensureSessionReadyForOrder();
    if (!sessionReady) {
      setState(() {
        _isPlacingOrder = false;
      });
      _showErrorSnackBar("Failed to prepare order session. Please try again.");
      return;
    }
    
    // Prepare completely fresh identifiers for this new order using your existing implementation
    final cartNotifier = ref.read(cartProvider.notifier);
    final freshIdentifiers = await cartNotifier.prepareForNewOrder();
    final currentCartKey = freshIdentifiers['cart_key'];
    final currentDeviceId = freshIdentifiers['device_id'];
    final currentTempOrderId = freshIdentifiers['temp_order_id'];
    
    if (currentCartKey == null || currentDeviceId == null || currentTempOrderId == null) {
      setState(() {
        _isPlacingOrder = false;
      });
      _showErrorSnackBar("Failed to generate order identifiers. Please try again.");
      return;
    }
    
    String deviceId = currentDeviceId;
    String cartKey = currentCartKey;
    String tempOrderId = currentTempOrderId;
    
    logger.log('Fresh identifiers generated:');
    logger.log('- Fresh Temp Order ID: $tempOrderId');
    logger.log('- Fresh Cart Key: $cartKey');
    logger.log('- Device ID: $deviceId');
    
    // Get required data
    final cartItems = ref.read(cartProvider);
    final selectedOutlet = ref.read(selectedOutletProvider).value!;
    
    // Get the user profile to access the access key and mobile number
    final authRepository = ref.read(authRepositoryProvider);
    final userProfile = await authRepository.getUserProfile();
    String? accessKey;
    String? mobileNo;
    
    if (userProfile != null) {
      accessKey = userProfile.accessKey;
      mobileNo = userProfile.mobile;
    }
    
    // Prepare delivery address
    Address deliveryAddress;

    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery) {
      deliveryAddress = widget.checkoutData.selectedAddress!;

      // CRITICAL: Ensure address has valid payment fields for Razorpay
      if (deliveryAddress.mobileNumber.isEmpty ||
          deliveryAddress.fullName.isEmpty) {
        _showErrorSnackBar('Address details incomplete. Cannot process payment. Please select or update your address.');
        setState(() {
          _isPlacingOrder = false;
        });
        return;
      }
    } else {
      // For self pickup, create address from outlet info
      // Ensure mobile number has a valid value
      final mobileForPayment = userProfile?.mobile?.isNotEmpty == true
          ? userProfile!.mobile
          : '9999999999'; // Fallback mobile for payment

      // Generate valid email from mobile or use default
      final emailForPayment = userProfile?.mobile?.isNotEmpty == true
          ? '${userProfile!.mobile}@customer.patelrmart.com'
          : 'orders@patelrmart.com';

      deliveryAddress = Address(
        id: 'pickup_address',
        fullName: widget.checkoutData.pickupName?.trim().isNotEmpty == true
            ? widget.checkoutData.pickupName!
            : (userProfile?.mobile ?? 'Customer'),
        mobileNumber: mobileForPayment,
        emailId: emailForPayment,
        deliveryAddrLine1: selectedOutlet.name,
        deliveryAddrLine2: selectedOutlet.address,
        deliveryAddrCity: 'Store Location',
        deliveryAddrPincode: ref.read(selectedPincodeProvider) ?? '',
        state: '',
        landmark: selectedOutlet.name,
        areaId: selectedOutlet.storeCode,
        isDefault: 'No',
        latitude: selectedOutlet.latitude,
        longitude: selectedOutlet.longitude,
      );
    }
    
    // Get delivery slot and date
    final deliverySlot = widget.checkoutData.deliveryTimeSlot ?? "9:00 AM - 10:00 PM";
    final deliveryDate = widget.checkoutData.deliveryDate?.toIso8601String().split('T')[0] ?? 
                        DateTime.now().add(Duration(days: 1)).toIso8601String().split('T')[0];
    
    // Calculate cart totals
    double cartTotal = 0;
    double cartSavings = 0;
    
    for (final item in cartItems) {
      cartTotal += item.totalPrice;
      cartSavings += item.savings;
    }
    
    // Get delivery charges
    final deliveryChargesState = ref.read(deliveryChargesProvider);
    final deliveryCharge = deliveryChargesState.deliveryCharge;
    
    // Calculate final amount
    final finalAmount = cartTotal + deliveryCharge;
    
    // Get delivery mode and payment mode
    final deliveryMode = widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery 
        ? "Home Delivery"
        : "Self Pickup";
    
    final paymentMode = _selectedPaymentMethod!.paymentModeName;
    
    logger.log('=== ORDER DETAILS ===');
    logger.log('Delivery Mode: $deliveryMode');
    logger.log('Payment Mode: $paymentMode');
    logger.log('Cart Total: ₹${cartTotal.toStringAsFixed(2)}');
    logger.log('Delivery Charge: ₹${deliveryCharge.toStringAsFixed(2)}');
    logger.log('Final Amount: ₹${finalAmount.toStringAsFixed(2)}');
    logger.log('Customer: ${deliveryAddress.fullName}');
    
    // STEP 1: Mark order as "Payment Processing" - CREATE DATABASE ENTRY
    logger.log('=== STEP 1: CREATING DATABASE ENTRY WITH PAYMENT PROCESSING STATUS ===');
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.markingPaymentProcessing;
    
    await enhancedCartValidator.markOrderAsPaymentProcessing(tempOrderId);
    
    print('\n🔄 === STEP 1: CREATING DATABASE ENTRY === 🔄');
    print('Temp Order ID: $tempOrderId');
    print('Payment Mode: $paymentMode');
    print('Amount: ₹${finalAmount.toStringAsFixed(2)}');
    print('Customer: ${deliveryAddress.fullName}');
    print('Database Status: Payment Processing');
    print('🔄 === CALLING PAYMENT PROCESSING API === 🔄\n');
    
    // Call the order payment processing API to create database entry
    final paymentProcessingService = ref.read(orderPaymentProcessingServiceProvider);
    final paymentProcessingResult = await paymentProcessingService.markOrderAsPaymentProcessing(
      deviceId: deviceId,
      tempOrderId: tempOrderId,
      storeCode: selectedOutlet.storeCode,
      cartItems: cartItems,
      deliveryAddress: deliveryAddress,
      deliverySlot: deliverySlot,
      deliveryDate: deliveryDate,
      deliveryMode: deliveryMode,
      paymentMode: paymentMode,
      totalMrp: cartTotal + cartSavings,
      totalOurPrice: cartTotal,
      discount: cartSavings,
      deliveryCharges: deliveryCharge,
      discountedAmount: cartTotal,
      finalPayableAmount: finalAmount,
      accessKey: accessKey,
      mobileNo: mobileNo,
      specialNotes: _buildSpecialNotes(userProfile),
    );
    
    // Store payment processing result
    ref.read(orderPaymentProcessingResultProvider.notifier).state = paymentProcessingResult;
    
    // Check if payment processing API call was successful
    if (!paymentProcessingResult.success) {
      setState(() {
        _isPlacingOrder = false;
      });
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      ref.read(orderErrorMessageProvider.notifier).state = 
        'Failed to create order entry: ${paymentProcessingResult.message}';
      
      // Mark order as failed - this will create a new session automatically
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
      
      _showErrorSnackBar('Failed to create order entry. Please try again.');
      return;
    }
    
    logger.log('✅ DATABASE ENTRY CREATED SUCCESSFULLY');
    logger.log('Order ID: ${paymentProcessingResult.orderId ?? "Generated"}');
    logger.log('Database Status: Payment Processing');
    
    print('\n✅ === STEP 1 COMPLETED: DATABASE ENTRY CREATED === ✅');
    print('Order ID: ${paymentProcessingResult.orderId ?? "Generated"}');
    print('Database Status: Payment Processing');
    print('✅ === PROCEEDING TO PAYMENT === ✅\n');
    
    String? transactionId;
    PaymentResult? paymentResult;
    
    // STEP 2: Process payment (handle both success and failure)
    if (paymentMode.toLowerCase() == "online payment") {
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.processingPayment;
      
      logger.log('=== STEP 2: PROCESSING ONLINE PAYMENT ===');
      logger.log('Payment Method: ${_selectedPaymentMethod!.displayName}');
      logger.log('Final Amount: ₹${finalAmount.toStringAsFixed(2)}');
      
      print('\n💳 === STEP 2: INITIATING ONLINE PAYMENT === 💳');
      print('Amount: ₹${finalAmount.toStringAsFixed(2)}');
      print('Customer: ${deliveryAddress.fullName}');
      print('Phone: ${deliveryAddress.mobileNumber}');
      print('Email: ${deliveryAddress.emailId}');
      print('💳 === OPENING RAZORPAY CHECKOUT === 💳\n');
      
      // Initialize payment service
      final paymentService = ref.read(paymentServiceProvider);
      
      // Start Razorpay payment
      paymentResult = await paymentService.startPayment(
        amount: finalAmount,
        description: 'Order Payment - PatelMart',
        customerName: deliveryAddress.fullName,
        customerEmail: deliveryAddress.emailId,
        customerPhone: deliveryAddress.mobileNumber,
        customOrderId: tempOrderId, // Pass temp order ID as custom order ID
      );
      
      // Store payment result in provider
      ref.read(paymentResultProvider.notifier).state = paymentResult;
      
      logger.log('=== STEP 2 COMPLETED: PAYMENT RESULT ===');
      logger.log('Payment Success: ${paymentResult.success}');
      logger.log('Payment ID: ${paymentResult.paymentId ?? "None"}');
      logger.log('Status: ${paymentResult.status ?? "Unknown"}');
      logger.log('Method: ${paymentResult.method ?? "Unknown"}');
      logger.log('Error Message: ${paymentResult.message ?? "None"}');
      
      if (paymentResult.success) {
        transactionId = paymentResult.paymentId;
        
        print('\n💳 === STEP 2: PAYMENT SUCCESSFUL === 💳');
        print('Payment ID: ${paymentResult.paymentId}');
        print('Status: ${paymentResult.status}');
        print('Method: ${paymentResult.method}');
        print('💳 === PROCEEDING TO ORDER CONFIRMATION === 💳\n');
      } else {
        // Payment failed - but continue to Step 3 to update database with failure
        logger.log('❌ PAYMENT FAILED - CONTINUING TO UPDATE DATABASE WITH FAILURE STATUS');
        logger.log('Payment Error: ${paymentResult.message}');
        logger.log('Will update order status to "Payment Failed"');
        
        print('\n❌ === STEP 2: PAYMENT FAILED === ❌');
        print('Payment Error: ${paymentResult.message}');
        print('Error Code: ${paymentResult.error}');
        print('Still proceeding to update database with failure status');
        print('Database will be updated: Payment Processing → Payment Failed');
        print('❌ === CONTINUING TO ORDER UPDATE === ❌\n');
        
        // Continue to Step 3 with failed payment result
        // transactionId remains null for failed payments
      }
    } else {
      // For COD, create a successful mock payment result
      paymentResult = PaymentResult(
        success: true,
        paymentId: 'COD_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Cash on Delivery',
        fullPaymentData: {
          'payment_method': 'Cash on Delivery',
          'amount': finalAmount,
          'status': 'pending',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
      );
      
      print('\n💰 === STEP 2: CASH ON DELIVERY === 💰');
      print('Payment Method: Cash on Delivery');
      print('No online payment required');
      print('Database will be updated: Payment Processing → Order Confirmed');
      print('💰 === PROCEEDING TO ORDER CONFIRMATION === 💰\n');
    }
    
    // STEP 3: Update order with proper status based on payment result (ALWAYS CALLED)
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.confirmingOrder;
    
    logger.log('=== STEP 3: UPDATING DATABASE WITH FINAL STATUS ===');
    logger.log('Using Temp Order ID: $tempOrderId');
    logger.log('Payment Success: ${paymentResult?.success ?? false}');
    logger.log('Transaction ID: ${transactionId ?? "None"}');
    
    // Determine what the final status should be
    String expectedOrderStatus;
    String expectedPaymentStatus;
    
    if (paymentMode.toLowerCase() == "online payment") {
      if (paymentResult != null && paymentResult.success) {
        expectedOrderStatus = "Order Confirmed";
        expectedPaymentStatus = "Payment Confirmed";
      } else {
        expectedOrderStatus = "Payment Failed";
        expectedPaymentStatus = "Payment Failed";
      }
    } else {
      expectedOrderStatus = "Order Confirmed";
      expectedPaymentStatus = "Pending";
    }
    
    print('\n📋 === STEP 3: UPDATING ORDER WITH FINAL STATUS === 📋');
    print('Temp Order ID: $tempOrderId');
    print('Payment Success: ${paymentResult?.success ?? false}');
    print('Expected Order Status: $expectedOrderStatus');
    print('Expected Payment Status: $expectedPaymentStatus');
    print('Transaction ID: ${transactionId ?? "None"}');
    print('Status Update: Payment Processing → $expectedOrderStatus');
    print('📋 === CALLING ORDER CONFIRMATION API === 📋\n');
    
    // CRITICAL: Call order confirmation API with the payment result (success or failure)
    // The updated OrderService will automatically handle the status based on paymentResult
    final orderService = ref.read(orderServiceProvider);
    final orderResult = await orderService.confirmOrder(
      deviceId: deviceId,
      cartKey: cartKey,
      tempOrderId: tempOrderId, // Same temp order ID to update existing record
      storeCode: selectedOutlet.storeCode,
      cartItems: cartItems,
      deliveryAddress: deliveryAddress,
      deliverySlot: deliverySlot,
      deliveryDate: deliveryDate,
      deliveryMode: deliveryMode,
      paymentMode: paymentMode,
      totalMrp: cartTotal + cartSavings,
      totalOurPrice: cartTotal,
      discount: cartSavings,
      deliveryCharges: deliveryCharge,
      discountedAmount: cartTotal,
      finalPayableAmount: finalAmount,
      paidAmount: (paymentResult?.success == true) ? finalAmount.toString() : "0",
      accessKey: accessKey,
      transactionId: transactionId,
      specialNotes: _buildSpecialNotes(userProfile),
      paymentResult: paymentResult, // Pass the actual payment result (success or failure)
      paymentFormat: PaymentDataFormat.both,
    );
    
    // Store order result
    ref.read(orderConfirmationResultProvider.notifier).state = orderResult;
    
    logger.log('=== STEP 3 COMPLETED: ORDER UPDATE RESULT ===');
    logger.log('Order API Success: ${orderResult.success}');
    logger.log('Order ID: ${orderResult.orderId ?? "None"}');
    logger.log('Expected Status: $expectedOrderStatus');
    logger.log('API Message: ${orderResult.message}');
    
    if (orderResult.success) {
      // API call successful - determine the outcome based on the message or payment result
      if (paymentResult != null && paymentResult.success && paymentMode.toLowerCase() == "online payment") {
        // Successful online payment
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.completed;
        await enhancedCartValidator.markOrderAsCompleted(tempOrderId);
        
        logger.log('✅ ORDER SUCCESSFULLY PLACED AND CONFIRMED');
        logger.log('Order ID: ${orderResult.orderId}');
        logger.log('Database Status: Order Confirmed');
        logger.log('Payment Status: Payment Confirmed');

        print('\n🎉 === ORDER SUCCESSFULLY COMPLETED === 🎉');
        print('Order ID: ${orderResult.orderId}');
        print('Database Status: Order Confirmed');
        print('Payment Status: Payment Confirmed');
        print('Transaction ID: $transactionId');
        print('Payment Processing → Order Confirmed ✅');
        print('🎉 === ORDER FLOW COMPLETED === 🎉\n');

        // Stop checkout timer on successful order completion
        ref.read(checkoutTimerProvider.notifier).stopTimer();

        // Clear cart, checkout data cache, and show success
        await ref.read(cartProvider.notifier).clearCart();
        await CheckoutData.clearFromPrefs();  // Clear cached checkout data including special notes
        setState(() {
          _isPlacingOrder = false;
        });
        _showOrderSuccessDialog(orderResult.orderId ?? tempOrderId);
        
      } else if (paymentMode.toLowerCase() != "online payment") {
        // Cash on Delivery
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.completed;
        await enhancedCartValidator.markOrderAsCompleted(tempOrderId);
        
        logger.log('✅ COD ORDER SUCCESSFULLY PLACED');
        logger.log('Order ID: ${orderResult.orderId}');
        logger.log('Database Status: Order Confirmed');
        logger.log('Payment Status: Pending');
        
        print('\n🎉 === COD ORDER SUCCESSFULLY COMPLETED === 🎉');
        print('Order ID: ${orderResult.orderId}');
        print('Database Status: Order Confirmed');
        print('Payment Status: Pending');
        print('Payment Processing → Order Confirmed ✅');
        print('🎉 === ORDER FLOW COMPLETED === 🎉\n');

        // Stop checkout timer on successful order completion
        ref.read(checkoutTimerProvider.notifier).stopTimer();

        // Clear cart, checkout data cache, and show success
        await ref.read(cartProvider.notifier).clearCart();
        await CheckoutData.clearFromPrefs();  // Clear cached checkout data including special notes
        setState(() {
          _isPlacingOrder = false;
        });
        _showOrderSuccessDialog(orderResult.orderId ?? tempOrderId);
        
      } else {
        // Payment failed but database was updated with failure status
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
        ref.read(orderErrorMessageProvider.notifier).state = 'Payment failed';
        await enhancedCartValidator.markOrderAsFailed(tempOrderId);
        
        logger.log('✅ DATABASE UPDATED WITH PAYMENT FAILURE STATUS');
        logger.log('Order ID: ${orderResult.orderId}');
        logger.log('Database Status: Payment Failed');
        logger.log('Payment Status: Payment Failed');
        
        print('\n❌ === PAYMENT FAILED BUT DATABASE UPDATED === ❌');
        print('Order ID: ${orderResult.orderId}');
        print('Database Status: Payment Failed');
        print('Payment Status: Payment Failed');
        print('Payment Processing → Payment Failed ✅');
        print('Database Updated: ✅');
        print('❌ === ORDER MARKED AS FAILED === ❌\n');
        
        setState(() {
          _isPlacingOrder = false;
        });
        
        // Show payment failure message
        _showErrorSnackBar('Payment failed . Please try again.');
      }
      
    } else {
      // API call itself failed
      setState(() {
        _isPlacingOrder = false;
      });
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      ref.read(orderErrorMessageProvider.notifier).state = orderResult.message;
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
      
      logger.error('❌ Order confirmation API call failed: ${orderResult.message}');
      print('\n❌ === ORDER CONFIRMATION API FAILED === ❌');
      print('Error: ${orderResult.message}');
      print('Database Status: Payment Processing (may be unchanged)');
      print('❌ === ORDER FLOW FAILED === ❌\n');
      
      _showErrorSnackBar('Order confirmation failed: ${orderResult.message}');
    }
    
  } catch (e) {
    setState(() {
      _isPlacingOrder = false;
    });
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
    ref.read(orderErrorMessageProvider.notifier).state = 'Unexpected error: $e';
    
    // Mark order as failed - this will create a new session automatically
    final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
    final prefs = await SharedPreferences.getInstance();
    final tempOrderId = prefs.getString('temp_order_id');
    if (tempOrderId != null) {
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
    }
    
    final logger = ref.read(loggerProvider);
    logger.error('Unexpected error during order placement: $e');
    
    print('\n💥 === UNEXPECTED ERROR === 💥');
    print('Error: $e');
    print('💥 === ORDER FLOW FAILED === 💥\n');
    
    _showErrorSnackBar('An unexpected error occurred. Please try again.');
  }
}
// Enhanced order success dialog
void _showOrderSuccessDialog(String orderId) {
  final paymentResult = ref.read(paymentResultProvider);
  final orderResult = ref.read(orderConfirmationResultProvider);
  final paymentProcessingResult = ref.read(orderPaymentProcessingResultProvider);
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 32,
            ),
            SizedBox(width: 12),
            Text(
              'Order Placed Successfully!',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your order has been successfully placed and is being processed.',
              style: AppTextStyles.bodyMedium,
            ),
            SizedBox(height: 12),
            
            // Order ID
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: $orderId',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  
                  // Payment information
                  if (paymentResult != null && paymentResult.success) ...[
                    SizedBox(height: 8),
                    Text(
                      'Payment ID: ${paymentResult.paymentId}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'Payment Status: Confirmed',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (widget.checkoutData.paymentMethod?.toLowerCase().contains('cod') == true ||
                            widget.checkoutData.paymentMethod?.toLowerCase().contains('pod') == true) ...[
                    SizedBox(height: 8),
                    Text(
                      'Payment: Cash on Delivery',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  
                  // Database status confirmation
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.green[700],
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Order Status: Confirmed',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            Text(
              'You will receive a confirmation message shortly.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            
            // Show delivery information
            if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery) ...[
              SizedBox(height: 12),
              Text(
                'Delivery Details:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Date: ${widget.checkoutData.deliveryDate != null ? _formatDate(widget.checkoutData.deliveryDate!) : "Tomorrow"}',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                'Time: ${widget.checkoutData.deliveryTimeSlot ?? "9:00 AM - 10:00 PM"}',
                style: AppTextStyles.bodySmall,
              ),
            ] else ...[
              SizedBox(height: 12),
              Text(
                'Pickup Details:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ready for pickup within 2-4 hours',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                'Store will call when ready',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              context.go('/'); // Navigate to home
            },
            child: Text(
              'Continue Shopping',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              context.go('/'); // Navigate to home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('View Orders'),
          ),
        ],
      );
    },
  );
}

// Helper method to format date for display
String _formatDate(DateTime date) {
  final now = DateTime.now();
  
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today';
  }
  
  if (date.year == now.year && date.month == now.month && date.day == now.day + 1) {
    return 'Tomorrow';
  }
  
  // Format as "Jan 15, 2025"
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

// Enhanced error display method
// Enhanced order success dialog

// Helper method to format date for display

// Enhanced error display method

// Helper method for CartItem conversion (add this if you need it)
  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method.paymentModeName.toLowerCase()) {
      case 'pod':
        return Icons.money;
      case 'online payment':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodSubtitle(PaymentMethod method, bool isSelfPickup) {
    switch (method.paymentModeName.toLowerCase()) {
      case 'pod':
        return isSelfPickup 
            ? 'Pay when you collect your order' 
            : 'Pay when your order is delivered';
      case 'online payment':
        return 'Pay securely with card, UPI or net banking';
      default:
        return 'Secure payment option';
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProcessStatus = ref.watch(orderProcessStatusProvider);
    final orderError = ref.watch(orderErrorMessageProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Show loading spinner with status message
    if (orderProcessStatus == OrderProcessStatus.validatingCart ||
        orderProcessStatus == OrderProcessStatus.processingPayment ||
        orderProcessStatus == OrderProcessStatus.confirmingOrder) {
      String statusMessage;
      switch (orderProcessStatus) {
        case OrderProcessStatus.validatingCart:
          statusMessage = 'Validating your cart...';
          break;
        case OrderProcessStatus.processingPayment:
          statusMessage = 'Processing payment...';
          break;
        case OrderProcessStatus.confirmingOrder:
          statusMessage = 'Placing your order...';
          break;
        default:
          statusMessage = 'Processing...';
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              statusMessage,
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      );
    }
    
    // If there's an error, display it
    if (orderProcessStatus == OrderProcessStatus.failed && orderError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Order Failed',
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                orderError,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.initial;
                ref.read(orderErrorMessageProvider.notifier).state = null;
              },
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Normal payment flow UI
    final bool isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show store pickup info if self-pickup is selected
                  if (isSelfPickup)
                    _buildStorePickupInfo(),
                  
                  // Order Summary Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ORDER SUMMARY',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCompactOrderSummary(),
                        ],
                      ),
                    ),
                  ),

                  // Pickup name field (only for self-pickup)
                  if (isSelfPickup)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: _pickupNameController,
                        inputFormatters: [NoEmojiInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Pickup Name',
                          hintText: 'Enter your name for pickup',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          widget.checkoutData.pickupName = value;
                        },
                      ),
                    ),

                  // Special instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _instructionsController,
                      inputFormatters: [NoEmojiInputFormatter()],
                      decoration: InputDecoration(
                        hintText: isSelfPickup
                            ? 'Any special instructions for pickup?'
                            : 'Any special instructions for delivery?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ),
                  
                  // Payment methods section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payment,
                          color: AppColors.primary.withOpacity(0.7),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PAYMENT METHOD',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(
                      'Select your preferred payment option',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Payment method options from API
                  _buildPaymentMethodOptions(),
                  
                  // Security info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All transactions are secure and encrypted',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Extra space for scrollability
                  SizedBox(height: 70),
                ],
              ),
            ),
          ),
          
          // Fixed bottom button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 12.0,
              bottom: bottomPadding > 0 ? bottomPadding : 16.0,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isPlacingOrder || _selectedPaymentMethod == null
                    ? null
                    : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isPlacingOrder
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('PLACE ORDER'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOptions() {
    return Consumer(
      builder: (context, ref, child) {
        final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
        
        return paymentMethodsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading payment methods...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          error: (error, stackTrace) {
            ref.read(loggerProvider).error('Error loading payment methods: $error');
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load payment methods',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.refresh(paymentMethodsProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (paymentMethods) {
            if (paymentMethods.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.payment_outlined,
                        color: Colors.orange,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No payment methods available',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please contact support for assistance',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Auto-select first payment method if none selected
            if (_selectedPaymentMethod == null && paymentMethods.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final firstMethod = paymentMethods.first;
                setState(() {
                  _selectedPaymentMethod = firstMethod;
                });
                ref.read(selectedPaymentMethodProvider.notifier).state = firstMethod;
                widget.checkoutData.paymentMethod = firstMethod.paymentModeName;
              });
            }

            return Column(
              children: [
                ...paymentMethods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final method = entry.value;
                  
                  return Column(
                    children: [
                      _buildPaymentMethodOption(method),
                      if (index < paymentMethods.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodOption(PaymentMethod method) {
    final isSelected = _selectedPaymentMethod?.idPaymentMode == method.idPaymentMode;
    final bool isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
    
    return InkWell(
      onTap: () => _selectPaymentMethod(method),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
              radius: 20,
              child: Icon(
                _getPaymentMethodIcon(method),
                color: isSelected ? Colors.white : Colors.grey[700],
                size: 18,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.displayName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getPaymentMethodSubtitle(method, isSelfPickup),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio button
            Radio<int>(
              value: method.idPaymentMode,
              groupValue: _selectedPaymentMethod?.idPaymentMode,
              activeColor: AppColors.primary,
              onChanged: (newValue) {
                if (newValue != null) {
                  _selectPaymentMethod(method);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOrderSummary() {
    return Consumer(
      builder: (context, ref, _) {
        final cartItems = ref.watch(cartProvider);
        final cartTotal = ref.watch(cartTotalProvider);
        final cartSavings = ref.watch(cartSavingsProvider);
        
        // Get delivery charges
        final deliveryChargesState = ref.watch(deliveryChargesProvider);
        final deliveryCharge = deliveryChargesState.deliveryCharge;
        final isFreeDelivery = deliveryChargesState.freeDeliveryEligible;
        final distance = deliveryChargesState.distance;
        
        // Calculate final amount
        final finalAmount = cartTotal + deliveryCharge;
        
        return Column(
          children: [
            // Quick summary with item count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${cartItems.length} items',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '₹${cartTotal.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            
            // Distance information
            if (distance > 0) ...[
              const SizedBox(height: 8),
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
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Delivery charges
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
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (deliveryChargesState.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  deliveryChargesState.isLoading
                      ? 'Calculating...'
                      : isFreeDelivery 
                        ? 'FREE' 
                        : '₹${deliveryCharge.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isFreeDelivery ? Colors.green : null,
                    fontWeight: isFreeDelivery ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            
            // Savings if any
            if (cartSavings > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.savings,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Savings',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${cartSavings.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
            
            const Divider(height: 16),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${finalAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            
            // Free delivery notification
            if (isFreeDelivery && distance > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Free delivery eligible',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  // Build store pickup info from selected outlet data
  Widget _buildStorePickupInfo() {
    return Consumer(
      builder: (context, ref, _) {
        final selectedOutletAsync = ref.watch(selectedOutletProvider);
        
        return selectedOutletAsync.when(
          data: (outlet) {
            if (outlet == null) {
              return const SizedBox.shrink();
            }
            
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Self Pickup Details',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      outlet.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outlet.address,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact: +91 1234567890',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Working Hours: ${outlet.openTime}',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Delivery Time: ${outlet.deliveryTime}',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Store Information Unavailable',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please go back and select a store for pickup.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
  // Widget _buildPaymentMethodOption({
  //   required String title,
  //   required String subtitle,
  //   required IconData icon,
  //   required String value,
  // }) {
  //   final isSelected = _selectedPaymentMethod == value;
    
  //   return InkWell(
  //     onTap: () => _selectPaymentMethod(value),
  //     child: Padding(
  //       padding: const EdgeInsets.symmetric(
  //         horizontal: 16.0,
  //         vertical: 12.0,
  //       ),
  //       child: Row(
  //         children: [
  //           // Icon
  //           CircleAvatar(
  //             backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
  //             radius: 20,
  //             child: Icon(
  //               icon,
  //               color: isSelected ? Colors.white : Colors.grey[700],
  //               size: 18,
  //             ),
  //           ),
            
  //           const SizedBox(width: 16),
            
  //           // Text
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: AppTextStyles.bodyLarge.copyWith(
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //                 Text(
  //                   subtitle,
  //                   style: AppTextStyles.bodySmall.copyWith(
  //                     color: AppColors.textSecondary,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
            
  //           // Radio button
  //           Radio<String>(
  //             value: value,
  //             groupValue: _selectedPaymentMethod,
  //             activeColor: AppColors.primary,
  //             onChanged: (newValue) {
  //               if (newValue != null) {
  //                 _selectPaymentMethod(newValue);
  //               }
  //             },
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
