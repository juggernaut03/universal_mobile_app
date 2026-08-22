// lib/presentation/features/account/address_book_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../../presentation/widgets/back_button_wrapper.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../data/models/address_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/location_provider.dart';
import '../../../di/repository_providers.dart';
import '../../../di/infrastructure_providers.dart';
import '../../providers/address_provider.dart';



// Main Address Book Screen
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

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
            backgroundColor: AppColors.neutral50,
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
              elevation: 0,
            ),
            body: SafeArea(
              child: addressesAsyncValue.when(
                data: (addresses) {
                  logger.log('Rendering ${addresses.length} addresses');
                  return _buildAddressList(context, ref, addresses);
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
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
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.push('/add-address'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Address',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressList(BuildContext context, WidgetRef ref, List<Address> addresses) {
    if (addresses.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 64,
                        color: AppColors.primary.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No saved addresses',
                      style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a delivery address to check out faster next time.',
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: addresses.length,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemBuilder: (context, index) {
        final address = addresses[index];
        return _buildAddressCard(context, ref, address);
      },
    );
  }

  /// Joins the non-empty parts of an address into one flowing line — the
  /// naive '${line1}, ${line2}' the old layout used printed a trailing ", "
  /// (or a bare "test, test") whenever a field was empty or duplicated.
  String _formatAddressLines(Address address) {
    final parts = [
      address.deliveryAddrLine1,
      address.deliveryAddrLine2,
      address.landmark,
    ].where((p) => p.trim().isNotEmpty).toSet(); // dedupe accidental repeats

    return parts.join(', ');
  }

  String _formatCityLine(Address address) {
    final cityState = [address.deliveryAddrCity, address.state]
        .where((p) => p.trim().isNotEmpty)
        .toSet()
        .join(', ');
    return [cityState, address.deliveryAddrPincode]
        .where((p) => p.trim().isNotEmpty)
        .join(' - ');
  }

  Widget _buildAddressCard(BuildContext context, WidgetRef ref, Address address) {
    final isDefault = address.isDefault.toLowerCase() == 'yes';
    final logger = ref.read(loggerProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDefault ? AppColors.primary.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDefault ? AppColors.primary.withOpacity(0.35) : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.12),
                ),
                child: Icon(Icons.location_on, color: AppColors.primary, size: 22),
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
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          address.mobileNumber,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'DEFAULT',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          Text(
            _formatAddressLines(address),
            style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
          ),
          const SizedBox(height: 2),
          Text(
            _formatCityLine(address),
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AddressActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: AppColors.primary,
                  onTap: () => _navigateToEditAddress(context, ref, address, logger),
                ),
              ),
              if (!isDefault) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _AddressActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Set Default',
                    color: AppColors.success,
                    onTap: () => _setAsDefault(context, ref, address, logger),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _AddressActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: AppColors.error,
                  onTap: () => _showDeleteConfirmation(context, ref, address, logger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToEditAddress(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
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
  // See the comment on _deleteAddress above — same fix, same reason: pop via
  // the dialog's own context, not the list row's.
  Future<void> _setAsDefault(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Setting address as default: ${address.id}');

    late BuildContext dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    bool success = false;
    Object? error;
    try {
      final repository = ref.read(addressRepositoryProvider);
      success = await repository.setDefaultAddress(address.id);
    } catch (e) {
      error = e;
      logger.error('Error setting address as default: $e');
    }

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error != null
                ? 'Error setting address as default: $error'
                : success
                    ? 'Address set as default'
                    : 'Failed to set address as default',
          ),
          backgroundColor: (error == null && success) ? Colors.green : Colors.red,
        ),
      );

      if (error == null && success) {
        // addressListProvider is *derived* from addressesProvider
        // (`ref.watch(addressesProvider.future)`), which only re-fetches when
        // addressRefreshProvider changes. Invalidating addressListProvider
        // alone just re-maps the same stale cached list — no real network
        // refetch — so a just-deleted/re-defaulted address kept showing
        // (stale) until something else happened to bump the refresh counter.
        ref.read(addressRefreshProvider.notifier).state++;
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Address address, Logger logger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withOpacity(0.1),
          ),
          child: Icon(Icons.delete_outline, color: AppColors.error, size: 28),
        ),
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
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
              foregroundColor: AppColors.error,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // Delete via the universal backend (DELETE /api/address-crud/delete-address/:id)
  //
  // The loading dialog used to be dismissed with `Navigator.pop(context)`
  // gated on the *list row's* `context.mounted` — but a row's Element can be
  // torn down mid-request (list rebuild, scroll recycling) independently of
  // the dialog, which lives on the app's own Navigator. When that happened,
  // the guard silently skipped the pop and the spinner stayed on screen
  // forever, even after the delete had already succeeded server-side. Popping
  // via the dialog's own captured context fixes that: it only depends on the
  // dialog itself still being up, which is exactly what we're closing.
  Future<void> _deleteAddress(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Deleting address: ${address.id}');

    late BuildContext dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    bool success = false;
    Object? error;
    try {
      final repository = ref.read(addressRepositoryProvider);
      success = await repository.deleteAddress(address.id);
    } catch (e) {
      error = e;
      logger.error('Error deleting address: $e');
    }

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error != null
              ? 'Error deleting address: $error'
              : success
                  ? 'Address deleted successfully'
                  : 'Failed to delete address',
        ),
        backgroundColor: (error == null && success) ? Colors.green : Colors.red,
      ),
    );

    if (error == null && success) {
      // See the comment in _setAsDefault above: bump the refresh counter, not
      // just the derived provider, or the list re-renders the same stale
      // cached data and the just-deleted address keeps showing.
      ref.read(addressRefreshProvider.notifier).state++;
    }
  }
}

/// A small tonal action button — tinted background in [color], icon + label.
/// Replaces the old bare TextButtons, which had no visual boundary and made
/// Edit/Set Default/Delete read as plain floating text rather than actions.
class _AddressActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddressActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


