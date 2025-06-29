// lib/presentation/features/store/store_info_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/outlet_model.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';

class StoreInfoScreen extends ConsumerWidget {
  const StoreInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final selectedPincode = ref.watch(selectedPincodeProvider);

    return PopScope(
      // This prevents the automatic pop behavior
      canPop: false,
      // Handle the back button press
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Navigate to home when back is pressed
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Added white background color
        appBar: AppBar(
          title: const Text('Store Information'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: SafeArea(
          child: selectedOutletAsync.when(
            data: (outlet) {
              if (outlet == null) {
                return _buildNoStoreSelected(context);
              }
              return _buildStoreInfo(context, outlet, selectedPincode);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error: ${error.toString()}'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoStoreSelected(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 80,
            color: AppColors.neutral500,
          ),
          const SizedBox(height: 16),
          Text(
            'No Store Selected',
            style: AppTextStyles.h5,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Please select a store to view its information.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/location-change'),
            child: const Text('Select Store'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfo(BuildContext context, OutletModel outlet, String? pincode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Card
          Card(
            color: Colors.white, // Added white background color for card
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 24,
                        child: Icon(
                          Icons.store,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outlet.name,
                              style: AppTextStyles.h5,
                            ),
                            Text(
                              'Store Code: ${outlet.storeCode}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.location_on, 'Address', outlet.address),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time,
                    'Opening Hours',
                    outlet.openTime,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.delivery_dining,
                    'Delivery Time',
                    outlet.deliveryTime,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.shopping_bag_outlined,
                    'Minimum Order',
                    '₹${outlet.minOrderAmount}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.local_offer,
                    'Offer',
                    outlet.offerName,
                  ),
                  if (outlet.latitude.isNotEmpty && outlet.longitude.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.map,
                      'Coordinates',
                      '${outlet.latitude}, ${outlet.longitude}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_city,
                    'Serving Pincode',
                    pincode ?? 'Unknown',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Change Store Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/location-change'),
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Change Pincode'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}