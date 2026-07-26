// Checkout step 1 of 4 — delivery method. Split out of checkout_flow_screen.dart.
// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/features/outlet_status/outlet_status_banner.dart';
import 'package:patelmart/presentation/providers/outlet_status_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/cart_provider.dart';
// FACEBOOK PIXEL IMPORTS
import 'package:flutter/foundation.dart';
import '../checkout_models.dart';

// Checkout step enum to track progress

class DeliveryMethodStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;
  final VoidCallback onContinue;
  final VoidCallback? onSelfPickupSelected;

  const DeliveryMethodStep({
    super.key,
    required this.checkoutData,
    required this.onContinue,
    this.onSelfPickupSelected,
  });

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

