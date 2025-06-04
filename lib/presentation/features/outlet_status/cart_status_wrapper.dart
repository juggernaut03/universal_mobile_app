// lib/presentation/widgets/cart_status_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/presentation/features/outlet_status/outlet_status_banner.dart';
import 'package:patelmart/presentation/providers/outlet_status_provider.dart';


/// Wrapper widget that checks if cart operations should be allowed
class CartStatusWrapper extends ConsumerWidget {
  final Widget child;
  final Widget? customDisabledWidget;
  final bool showStatusBanner;

  const CartStatusWrapper({
    Key? key,
    required this.child,
    this.customDisabledWidget,
    this.showStatusBanner = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);
    
    return Column(
      children: [
        // Status banner if requested
        if (showStatusBanner) const OutletStatusBanner(),
        
        // Main content or disabled state
        Expanded(
          child: outletStatusAsync.when(
            data: (status) {
              if (status == null || isCartEnabled) {
                return child;
              }
              
              return customDisabledWidget ?? _buildDisabledState(context, ref, status);
            },
            loading: () => child, // Show content while loading
            error: (error, stackTrace) => child, // Show content on error (fail-safe)
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledState(BuildContext context, WidgetRef ref, status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: 24),
            Text(
              'Cart Temporarily Unavailable',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              status.statusMessage,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
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
                // const SizedBox(width: 5),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/location-change');
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('Change store'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}