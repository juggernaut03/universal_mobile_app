// lib/presentation/features/location/location_change_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/utils/back_handler.dart';
import '../../../data/models/outlet_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/launch_flow_provider.dart';

class LocationChangeScreen extends ConsumerWidget {
  const LocationChangeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPincode = ref.watch(selectedPincodeProvider);
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final isScreenSmall = ResponsiveUtils.isSmall(context);
    final logger = ref.read(loggerProvider);
    final backHandler = BackButtonHandler(logger: logger);

    logger.log('Building LocationChangeScreen - Pincode: $selectedPincode');

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
        appBar: AppBar(
          title: const Text('Change Location'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Explicitly navigate to home when the app bar back button is pressed
              context.go('/home');
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isScreenSmall ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Current Location',
                    style: AppTextStyles.h4,
                  ),
                  const SizedBox(height: 16),
                  _buildCurrentLocationCard(context, selectedPincode, selectedOutletAsync),
                  const SizedBox(height: 32),
                  Text(
                    'Change Location',
                    style: AppTextStyles.h4,
                  ),
                  const SizedBox(height: 16),
                  _buildChangeLocationOptions(context, ref),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLocationCard(
    BuildContext context, 
    String? selectedPincode, 
    AsyncValue<OutletModel?> selectedOutletAsync
  ) {
    return Card(
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
                Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pincode: ${selectedPincode ?? 'Not set'}',
                  style: AppTextStyles.h6,
                ),
              ],
            ),
            const SizedBox(height: 16),
            selectedOutletAsync.when(
              data: (outlet) {
                if (outlet == null) {
                  return const Text('No store selected');
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.store,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Store: ${outlet.name}',
                            style: AppTextStyles.h6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: Text(
                        outlet.address,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            outlet.openTime,
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.local_offer,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            outlet.offerName,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => Text(
                'Error loading store information',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeLocationOptions(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    
    return Column(
      children: [
        _buildOptionCard(
          context,
          icon: Icons.my_location,
          title: 'Change Delivery Pincode',
          description: 'Detect your location automatically using GPS',
          onTap: () async {
            logger.log('Automatic Location Detection tapped');
            
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );
            
            try {
              // First check if location services are enabled
              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
              if (!serviceEnabled) {
                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);
                  // Show location services dialog
                  _showLocationServicesDialog(context);
                }
                return; // Exit early
              }
              
              // Force refresh the current pincode provider
              ref.refresh(currentPincodeProvider);
              
              final currentPin = await ref.read(currentPincodeProvider.future);
              logger.log('Retrieved pincode from location: $currentPin');
              
              if (context.mounted) {
                Navigator.pop(context); // Dismiss loading indicator
                
                if (currentPin == null) {
                  logger.log('Could not detect location, showing error');
                  _showErrorSnackBar(
                    context,
                    'Could not detect your location. Please try manual selection.',
                  );
                } else {
                  // Force refresh to get the latest data
                  ref.refresh(isPincodeServiceableProvider(currentPin));
                  
                  final isServiceable = await ref.read(
                    isPincodeServiceableProvider(currentPin).future,
                  );
                  logger.log('Pincode $currentPin serviceable: $isServiceable');
                  
                  if (isServiceable) {
                    logger.log('Pincode is serviceable, saving and checking for outlets');
                    // Save the pincode
                    await ref.read(selectedPincodeProvider.notifier).selectPincode(currentPin);
                    
                    // Check if there are multiple outlets
                    final outlets = await ref.read(
                      availableOutletsProvider(currentPin).future
                    );
                    
                    if (outlets.isEmpty) {
                      _showErrorSnackBar(
                        context,
                        'No stores available for this location. Please try another location.'
                      );
                    } else if (outlets.length == 1) {
                      // If only one outlet, select it automatically
                      logger.log('Single outlet found, auto-selecting');
                      await ref.read(selectedOutletProvider.notifier).selectOutlet(outlets[0]);
                      
                      // Update launch flow state
                      ref.read(launchFlowProvider.notifier).outletSelected();
                      
                      // Navigate to home
                      if (context.mounted) {
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Store "${outlets[0].name}" selected automatically'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        
                        // Go to store info
                        context.go('/home');
                      }
                    } else {
                      // Update launch flow state
                      ref.read(launchFlowProvider.notifier).pincodeSelected();
                      
                      // Navigate to outlet selection
                      if (context.mounted) {
                        context.go('/outlet-selection');
                      }
                    }
                  } else {
                    logger.log('Pincode is not serviceable, showing serviceable pincodes');
                    
                    // Show a dialog with all serviceable pincodes for manual selection
                    if (context.mounted) {
                      _showServiceablePincodesDialog(context, ref);
                    }
                  }
                }
              }
            } catch (e) {
              logger.error('Error during location detection: $e');
              if (context.mounted) {
                Navigator.pop(context); // Dismiss loading indicator
                
                if (e is LocationPermissionException) {
                  // Improved location permission handling
                  if (e.message.contains('disabled')) {
                    // Location services are disabled
                    _showLocationServicesDialog(context);
                  } else {
                    // Other permission issues
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(
                              Icons.location_disabled,
                              color: AppColors.warning,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text('Location Permission Required'),
                          ],
                        ),
                        content: Text(e.message),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              // Try to open app settings
                              final opened = await Geolocator.openAppSettings();
                              if (!opened && context.mounted) {
                                _showErrorSnackBar(
                                  context,
                                  'Please enable location permissions in your device settings.',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Open Settings'),
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  // Show generic error
                  _showErrorSnackBar(
                    context,
                    'Error detecting location: ${e.toString()}',
                  );
                }
              }
            }
          },
        ),
        const SizedBox(height: 16),
        
        _buildOptionCard(
          context,
          icon: Icons.store,
          title: 'Change Store',
          description: 'Select a different store in your area',
          onTap: () async {
            // Use ref.read instead of context.read
            final selectedPincode = ref.read(selectedPincodeProvider);
            logger.log('Change Store tapped, pincode: $selectedPincode');
            
            if (selectedPincode != null) {
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                // Check how many outlets are available for this pincode
                final outlets = await ref.read(
                  availableOutletsProvider(selectedPincode).future
                );
                
                // Dismiss loading indicator
                if (context.mounted) {
                  Navigator.pop(context);
                }
                
                if (outlets.isEmpty) {
                  // No outlets available
                  _showErrorSnackBar(
                    context,
                    'No stores available for your pincode. Please try a different pincode.',
                  );
                } else if (outlets.length == 1) {
                  // Only one outlet available, show info message
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text('Single Outlet'),
                        ],
                      ),
                      content: Text(
                        'Your selected pincode ($selectedPincode) has only one store available. '
                        'Please change your pincode to try different stores.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // Show pincode selection dialog to change pincode
                            _showServiceablePincodesDialog(context, ref);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Change Pincode'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Multiple outlets available, navigate to outlet selection
                  logger.log('Navigating to outlet-selection');
                  context.go('/outlet-selection');
                }
              } catch (e) {
                logger.error('Error checking available outlets: $e');
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading indicator if still showing
                  _showErrorSnackBar(
                    context,
                    'Error loading stores. Please try again.',
                  );
                }
              }
            } else {
              logger.log('No pincode found, showing error');
              _showErrorSnackBar(
                context,
                'Please select a pincode first',
              );
            }
          },
        ),
      ],
    );
  }

  void _showLocationServicesDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          // No additional cleanup needed when this dialog is dismissed
        },
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.location_disabled,
                color: AppColors.warning,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Location Disabled'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your location services are turned off. Please enable location services to automatically detect your delivery area.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Turn on Location Services in your device settings to continue.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Open location settings
                final opened = await Geolocator.openLocationSettings();
                if (!opened && context.mounted) {
                  // If we couldn't open settings, show error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enable location services in your device settings.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h6,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.neutral400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServiceablePincodesDialog(BuildContext context, WidgetRef ref) {
    // TextEditingController for search functionality
    final searchController = TextEditingController();
    // State for filtered pincodes
    final ValueNotifier<String> searchQuery = ValueNotifier<String>('');
    
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissal by tapping outside
      builder: (context) {
        return PopScope(
          // Handle hardware back button press
          canPop: true,
          onPopInvoked: (didPop) {
            if (!didPop) {
              // Properly dispose resources before popping
              searchController.dispose();
              searchQuery.dispose();
              Navigator.of(context).pop();
            }
          },
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with title and close button
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Serviceable Pincodes',
                          style: AppTextStyles.h6.copyWith(color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            // Properly dispose resources when manually closed
                            searchController.dispose();
                            searchQuery.dispose();
                            Navigator.pop(context);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by pincode',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        searchQuery.value = value;
                      },
                    ),
                  ),
                  
                  // Pincode grid
                  Flexible(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final pincodesAsync = ref.watch(allPincodesProvider);
                        
                        return pincodesAsync.when(
                          data: (pincodes) {
                            if (pincodes.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No serviceable pincodes found'),
                                ),
                              );
                            }
                            
                            return ValueListenableBuilder<String>(
                              valueListenable: searchQuery,
                              builder: (context, query, _) {
                                // Filter pincodes based on search query
                                final filteredPincodes = query.isEmpty
                                    ? pincodes
                                    : pincodes.where((p) => 
                                        p.pincode.contains(query)).toList();
                                
                                if (filteredPincodes.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'No pincodes match your search',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    ),
                                  );
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 2.4,
                                    ),
                                    itemCount: filteredPincodes.length,
                                    itemBuilder: (context, index) {
                                      final pincode = filteredPincodes[index];
                                      return _buildPincodeCard(context, ref, pincode.pincode);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (_, __) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Error loading pincodes. Please try again.',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // Ensure controllers are disposed when dialog is closed
      // This is a safety net in case the other disposal methods weren't called
      if (searchController.hasListeners) {
        searchController.dispose();
      }
      if (searchQuery.hasListeners) {
        searchQuery.dispose();
      }
    });
  }

  Widget _buildPincodeCard(BuildContext context, WidgetRef ref, String pincode) {
    return InkWell(
      onTap: () async {
        // Get references to providers before closing dialog
        final logger = ref.read(loggerProvider);
        final pincodeNotifier = ref.read(selectedPincodeProvider.notifier);
        final launchFlowNotifier = ref.read(launchFlowProvider.notifier);
        
        // Close dialog
        Navigator.pop(context);
        
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        try {
          await pincodeNotifier.selectPincode(pincode);
          
          // Update the launch flow state
          launchFlowNotifier.pincodeSelected();
          
          // Close loading indicator
          if (context.mounted) {
            Navigator.pop(context);
            
            // Navigate to outlet selection
            context.go('/outlet-selection');
          }
        } catch (e) {
          logger.error('Error selecting pincode: $e');
          if (context.mounted) {
            Navigator.pop(context); // Close loading indicator
            _showErrorSnackBar(context, 'Failed to select pincode. Please try again.');
          }
        }
      },
      child: Container(
        height: 36, // Explicitly set a smaller height
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            pincode,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 15, // Slightly smaller font
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}