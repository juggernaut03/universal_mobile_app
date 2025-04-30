// lib/presentation/features/location/pincode_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/location_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../data/services/location_service.dart';
import '../../../data/models/pincode_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/outlet_provider.dart';

class PincodeSelectionScreen extends ConsumerStatefulWidget {
  const PincodeSelectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PincodeSelectionScreen> createState() => _PincodeSelectionScreenState();
}

class _PincodeSelectionScreenState extends ConsumerState<PincodeSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLocationDetectionAttempted = false;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _hasShownLocationModal = false;
  String? _nonServiceablePincode;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Schedule location checks for the next frame to avoid build issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tryAutoLocationDetection();
        _checkLocationServiceability();
      }
    });
  }
  
  // Check if we need to show location serviceability modals
  Future<void> _checkLocationServiceability() async {
    final logger = ref.read(loggerProvider);
    
    // Only check if we haven't shown a modal yet
    if (_hasShownLocationModal) {
      return;
    }
    
    _hasShownLocationModal = true;
    
    // Get location info without watching the provider (to avoid rebuild cycles)
    final locationInfo = ref.read(locationInfoProvider);
    
    if (locationInfo.nonServiceablePincode != null) {
      setState(() {
        _nonServiceablePincode = locationInfo.nonServiceablePincode;
      });
      
      // Show modal in next frame to avoid rebuild issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNonServiceableAreaModal(context);
        }
      });
    } else if (locationInfo.locationError != null) {
      // Handle location errors in next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleLocationError(locationInfo.locationError!);
        }
      });
    }
  }
  
  void _handleLocationError(String errorType) {
    final logger = ref.read(loggerProvider);
    logger.log('Handling location error: $errorType');
    
    if (errorType == 'location_disabled') {
      _showLocationServicesDialog(context);
    } else if (errorType == 'permission_denied') {
      _showLocationPermissionDialog(context);
    } else if (errorType == 'network_error') {
      _showNetworkErrorDialog(context);
    }
  }

  Future<void> _tryAutoLocationDetection() async {
    final logger = ref.read(loggerProvider);
    final launchState = ref.read(launchFlowProvider);
    
    logger.log('Trying auto location detection. Launch state: $launchState');
    
    if (launchState == AppLaunchState.needLocationPermission && !_isLocationDetectionAttempted) {
      logger.log('Auto-triggering location detection');
      
      setState(() {
        _isLocationDetectionAttempted = true;
        _isLoading = true;
      });
      
      try {
        // Let the system try to fetch the location
        await ref.read(launchFlowProvider.notifier).fetchLocationAndCheckPincode();
      } catch (e) {
        logger.error('Error in auto location detection: $e');
        
        if (mounted) {
          if (e is LocationPermissionException) {
            await LocationService.handleLocationError(
              context, 
              e,
              onCancel: () {
                // Just continue with manual selection
              }
            );
          } else {
            // Show a toast for other errors
            showErrorToast(
              context, 
              'Could not detect location automatically. Please select manually.'
            );
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  // Filter pincodes locally based on search query
  List<PincodeModel> _filterPincodes(List<PincodeModel> pincodes, String query) {
    if (query.isEmpty) {
      return pincodes;
    }
    
    final lowerCaseQuery = query.toLowerCase();
    return pincodes.where((pincode) => 
      pincode.pincode.toLowerCase().contains(lowerCaseQuery)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allPincodesAsync = ref.watch(allPincodesProvider);
    final launchState = ref.watch(launchFlowProvider);
    final logger = ref.read(loggerProvider);
    
    logger.log('Building PincodeSelectionScreen - LaunchState: $launchState');

    // Check if we can go back
    final canGoBack = launchState == AppLaunchState.readyToLaunch || 
                      launchState == AppLaunchState.subsequentLaunch;
                      
    // Determine back navigation route
    final backRoute = canGoBack ? '/location-change' : null;

    // Show loading screen during location detection
    if (_isLoading) {
      return BackButtonWrapper(
        alternateRoute: backRoute,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Detecting Location'),
            leading: canGoBack ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/location-change'),
            ) : null,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Detecting your location...',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = false;
                    });
                  },
                  child: const Text('Select manually instead'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BackButtonWrapper(
      alternateRoute: backRoute,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Serviceable Pincodes'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (canGoBack) {
                context.go('/location-change');
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
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
              ),
            ),
            
            // Pincode grid
            Expanded(
              child: allPincodesAsync.when(
                data: (allPincodes) {
                  if (allPincodes.isEmpty) {
                    return Center(
                      child: Text(
                        'No serviceable pincodes found',
                        style: AppTextStyles.bodyLarge,
                      ),
                    );
                  }
                  
                  // Filter pincodes locally based on search query
                  final filteredPincodes = _filterPincodes(allPincodes, _searchQuery);
                  
                  if (filteredPincodes.isEmpty && _searchQuery.isNotEmpty) {
                    // Show "no results" message when search has no matches
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No matching pincodes found',
                            style: AppTextStyles.h5,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different Pincode',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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
                        return _buildPincodeCard(pincode.pincode);
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
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
                        'Error loading pincodes',
                        style: AppTextStyles.h5.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => ref.refresh(allPincodesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPincodeCard(String pincode) {
    return InkWell(
      onTap: () => _selectPincode(pincode),
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

  Future<void> _selectPincode(String pincode) async {
    final logger = ref.read(loggerProvider);
    logger.log('Selecting pincode: $pincode');
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if the pincode is serviceable
      final isServiceable = await ref.read(isPincodeServiceableProvider(pincode).future);
      
      if (isServiceable) {
        logger.log('Pincode is serviceable, saving and proceeding to outlet selection');
        
        // Save the selected pincode
        await ref.read(selectedPincodeProvider.notifier).selectPincode(pincode);
        
        // Update the launch flow state
        ref.read(launchFlowProvider.notifier).pincodeSelected();
        
        // Navigate to outlet selection screen
        if (mounted) {
          context.go('/outlet-selection');
        }
      } else {
        logger.log('Pincode is not serviceable, showing error');
        // Show error message if pincode is not serviceable
        if (mounted) {
          _showErrorSnackBar('Sorry! We currently do not serve in this area: $pincode');
        }
      }
    } catch (e) {
      logger.error('Error selecting pincode: $e');
      
      // Show error message
      if (mounted) {
        String message = 'Error checking pincode';
        ErrorType errorType = ErrorType.generic;
        
        if (e is ApiException) {
          message = e.message;
          errorType = e.type;
        } else {
          message = e.toString();
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: AppErrorWidget(
              errorType: errorType,
              message: message,
              onRetry: () {
                Navigator.pop(context);
                _selectPincode(pincode);
              },
              onCancel: () => Navigator.pop(context),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _detectCurrentLocation() async {
    final logger = ref.read(loggerProvider);
    logger.log('Manual location detection triggered');
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh the current location provider to force a new location fetch
      ref.refresh(currentPincodeProvider);
      
      // Get the pincode from current location
      final pincode = await ref.read(currentPincodeProvider.future);
      
      if (pincode == null) {
        logger.log('Could not detect location, showing error');
        _showErrorSnackBar('Could not detect your location. Please select a pincode manually.');
        return;
      }
      
      // Check if the pincode is serviceable
      final isServiceable = await ref.read(isPincodeServiceableProvider(pincode).future);
      logger.log('Pincode $pincode serviceable: $isServiceable');
      
      if (isServiceable) {
        // Save the pincode
        await ref.read(selectedPincodeProvider.notifier).selectPincode(pincode);
        
        // Check if there are multiple outlets
        final outlets = await ref.read(availableOutletsProvider(pincode).future);
        
        if (outlets.isEmpty) {
          _showErrorSnackBar('No stores available in your area. Please select another pincode.');
        } else if (outlets.length == 1) {
          // If only one outlet, select it automatically
          logger.log('Single outlet found, auto-selecting');
          await ref.read(selectedOutletProvider.notifier).selectOutlet(outlets[0]);
          
          // Update launch flow state
          ref.read(launchFlowProvider.notifier).outletSelected();
          
          // Navigate to store info
          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Store "${outlets[0].name}" selected automatically'),
                backgroundColor: AppColors.success,
              ),
            );
            
            // Go to store info
            context.go('/store-info');
          }
        } else {
          // Update launch flow state
          ref.read(launchFlowProvider.notifier).pincodeSelected();
          
          // Navigate to outlet selection
          if (mounted) {
            context.go('/outlet-selection');
          }
        }
      } else {
        _showErrorSnackBar('Sorry! We currently do not serve in your area: $pincode');
      }
    } catch (e) {
      logger.error('Error detecting location: $e');
      
      if (mounted) {
        if (e is LocationPermissionException) {
          await LocationService.handleLocationError(
            context, 
            e,
            onCancel: () {
              // Just continue with manual selection
            }
          );
        } else {
          _showErrorSnackBar('Error detecting location: ${e.toString()}');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
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
  
  void _showNonServiceableAreaModal(BuildContext context) {
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
                Icons.location_off,
                color: AppColors.warning,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('We Are Expanding!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We currently do not deliver to your detected location (Pincode: $_nonServiceablePincode).',
                style: AppTextStyles.bodyMedium,
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
                        'Please choose from our list of serviceable pincodes.',
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
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Choose Pincode'),
            ),
          ],
        ),
      ),
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
                'We need access to your location to check if we deliver to your area.',
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
                        'Please enable location services in your device settings.',
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
              child: const Text('Choose Manually'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Open location settings
                final opened = await Geolocator.openLocationSettings();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
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
  
  void _showLocationPermissionDialog(BuildContext context) {
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
                'We need permission to access your location to check if we deliver to your area.',
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
                        'Please grant location permission in app settings.',
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
              child: const Text('Choose Manually'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Open app settings
                final opened = await Geolocator.openAppSettings();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Please grant location permission in app settings.',
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
  
  void _showNetworkErrorDialog(BuildContext context) {
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
                Icons.signal_wifi_off,
                color: AppColors.warning,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Network Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to check your location due to a network error.',
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
                        'Please check your internet connection and try again.',
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
              child: const Text('Choose Manually'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Retry location fetch
                ref.read(launchFlowProvider.notifier).fetchLocationAndCheckPincode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Try Again'),
            ),
          ],
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
                  
                  // Pincode grid - simplified to avoid nested providers
                  Flexible(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final pincodesAsync = ref.watch(allPincodesProvider);
                        
                        // Handle loading state
                        if (pincodesAsync.isLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        // Handle error state
                        if (pincodesAsync.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Error loading pincodes. Please try again.',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          );
                        }
                        
                        // Get data
                        final pincodes = pincodesAsync.value ?? [];
                        
                        if (pincodes.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No serviceable pincodes found'),
                            ),
                          );
                        }
                        
                        // Use ValueListenableBuilder for search filtering
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
                                // Use a different builder method to avoid state issues
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 2.4,
                                ),
                                itemCount: filteredPincodes.length,
                                itemBuilder: (context, index) {
                                  final pincode = filteredPincodes[index];
                                  return _buildServiceablePincodeCard(context, ref, pincode.pincode);
                                },
                              ),
                            );
                          },
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

  Widget _buildServiceablePincodeCard(BuildContext context, WidgetRef ref, String pincode) {
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
            _showErrorSnackBar( 'Failed to select pincode. Please try again.');
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
}