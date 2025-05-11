// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/cart_validator_provider.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/order_providers.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/reorder_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/outlet_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../account/address_book_screen.dart';
import 'package:patelmart/presentation/providers/cart_validator_provider.dart' as validator;


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

  CheckoutData({
    this.deliveryMethod,
    this.selectedAddress,
    this.deliveryDate,
    this.deliveryTimeSlot,
    this.specialInstructions,
    this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'deliveryMethod': deliveryMethod?.index,
      'selectedAddress': selectedAddress?.toJson(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'deliveryTimeSlot': deliveryTimeSlot,
      'specialInstructions': specialInstructions,
      'paymentMethod': paymentMethod,
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
  }

  Future<void> _loadCheckoutData() async {
    setState(() {
      _isLoading = true;
    });

    // Load saved checkout data if any
    _checkoutData = await CheckoutData.loadFromPrefs();

    setState(() {
      _isLoading = false;
    });
  }

  void _goToNextStep() {
    setState(() {
      switch (_currentStep) {
        case CheckoutStep.delivery:
          // If delivery method is self pickup, skip directly to payment
          if (_checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
            _currentStep = CheckoutStep.payment;
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
                              '₹${(item.product.ourPrice * item.quantity).toStringAsFixed(2)}',
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
                
                // Order summary
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivery Fee',
                            style: AppTextStyles.bodyMedium,
                          ),
                          Text(
                            'FREE',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Savings',
                            style: AppTextStyles.bodyMedium,
                          ),
                          Text(
                            '- ₹${cartSavings.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
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
                            '₹${cartTotal.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (cartSavings > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
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
                        ),
                    ],
                  ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_currentStep == CheckoutStep.delivery) {
              context.pop();
            } else {
              // Handle back navigation for self-pickup case
              if (_checkoutData.deliveryMethod == DeliveryMethod.selfPickup && 
                  _currentStep == CheckoutStep.payment) {
                setState(() {
                  _currentStep = CheckoutStep.delivery;
                });
              } else {
                setState(() {
                  _currentStep = CheckoutStep.values[_currentStep.index - 1];
                });
              }
            }
          },
        ),
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
    );
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
      // For self-pickup, only show delivery and payment steps
      stepsToShow = [CheckoutStep.delivery, CheckoutStep.payment];
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
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: AppTextStyles.h6,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cartItems.length} item(s)',
                style: AppTextStyles.bodyMedium,
              ),
              Text(
                '₹${cartTotal.toStringAsFixed(2)}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (cartSavings > 0)
            Text(
              'You saved: ₹${cartSavings.toStringAsFixed(2)}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.purple,
              ),
            ),
          InkWell(
            onTap: () {
              // Show detailed order summary in a modal bottom sheet
              _showOrderDetailsBottomSheet(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    'View details',
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
}

// STEP 1: Delivery Method Step
class DeliveryMethodStep extends StatefulWidget {
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
  State<DeliveryMethodStep> createState() => _DeliveryMethodStepState();
}

class _DeliveryMethodStepState extends State<DeliveryMethodStep> {
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
    
    // If self-pickup is selected, immediately proceed to payment
    if (method == DeliveryMethod.selfPickup && widget.onSelfPickupSelected != null) {
      widget.onSelfPickupSelected!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        
        // Home Delivery Option
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildDeliveryOption(
            title: 'Home Delivery',
            subtitle: 'Delivered to your doorstep',
            icon: Icons.home,
            method: DeliveryMethod.homeDelivery,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Self Pickup Option
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildDeliveryOption(
            title: 'Self Pickup',
            subtitle: 'Collect from our store',
            icon: Icons.store,
            method: DeliveryMethod.selfPickup,
          ),
        ),
        
        const Spacer(),
        
        // Order Total Section
        _buildOrderTotal(),
        
        // Continue Button - Only shown for home delivery
        if (_selectedMethod == DeliveryMethod.homeDelivery)
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
  }) {
    final isSelected = _selectedMethod == method;
    
    return InkWell(
      onTap: () => _selectDeliveryMethod(method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
              radius: 24,
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
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
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
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
              onChanged: (value) {
                if (value != null) {
                  _selectDeliveryMethod(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTotal() {
    return Consumer(
      builder: (context, ref, _) {
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
                    deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(2)}' : 'FREE',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: deliveryFee > 0 ? null : Colors.purple,
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
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// STEP 2: Delivery Address Step
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

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch addresses from the provider
      final addressesAsync = ref.read(addressesProvider.future);
      _addresses = await addressesAsync;
      
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
      print('Error loading addresses: $e');
      // Handle error loading addresses
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
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildNoAddressesView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
        Text(
          'Please add a delivery address to continue',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // Navigate to add address screen
            context.push('/add-address');
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
          child: Row(
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
        ),
      ),
    );
  }

  Widget _buildOrderTotal() {
    return Consumer(
      builder: (context, ref, _) {
        final cartTotal = ref.watch(cartTotalProvider);
        final cartSavings = ref.watch(cartSavingsProvider);
        
        // Free delivery in this case
        const deliveryFee = 0.0;
        
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
                    'FREE',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
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
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// STEP 3: Delivery Time Step
class DeliveryTimeStep extends StatefulWidget {
  final CheckoutData checkoutData;
  final VoidCallback onContinue;

  const DeliveryTimeStep({
    Key? key,
    required this.checkoutData,
    required this.onContinue,
  }) : super(key: key);

  @override
  State<DeliveryTimeStep> createState() => _DeliveryTimeStepState();
}

class _DeliveryTimeStepState extends State<DeliveryTimeStep> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  late List<DateTime> _availableDates;
  late Map<String, List<String>> _timeSlots;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.checkoutData.deliveryDate;
    _selectedTimeSlot = widget.checkoutData.deliveryTimeSlot;
    _initializeAvailableDates();
    _initializeTimeSlots();
    
    // If we have a date but no time slot, or neither, initialize them
    if (_selectedDate == null) {
      _selectedDate = _availableDates.first;
      widget.checkoutData.deliveryDate = _selectedDate;
    }
    
    // If we don't have a time slot selected, but we have a date, select first slot
    if (_selectedTimeSlot == null) {
      final dateSlotsKey = _formatDateKey(_selectedDate!);
      if (_timeSlots.containsKey(dateSlotsKey) && _timeSlots[dateSlotsKey]!.isNotEmpty) {
        _selectedTimeSlot = _timeSlots[dateSlotsKey]!.first;
        widget.checkoutData.deliveryTimeSlot = _selectedTimeSlot;
      }
    }
  }

  void _initializeAvailableDates() {
    // Generate dates for the next 3 days
    final now = DateTime.now();
    _availableDates = List.generate(3, (index) {
      return DateTime(now.year, now.month, now.day + index);
    });
  }

  void _initializeTimeSlots() {
    // Initialize time slots for each date
    _timeSlots = {};
    for (final date in _availableDates) {
      final key = _formatDateKey(date);
      
      // Different time slots based on the date (for demonstration)
      if (date.day % 2 == 0) {
        _timeSlots[key] = [
          '09:00 AM - 12:00 PM',
          '01:00 PM - 04:00 PM',
          '05:00 PM - 08:00 PM',
        ];
      } else {
        _timeSlots[key] = [
          '10:00 AM - 01:00 PM',
          '02:00 PM - 05:00 PM',
          '06:00 PM - 09:00 PM',
        ];
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
        _selectedTimeSlot = _timeSlots[key]!.first;
      } else {
        _selectedTimeSlot = null;
      }
    });
    
    // Update checkout data
    widget.checkoutData.deliveryDate = date;
    widget.checkoutData.deliveryTimeSlot = _selectedTimeSlot;
  }

  void _selectTimeSlot(String timeSlot) {
    setState(() {
      _selectedTimeSlot = timeSlot;
    });
    widget.checkoutData.deliveryTimeSlot = timeSlot;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Choose Delivery Time',
            style: AppTextStyles.h5,
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Select delivery time slot',
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
          child: ListView.builder(
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
            child: ElevatedButton(
              onPressed: _selectedTimeSlot == null ? null : widget.onContinue,
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

  Widget _buildTimeSlots() {
    if (_selectedDate == null) {
      return const Center(
        child: Text('Please select a date first'),
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
              'Please select a different date',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
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
          child: Text(
            _formatDateDisplay(_selectedDate!),
            style: AppTextStyles.h6,
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
              final isSelected = _selectedTimeSlot == slot;
              
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
                        slot,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Available',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.green,
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
                    'FREE',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
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
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// STEP 4: Payment Step
// STEP 4: Payment Step
// Updated PaymentStep implementation for the CheckoutFlowScreen

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
  String? _selectedPaymentMethod;
  final TextEditingController _instructionsController = TextEditingController();
  bool _isPlacingOrder = false;
  bool _showSuccessDialog = false;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.checkoutData.paymentMethod ?? 'COD';
    _instructionsController.text = widget.checkoutData.specialInstructions ?? '';
    
    // Reset the order state when initializing the payment step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.initial;
      ref.read(orderErrorMessageProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  void _selectPaymentMethod(String method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
    widget.checkoutData.paymentMethod = method;
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
  

// This snippet shows the changes needed in the checkout_flow_screen.dart file
// for the _placeOrder method to use the new parameters

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
    
    // Update order process status
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.validatingCart;
    
    // Get required data
    final cartItems = ref.read(cartProvider);
    final selectedOutlet = ref.read(selectedOutletProvider).value!;
    final cartValidator = ref.read(validator.cartValidatorProvider);

    // Get the current cart key, device ID, and temp order ID before proceeding
    final currentCartKey = await cartValidator.getCurrentCartKey();
    final currentDeviceId = await cartValidator.getCurrentDeviceId();
    final currentTempOrderId = await cartValidator.getCurrentTempOrderId();
    
    // If any required values are missing, show error
    if (currentCartKey == null || currentDeviceId == null || currentTempOrderId == null) {
      setState(() {
        _isPlacingOrder = false;
      });
      _showErrorSnackBar("Cart information is missing. Please try again.");
      return;
    }
    
    String deviceId = currentDeviceId;
    String cartKey = currentCartKey;
    String tempOrderId = currentTempOrderId;
    
    logger.log('Using existing cart identifiers for reference: cartKey=$cartKey, deviceId=$deviceId, tempOrderId=$tempOrderId');
    
    // Convert delivery address to API format
    final Address deliveryAddress = widget.checkoutData.selectedAddress ?? 
        Address(
          id: '1',
          fullName: 'Guest User',
          mobileNumber: '',
          emailId: '',
          deliveryAddrLine1: '',
          deliveryAddrLine2: '',
          deliveryAddrCity: '',
          deliveryAddrPincode: '',
          isDefault: 'No',
          areaId: '1',
          landmark: '',
          state: '',
        );
    
    final Map<String, dynamic> formattedAddress = {
      "full_name": deliveryAddress.fullName,
      "contact_no": deliveryAddress.mobileNumber,
      "email": deliveryAddress.emailId,
      "address_1": deliveryAddress.deliveryAddrLine1,
      "address_2": deliveryAddress.deliveryAddrLine2,
      "area": deliveryAddress.areaId,
      "landmart": deliveryAddress.landmark, // Note the API expects "landmart" not "landmark"
      "city": deliveryAddress.deliveryAddrCity,
      "state": deliveryAddress.state,
    };
    
    // Calculate order amounts
    final cartTotal = ref.read(cartTotalProvider);
    final cartSavings = ref.read(cartSavingsProvider);
    final deliveryCharge = 0.0; // Assuming free delivery, modify as needed
    final finalAmount = cartTotal + deliveryCharge;
    
    // Determine delivery mode
    final deliveryMode = widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery
        ? "Home Delivery"
        : "Self Pickup";
    
    // Determine payment mode for API
    final paymentMode = _selectedPaymentMethod == "CARD" || _selectedPaymentMethod == "UPI" || _selectedPaymentMethod == "NET_BANKING"
        ? "ONLINE"
        : "POD";
    
    String? transactionId;
    
    // Handle online payment if selected
    if (paymentMode == "ONLINE") {
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.processingPayment;
      
      // Initialize payment service
      final paymentService = ref.read(paymentServiceProvider);
      
      // Start Razorpay payment
      final paymentResult = await paymentService.startPayment(
        amount: finalAmount,
        description: 'Order Payment',
        customerName: deliveryAddress.fullName,
        customerEmail: deliveryAddress.emailId,
        customerPhone: deliveryAddress.mobileNumber,
      );
      
      // Store payment result
      ref.read(paymentResultProvider.notifier).state = paymentResult;
      
      if (!paymentResult.success) {
        // Payment failed or was cancelled
        ref.read(orderErrorMessageProvider.notifier).state = 
            paymentResult.message ?? 'Payment failed. Please try again.';
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
        
        if (mounted) {
          setState(() {
            _isPlacingOrder = false;
          });
          _showErrorSnackBar(paymentResult.message ?? 'Payment failed. Please try again.');
        }
        return;
      }
      
      // Set transaction ID from payment
      transactionId = paymentResult.paymentId;
      logger.log('Payment successful with transaction ID: $transactionId');
    }
    
    // Continue with order confirmation
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.confirmingOrder;
    
    // Get delivery date and time slot
    final String deliveryDate = widget.checkoutData.deliveryDate != null
        ? '${widget.checkoutData.deliveryDate!.year}-${widget.checkoutData.deliveryDate!.month.toString().padLeft(2, '0')}-${widget.checkoutData.deliveryDate!.day.toString().padLeft(2, '0')}'
        : DateTime.now().add(Duration(days: 1)).toString().split(' ')[0];
    
    final String deliverySlot = widget.checkoutData.deliveryTimeSlot ?? "Standard Delivery";
    
    // Log order details before sending
    logger.log('Sending order confirmation with identifiers: deviceId=$deviceId, tempOrderId=$tempOrderId');
    logger.log('Order details: ${cartItems.length} items, $deliveryMode, $paymentMode');
    
    // Call order service to confirm order, passing all three identifiers
    final orderService = ref.read(orderServiceProvider);
    final orderResult = await orderService.confirmOrder(
      deviceId: deviceId,
      cartKey: cartKey,  // This will be used as reference only
      tempOrderId: tempOrderId,
      storeCode: selectedOutlet.storeCode,
      cartItems: cartItems,
      deliveryAddress: formattedAddress,
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
      paidAmount: paymentMode == "ONLINE" ? finalAmount.toString() : "0",
      transactionId: transactionId,
      specialNotes: _instructionsController.text,
    );
    
    // Store order result
    ref.read(orderConfirmationResultProvider.notifier).state = orderResult;
    
    if (orderResult.success) {
      // Order confirmed successfully
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.completed;
      
      // Clear cart after successful order
      ref.read(cartProvider.notifier).clearCart();
      
      // Clear the cart data (ONLY cart key, but keep device ID and temp order ID for consistency)
      await cartValidator.clearCartData();
      
      // Clear checkout data
      await CheckoutData.clearFromPrefs();
      final createOrder = ref.read(createOrderFromCartProvider);
   final orderRecord = await createOrder(
  paymentMode, // Use actual payment method from your existing code
  deliveryMode,
  deliverySlot,
  formattedAddress.toString(),
);

if (orderRecord == null) {
  // Order was placed successfully with the server but failed to save locally
  logger.error('Failed to save order to local history');
  // This isn't critical, so we still allow the order completion to proceed
}

if (mounted) {
  setState(() {
    _isPlacingOrder = false;
    _showSuccessDialog = true;
  });
  _showOrderSuccessDialog();
}
      
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
          _showSuccessDialog = true;
        });
        _showOrderSuccessDialog();
      }
    } else {
      // Order confirmation failed
      ref.read(orderErrorMessageProvider.notifier).state = orderResult.message;
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
        _showErrorSnackBar(orderResult.message);
      }
    }
  } catch (e) {
    // Handle unexpected errors
    final logger = ref.read(loggerProvider);
    logger.error('Error placing order: $e');
    ref.read(orderErrorMessageProvider.notifier).state = e.toString();
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
    
    if (mounted) {
      setState(() {
        _isPlacingOrder = false;
      });
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
    }
  }
}

  void _showOrderSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent dismissing by back button
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Order Placed Successfully!',
                  style: AppTextStyles.h5,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup
                      ? 'Your order has been placed successfully. You can collect it from our store.'
                      : 'Your order has been placed successfully. You can track your order in the Orders section.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate back to home
                      context.go('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('CONTINUE SHOPPING'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Return the payment method display name
  String _getPaymentMethodDisplayName(String method) {
    switch (method) {
      case 'COD':
        return 'Cash on Delivery';
      case 'CARD':
        return 'Credit/Debit Card';
      case 'UPI':
        return 'UPI';
      case 'NET_BANKING':
        return 'Net Banking';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProcessStatus = ref.watch(orderProcessStatusProvider);
    final orderError = ref.watch(orderErrorMessageProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Show loading spinner with status message based on the current order process status
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
                // Reset the order state and try again
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
                  
                  // Special instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _instructionsController,
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
                  
                  // Payment methods
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
                  
                  // Payment method options
                  _buildPaymentMethodOption(
                    title: 'Cash on Delivery',
                    subtitle: isSelfPickup ? 'Pay when you collect your order' : 'Pay when your order is delivered',
                    icon: Icons.money,
                    value: 'COD',
                  ),
                  const Divider(height: 1),
                  _buildPaymentMethodOption(
                    title: 'Credit/Debit Card',
                    subtitle: 'Pay securely with your card',
                    icon: Icons.credit_card,
                    value: 'CARD',
                  ),
                  const Divider(height: 1),
                  _buildPaymentMethodOption(
                    title: 'UPI',
                    subtitle: 'Pay using UPI apps',
                    icon: Icons.account_balance,
                    value: 'UPI',
                  ),
                  const Divider(height: 1),
                  _buildPaymentMethodOption(
                    title: 'Net Banking',
                    subtitle: 'Pay using net banking',
                    icon: Icons.account_balance_wallet,
                    value: 'NET_BANKING',
                  ),
                  
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
                  
                  // Order summary
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildOrderSummary(),
                  ),
                  
                  // Extra space to ensure scrollability
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

  // Build store pickup info from selected outlet data
  Widget _buildStorePickupInfo() {
    return Consumer(
      builder: (context, ref, _) {
        final selectedOutletAsync = ref.watch(selectedOutletProvider);
        
        return selectedOutletAsync.when(
          data: (outlet) {
            if (outlet == null) {
              return const SizedBox.shrink(); // No outlet selected
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
                    // Display contact information if available, otherwise show a default
                    Text(
                      'Contact: +91 1234567890', // Usually outlets would have contact info
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
  
  Widget _buildPaymentMethodOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    
    return InkWell(
      onTap: () => _selectPaymentMethod(value),
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
                icon,
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
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio button
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              activeColor: AppColors.primary,
              onChanged: (newValue) {
                if (newValue != null) {
                  _selectPaymentMethod(newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Consumer(
      builder: (context, ref, _) {
        final cartTotal = ref.watch(cartTotalProvider);
        final cartSavings = ref.watch(cartSavingsProvider);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL AMOUNT',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '₹${cartTotal.toStringAsFixed(2)}',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (cartSavings > 0)
              Text(
                'You saved ₹${cartSavings.toStringAsFixed(2)} on this order',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.orange,
                ),
                textAlign: TextAlign.right,
              ),
          ],
        );
      },
    );
  }
}