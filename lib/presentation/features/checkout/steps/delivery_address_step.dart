// Checkout step 2 of 4 — delivery address. Split out of checkout_flow_screen.dart.
// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/presentation/providers/address_provider.dart';
import 'package:patelmart/presentation/providers/delivery_charges_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/cart_provider.dart';
import 'package:patelmart/presentation/providers/address_provider.dart' as address;
// FACEBOOK PIXEL IMPORTS
import '../../../../di/infrastructure_providers.dart';
import '../checkout_models.dart';

// Checkout step enum to track progress

class DeliveryAddressStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;
  final VoidCallback onContinue;

  const DeliveryAddressStep({
    super.key,
    required this.checkoutData,
    required this.onContinue,
  });

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
      // See the matching comment in delivery_time_step.dart: handling/
      // packaging are store-configured flat fees that free delivery does
      // NOT waive, so they're their own line items rather than folded into
      // "Delivery Fee".
      final distanceCharge = deliveryChargesState.distanceCharge;
      final handlingFee = deliveryChargesState.handlingFee;
      final packageFee = deliveryChargesState.packageFee;

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
                    : (isFreeDelivery && distanceCharge <= 0)
                      ? 'FREE'
                      : '₹${distanceCharge.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: (isFreeDelivery && distanceCharge <= 0) ? Colors.green : null,
                    fontWeight: (isFreeDelivery && distanceCharge <= 0) ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),

            // Handling fee — store-configured flat charge (admin panel),
            // shown only when the store actually has one set.
            if (!isLoading && handlingFee > 0) ...[
              const SizedBox(height: 8),
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
                        'Handling Fee:',
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
            ],

            // Packaging fee — same idea, shown only when set.
            if (!isLoading && packageFee > 0) ...[
              const SizedBox(height: 8),
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
                        'Packaging Fee:',
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
            ],

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

