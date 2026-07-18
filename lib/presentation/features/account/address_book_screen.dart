// lib/presentation/features/account/address_book_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../data/models/address_model.dart';
import '../../../data/repositories/address_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/location_provider.dart';

// Address list provider backed by the universal backend via AddressRepository
final addressListProvider = FutureProvider.autoDispose<List<Address>>((ref) async {
  final logger = ref.read(loggerProvider);
  final repository = ref.read(addressRepositoryProvider);

  logger.log('Fetching addresses from universal backend...');
  final addresses = await repository.getAddresses();
  logger.log('Fetched ${addresses.length} address(es)');
  return addresses;
});

// Provider to refresh addresses when needed
final refreshAddressListProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.invalidate(addressListProvider);
    await ref.read(addressListProvider.future);
  };
});

// Main Address Book Screen
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({Key? key}) : super(key: key);

  // Custom back navigation handler - matches the pattern from other screens
  Future<bool> _handleBackPress(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on AddressBookScreen - navigating to account');
    
    try {
      // Navigate to account using go
      context.go('/account');
      
      // Return false to prevent default back navigation
      return false;
    } catch (e) {
      logger.error('Error handling back navigation: $e');
      // If go fails, try push as fallback
      if (context.mounted) {
        context.pushReplacement('/account');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the updated address list provider with centralized access key management
    final addressesAsyncValue = ref.watch(addressListProvider);
    final logger = ref.read(loggerProvider);
    
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted on AddressBookScreen - going to account');
          
          // Navigate to account
          if (context.mounted) {
            context.go('/account');
          }
        }
      },
      child: WillPopScope(
        onWillPop: () => _handleBackPress(context, ref),
        child: BackButtonWrapper(
          child: Scaffold(
            backgroundColor: Colors.white, // Set white background
            appBar: AppBar(
              title: const Text('Address Book'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  final logger = ref.read(loggerProvider);
                  logger.log('Address Book back button pressed');
                  // Use the same navigation logic as the hardware back button
                  _handleBackPress(context, ref);
                },
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            body: SafeArea(
              child: addressesAsyncValue.when(
                data: (addresses) {
                  logger.log('Rendering ${addresses.length} addresses');
                  return _buildAddressList(context, ref, addresses);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) {
                  logger.error('Error loading addresses: $error');
                  return AppErrorWidget(
                    errorType: ErrorType.network,
                    message: 'Failed to load addresses: $error',
                    onRetry: () => ref.refresh(addressListProvider),
                  );
                },
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => context.push('/add-address'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressList(BuildContext context, WidgetRef ref, List<Address> addresses) {
    if (addresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No addresses found',
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first delivery address',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-address'),
              icon: const Icon(Icons.add),
              label: const Text('ADD NEW ADDRESS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: addresses.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final address = addresses[index];
        return _buildAddressCard(context, ref, address);
      },
    );
  }

  Widget _buildAddressCard(BuildContext context, WidgetRef ref, Address address) {
    final isDefault = address.isDefault.toLowerCase() == 'yes';
    final logger = ref.read(loggerProvider);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDefault ? AppColors.primary : Colors.transparent,
          width: isDefault ? 1 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.fullName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        address.mobileNumber,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '${address.deliveryAddrLine1}, ${address.deliveryAddrLine2}',
              style: AppTextStyles.bodyMedium,
            ),
            Text(
              '${address.deliveryAddrCity} - ${address.deliveryAddrPincode}',
              style: AppTextStyles.bodyMedium,
            ),
            if (address.landmark.isNotEmpty)
              Text(
                'Landmark: ${address.landmark}',
                style: AppTextStyles.bodyMedium,
              ),
            if (address.state.isNotEmpty)
              Text(
                'State: ${address.state}',
                style: AppTextStyles.bodyMedium,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _navigateToEditAddress(context, ref, address, logger);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('EDIT'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                if (!isDefault)
                  TextButton.icon(
                    onPressed: () {
                      _setAsDefault(context, ref, address, logger);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Set Default'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () {
                    _showDeleteConfirmation(context, ref, address, logger);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('DELETE'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditAddress(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Preparing to edit address: ${address.id}');
    
    try {
      // Get current app data to update the address with current pincode and mobile
      String currentPincode = address.deliveryAddrPincode; // fallback
      String currentMobile = address.mobileNumber; // fallback
      
      // Get current selected pincode from the app
      try {
        final selectedPincode = ref.read(selectedPincodeProvider);
        if (selectedPincode != null && selectedPincode.isNotEmpty) {
          currentPincode = selectedPincode;
          logger.log('Using current app pincode: $currentPincode');
        } else {
          logger.warning('No current pincode selected, using stored address pincode: $currentPincode');
        }
      } catch (e) {
        logger.error('Error getting current pincode: $e');
      }
      
      // Get current user mobile from auth provider
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        if (userProfile != null && userProfile.mobile.isNotEmpty) {
          currentMobile = userProfile.mobile;
          logger.log('Using current user mobile: $currentMobile');
        } else {
          logger.warning('No current user mobile, using stored address mobile: $currentMobile');
        }
      } catch (e) {
        logger.error('Error getting current user mobile: $e');
      }
      
      // Create an updated address with current app data for pincode and mobile
      final updatedAddress = address.copyWith(
        deliveryAddrPincode: currentPincode,
        mobileNumber: currentMobile,
      );
      
      // Store the updated address in shared preferences for the edit screen to access
      final prefs = await SharedPreferences.getInstance();
      final addressJson = jsonEncode(updatedAddress.toJson());
      
      logger.log('Saving updated address to edit with current app data: $addressJson');
      await prefs.setString('address_to_edit', addressJson);
      
      if (context.mounted) {
        context.push('/edit-address');
      }
    } catch (e) {
      logger.error('Error preparing address for editing: $e');
      
      // Fallback: use original address if updating fails
      final prefs = await SharedPreferences.getInstance();
      final addressJson = jsonEncode(address.toJson());
      await prefs.setString('address_to_edit', addressJson);
      
      if (context.mounted) {
        context.push('/edit-address');
      }
    }
  }

  // Updated implementation using centralized access key management
  // Set default via the universal backend (update-address with is_default Yes)
  void _setAsDefault(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Setting address as default: ${address.id}');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repository = ref.read(addressRepositoryProvider);
      final success = await repository.setDefaultAddress(address.id);

      if (context.mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Address set as default'
                  : 'Failed to set address as default',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          ref.refresh(addressListProvider);
        }
      }
    } catch (e) {
      logger.error('Error setting address as default: $e');

      if (context.mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting address as default: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Address address, Logger logger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // Close the confirmation dialog
              Navigator.pop(context);
              // Call the delete function
              _deleteAddress(context, ref, address, logger);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // Delete via the universal backend (DELETE /api/address-crud/delete-address/:id)
  void _deleteAddress(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Deleting address: ${address.id}');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repository = ref.read(addressRepositoryProvider);
      final success = await repository.deleteAddress(address.id);

      if (context.mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Address deleted successfully'
                  : 'Failed to delete address',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          ref.refresh(addressListProvider);
        }
      }
    } catch (e) {
      logger.error('Error deleting address: $e');

      if (context.mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
