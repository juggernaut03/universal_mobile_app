// lib/presentation/features/location/location_change_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/utils/location_utils.dart';
import '../../../data/models/outlet_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/home_refresh_provider.dart';
import '../../../di/infrastructure_providers.dart';

class LocationChangeScreen extends ConsumerStatefulWidget {
  const LocationChangeScreen({super.key});

  @override
  ConsumerState<LocationChangeScreen> createState() => _LocationChangeScreenState();
}

class _LocationChangeScreenState extends ConsumerState<LocationChangeScreen> {
  bool _isDisposed = false;
  bool _isNavigating = false;
  
  @override
  void initState() {
    super.initState();
    // Refresh outlet data when screen is loaded to ensure latest store information
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _refreshStoreInformation();
        _checkForStoreUpdateSuccess();
      }
    });
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
  
  void _refreshStoreInformation() {
    try {
      // Refresh the selected outlet provider to get latest store information
      ref.invalidate(selectedOutletProvider);
      
      // Also refresh pincode-related data
      final currentPincode = ref.read(selectedPincodeProvider);
      if (currentPincode != null) {
        ref.invalidate(availableOutletsProvider(currentPincode));
      }
    } catch (e) {
      // Handle error silently as this is not critical
      final logger = ref.read(loggerProvider);
      logger.error('Error refreshing store information: $e');
    }
  }
  
  void _checkForStoreUpdateSuccess() {
    // This method can be used to detect if the user just returned from outlet selection
    // and show appropriate feedback. For now, we'll let the reactive UI handle the updates.
    final launchState = ref.read(launchFlowProvider);
    if (launchState == AppLaunchState.subsequentLaunch) {
      // User is in the app and may have just updated their store selection
      final logger = ref.read(loggerProvider);
      logger.log('Location change screen loaded - checking for store updates');
    }
  }

  void _safeSetState(VoidCallback callback) {
    if (!_isDisposed && mounted) {
      setState(callback);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();
    
    final selectedPincode = ref.watch(selectedPincodeProvider);
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final isScreenSmall = ResponsiveUtils.isSmall(context);
    final logger = ref.read(loggerProvider);

    logger.log('Building LocationChangeScreen - Pincode: $selectedPincode');

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop && !_isNavigating) {
          _safeNavigateToHome();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Set white background

        appBar: AppBar(
          title: const Text('Change Location'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _safeNavigateToHome,
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

  void _safeNavigateToHome() {
    if (_isDisposed || !mounted || _isNavigating) return;

    _safeSetState(() {
      _isNavigating = true;
    });

    // Kick off a full refresh of all home data for the newly selected location
    ref.read(forceRefreshAllHomeDataProvider)().catchError((e) {});

    context.go('/home');
  }

  Widget _buildCurrentLocationCard(
    BuildContext context, 
    String? selectedPincode, 
    AsyncValue<OutletModel?> selectedOutletAsync
  ) {
    return Card(
      elevation: 2,
      color: Colors.white,
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
          onTap: () => _handleAutoLocationDetection(context, ref, logger),
        ),
        const SizedBox(height: 16),
        
        _buildOptionCard(
          context,
          icon: Icons.store,
          title: 'Change Store',
          description: 'Select a different store in your area',
          onTap: () => _handleChangeStore(context, ref, logger),
        ),
        const SizedBox(height: 16),
        
        _buildOptionCard(
          context,
          icon: Icons.list_alt,
          title: 'Browse All Pincodes',
          description: 'View and select from all available pincodes',
          onTap: () => _handleBrowseAllPincodes(context, ref, logger),
        ),
      ],
    );
  }

  Future<void> _handleAutoLocationDetection(
    BuildContext context, 
    WidgetRef ref, 
    dynamic logger
  ) async {
    if (_isDisposed || !mounted) return;
    
    logger.log('Automatic Location Detection tapped');
    
    // Show loading indicator
    _showLoadingDialog(context);
    
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          Navigator.pop(context);
          _showLocationServicesDialog(context);
        }
        return;
      }
      
      // Force refresh the current pincode provider
      ref.refresh(currentPincodeProvider);
      
      final currentPin = await ref.read(currentPincodeProvider.future);
      logger.log('Retrieved pincode from location: $currentPin');
      
      if (context.mounted) {
        Navigator.pop(context);
        
        if (currentPin == null) {
          logger.log('Could not detect location, showing error');
          _showErrorSnackBar(
            context,
            'Could not detect your location. Please try manual selection.',
          );
        } else {
          await _processDetectedPincode(context, ref, logger, currentPin);
        }
      }
    } catch (e) {
      logger.error('Error during location detection: $e');
      if (context.mounted) {
        Navigator.pop(context);
        await _handleLocationError(context, e);
      }
    }
  }

  Future<void> _processDetectedPincode(
    BuildContext context,
    WidgetRef ref,
    dynamic logger,
    String pincode,
  ) async {
    try {
      // Force refresh to get the latest data
      ref.refresh(isPincodeServiceableProvider(pincode));
      
      final isServiceable = await ref.read(
        isPincodeServiceableProvider(pincode).future,
      );
      logger.log('Pincode $pincode serviceable: $isServiceable');
      
      if (isServiceable) {
        logger.log('Pincode is serviceable, saving and checking for outlets');
        await ref.read(selectedPincodeProvider.notifier).selectPincode(pincode);
        
        final outlets = await ref.read(
          availableOutletsProvider(pincode).future
        );
        
        if (!context.mounted) return;
        await _handleOutletSelection(context, ref, logger, outlets);
      } else {
        logger.log('Pincode is not serviceable, showing serviceable pincodes');
        if (context.mounted) {
          _showServiceablePincodesDialog(context, ref);
        }
      }
    } catch (e) {
      logger.error('Error processing detected pincode: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error processing location: ${e.toString()}');
      }
    }
  }

  Future<void> _handleOutletSelection(
    BuildContext context,
    WidgetRef ref,
    dynamic logger,
    List<dynamic> outlets,
  ) async {
    if (_isDisposed || !mounted) return;
    
    if (outlets.isEmpty) {
      _showErrorSnackBar(
        context,
        'No stores available for this location. Please try another location.'
      );
    } else {
      // Always navigate to outlet selection screen regardless of number of outlets
      logger.log('Navigating to outlet selection with ${outlets.length} available outlet(s)');
      
      ref.read(launchFlowProvider.notifier).pincodeSelected();
      
      // Add small delay to ensure provider state is fully updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (context.mounted && !_isNavigating) {
        _safeSetState(() {
          _isNavigating = true;
        });
        context.go('/outlet-selection');
      }
    }
  }

  Future<void> _handleLocationError(BuildContext context, dynamic error) async {
    if (error is LocationPermissionException) {
      if (error.message.contains('disabled')) {
        _showLocationServicesDialog(context);
      } else {
        _showLocationPermissionDialog(context, error);
      }
    } else {
      _showErrorSnackBar(
        context,
        'Error detecting location: ${error.toString()}',
      );
    }
  }

  Future<void> _handleBrowseAllPincodes(
    BuildContext context,
    WidgetRef ref,
    dynamic logger,
  ) async {
    if (_isDisposed || !mounted) return;
    
    logger.log('Browse All Pincodes tapped');
    _showServiceablePincodesDialog(context, ref);
  }

  Future<void> _handleChangeStore(
    BuildContext context,
    WidgetRef ref,
    dynamic logger,
  ) async {
    if (_isDisposed || !mounted) return;
    
    final selectedPincode = ref.read(selectedPincodeProvider);
    logger.log('Change Store tapped, pincode: $selectedPincode');
    
    if (selectedPincode != null) {
      _showLoadingDialog(context);
      
      try {
        final outlets = await ref.read(
          availableOutletsProvider(selectedPincode).future
        );
        
        if (!context.mounted) return;
        Navigator.pop(context);

        if (outlets.isEmpty) {
          _showErrorSnackBar(
            context,
            'No stores available for your pincode. Please try a different pincode.',
          );
        } else {
          // Always show outlet selection screen, even for single outlets
          // This ensures users can see all available store options and details
          logger.log('Found ${outlets.length} outlet(s), navigating to outlet-selection');
          
          // Add small delay to ensure provider state is fully updated
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (context.mounted && !_isNavigating) {
            _safeSetState(() {
              _isNavigating = true;
            });
            context.go('/outlet-selection');
          }
        }
      } catch (e) {
        logger.error('Error checking available outlets: $e');
        if (context.mounted) {
          Navigator.pop(context);
          _showErrorSnackBar(context, 'Error loading stores. Please try again.');
        }
      }
    } else {
      logger.log('No pincode found, showing error');
      _showErrorSnackBar(context, 'Please select a pincode first');
    }
  }

  void _showLoadingDialog(BuildContext context) {
    if (_isDisposed || !mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing...'),
              ],
            ),
          ),
        );
      },
    );
  }



  void _showLocationServicesDialog(BuildContext context) {
    if (!mounted || _isDisposed) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: true,
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
                    Expanded(
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                final opened = await Geolocator.openLocationSettings();
                if (!opened && context.mounted) {
                  _showErrorSnackBar(
                    context,
                    'Please enable location services in your device settings.',
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

  void _showLocationPermissionDialog(BuildContext context, LocationPermissionException error) {
    if (!mounted || _isDisposed) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
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

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
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
    if (!mounted || _isDisposed) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _ServiceablePincodesDialog(
          onPincodeSelected: (pincode) async {
            try {
              // Close dialog first
              Navigator.of(dialogContext).pop();
              
              // Small delay to ensure dialog is properly closed
              await Future.delayed(const Duration(milliseconds: 100));
              
              // Set the selected pincode
              if (context.mounted && !_isDisposed) {
                await ref.read(selectedPincodeProvider.notifier).selectPincode(pincode);

                // Re-check: the guard above ran before this await.
                if (!context.mounted) return;

                // Show feedback that pincode has been selected
                _showSuccessSnackBar(context, 'Pincode $pincode selected. Please choose your store.');
                
                // Add small delay to ensure provider state is fully updated
                await Future.delayed(const Duration(milliseconds: 100));
                
                // Navigate to outlet selection
                if (context.mounted && !_isNavigating) {
                  _safeSetState(() {
                    _isNavigating = true;
                  });
                  context.go('/outlet-selection');
                }
              }
            } catch (e) {
              if (context.mounted && !_isDisposed) {
                _showErrorSnackBar(context, 'Error selecting pincode: $e');
              }
            }
          },
        );
      },
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!mounted || _isDisposed) return;
    
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
  
  void _showSuccessSnackBar(BuildContext context, String message) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Separate dialog widget to handle its own state and disposal
class _ServiceablePincodesDialog extends ConsumerStatefulWidget {
  final Function(String) onPincodeSelected;
  
  const _ServiceablePincodesDialog({
    required this.onPincodeSelected,
  });

  @override
  ConsumerState<_ServiceablePincodesDialog> createState() => _ServiceablePincodesDialogState();
}

class _ServiceablePincodesDialogState extends ConsumerState<_ServiceablePincodesDialog> {
  late TextEditingController _searchController;
  late ValueNotifier<String> _searchQuery;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchQuery = ValueNotifier<String>('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!_isDisposed && mounted) {
      _searchQuery.value = _searchController.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Additional cleanup is handled in dispose()
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
            minHeight: 300,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
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
                    const Text(
                      'Select Pincode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search pincode...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
              
              // Content
              Flexible(
                child: Consumer(
                  builder: (context, ref, _) {
                    final pincodesAsync = ref.watch(allPincodesProvider);
                    
                    return pincodesAsync.when(
                      data: (pincodes) {
                        if (pincodes.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No serviceable pincodes found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        return ValueListenableBuilder<String>(
                          valueListenable: _searchQuery,
                          builder: (context, query, _) {
                            final filteredPincodes = query.isEmpty
                                ? pincodes
                                : pincodes.where((p) => 
                                    p.pincode.toLowerCase().contains(query.toLowerCase())
                                  ).toList();
                            
                            if (filteredPincodes.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No pincodes match "$query"',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filteredPincodes.map((pincode) {
                                  return _buildPincodeChip(pincode.pincode);
                                }).toList(),
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
                      error: (error, stackTrace) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Error loading pincodes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  ref.invalidate(allPincodesProvider);
                                },
                                child: const Text('Retry'),
                              ),
                            ],
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
  }

  Widget _buildPincodeChip(String pincode) {
    return InkWell(
      onTap: () {
        if (!_isDisposed && mounted) {
          widget.onPincodeSelected(pincode);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          pincode,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}