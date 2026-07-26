// lib/presentation/features/location/pincode_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/location_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../presentation/widgets/back_button_wrapper.dart';
import '../../../data/services/location_service.dart';
import '../../../data/models/pincode_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../../domain/entities/delivery_location.dart';
import '../../../di/infrastructure_providers.dart';

class PincodeSelectionScreen extends ConsumerStatefulWidget {
  const PincodeSelectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PincodeSelectionScreen> createState() => _PincodeSelectionScreenState();
}

class _PincodeSelectionScreenState extends ConsumerState<PincodeSelectionScreen> {
  late TextEditingController _searchController;
  bool _isLocationDetectionAttempted = false;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _hasShownLocationModal = false;
  String? _nonServiceablePincode;
  bool _isDisposed = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    
    // Schedule location checks for the next frame to avoid build issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _tryAutoLocationDetection();
        _checkLocationServiceability();
      }
    });
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback callback) {
    if (!_isDisposed && mounted) {
      setState(callback);
    }
  }

  // Check if we need to show location serviceability modals
  Future<void> _checkLocationServiceability() async {
    if (_isDisposed || !mounted) return;
    
    final logger = ref.read(loggerProvider);
    
    // Only check if we haven't shown a modal yet
    if (_hasShownLocationModal) {
      return;
    }
    
    _hasShownLocationModal = true;
    
    // Get location info without watching the provider (to avoid rebuild cycles)
    final locationInfo = ref.read(locationInfoProvider);
    
    if (locationInfo.nonServiceablePincode != null) {
      _safeSetState(() {
        _nonServiceablePincode = locationInfo.nonServiceablePincode;
      });
      
      // Show modal in next frame to avoid rebuild issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _showNonServiceableAreaModal(context);
        }
      });
    } else if (locationInfo.issue != null) {
      // Handle location errors in next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _handleLocationError(locationInfo.issue!);
        }
      });
    }
  }
  
  /// Routes a detection failure to the right recovery affordance.
  ///
  /// Was an if/else chain comparing magic strings, and it handled only three of
  /// the five codes the launch flow could emit — 'pincode_not_found' and
  /// 'no_outlets' fell through silently, leaving the user on the picker with no
  /// explanation. Switching over the enum with no `default:` means the compiler
  /// now rejects any unhandled case.
  void _handleLocationError(LocationIssue issue) {
    if (_isDisposed || !mounted) return;

    ref.read(loggerProvider).log('Handling location issue: $issue');

    switch (issue) {
      case LocationIssue.locationServicesDisabled:
        _showLocationServicesDialog(context);
      case LocationIssue.permissionDenied:
      case LocationIssue.permissionPermanentlyDenied:
        _showLocationPermissionDialog(context);
      case LocationIssue.networkError:
        _showNetworkErrorDialog(context);
      case LocationIssue.pincodeNotDetected:
      case LocationIssue.noOutletsForPincode:
        // Previously unhandled. No dialog is right here — the user is already
        // on the manual picker — but they need to be told why.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(issue.userMessage)),
        );
    }
  }

  Future<void> _tryAutoLocationDetection() async {
    if (_isDisposed || !mounted) return;
    
    final logger = ref.read(loggerProvider);
    final launchState = ref.read(launchFlowProvider);
    
    logger.log('Trying auto location detection. Launch state: $launchState');
    
    if (launchState == AppLaunchState.needLocationPermission && !_isLocationDetectionAttempted) {
      logger.log('Auto-triggering location detection');
      
      _safeSetState(() {
        _isLocationDetectionAttempted = true;
        _isLoading = true;
      });
      
      try {
        // Let the system try to fetch the location
        await ref.read(launchFlowProvider.notifier).fetchLocationAndCheckPincode();
      } catch (e) {
        logger.error('Error in auto location detection: $e');
        
        if (mounted && !_isDisposed) {
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
        _safeSetState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_isDisposed || !mounted) return;
    
    _safeSetState(() {
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
    if (_isDisposed) return const SizedBox.shrink();
    
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
              onPressed: () => _safeNavigateToLocationChange(),
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
                    _safeSetState(() {
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
                _safeNavigateToLocationChange();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
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
              
              // Pincode grid - wrapped in Expanded and safe area
              Expanded(
                child: allPincodesAsync.when(
                  data: (allPincodes) {
                    if (allPincodes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No serviceable pincodes found',
                              style: AppTextStyles.h5,
                            ),
                          ],
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
                    
                    // Use SingleChildScrollView with proper constraints
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: filteredPincodes.map((pincode) {
                            return _buildPincodeCard(pincode.pincode);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPincodeCard(String pincode) {
    return InkWell(
      onTap: () => _selectPincode(pincode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: (MediaQuery.of(context).size.width - 52) / 3, // Calculate width for 3 columns
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            pincode,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _safeNavigateToLocationChange() {
    if (_isDisposed || !mounted || _isNavigating) return;
    
    _safeSetState(() {
      _isNavigating = true;
    });
    
    context.go('/location-change');
  }

  Future<void> _selectPincode(String pincode) async {
    if (_isDisposed || !mounted || _isNavigating) return;
    
    final logger = ref.read(loggerProvider);
    logger.log('Selecting pincode: $pincode');
    
    _safeSetState(() {
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
        
        // Add small delay to ensure provider state is fully updated
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Navigate to outlet selection screen
        if (mounted && !_isDisposed && !_isNavigating) {
          _safeSetState(() {
            _isNavigating = true;
          });
          context.go('/outlet-selection');
        }
      } else {
        logger.log('Pincode is not serviceable, showing error');
        // Show error message if pincode is not serviceable
        if (mounted && !_isDisposed) {
          _showErrorSnackBar('Sorry! We currently do not serve in this area: $pincode');
        }
      }
    } catch (e) {
      logger.error('Error selecting pincode: $e');
      
      // Show error message
      if (mounted && !_isDisposed) {
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
          builder: (dialogContext) => AlertDialog(
            content: AppErrorWidget(
              errorType: errorType,
              message: message,
              onRetry: () {
                Navigator.pop(dialogContext);
                _selectPincode(pincode);
              },
              onCancel: () => Navigator.pop(dialogContext),
            ),
          ),
        );
      }
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _detectCurrentLocation() async {
    if (_isDisposed || !mounted) return;
    
    final logger = ref.read(loggerProvider);
    logger.log('Manual location detection triggered');
    
    _safeSetState(() {
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
        
        // Check if there are outlets available
        final outlets = await ref.read(availableOutletsProvider(pincode).future);
        
        if (outlets.isEmpty) {
          _showErrorSnackBar('No stores available in your area. Please select another pincode.');
        } else {
          // Always show outlet selection screen, even for single outlets
          // This ensures users can see the store details and make an informed choice
          logger.log('Found ${outlets.length} outlet(s), navigating to outlet selection');
          
          // Update launch flow state
          ref.read(launchFlowProvider.notifier).pincodeSelected();
          
          // Add small delay to ensure provider state is fully updated
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Navigate to outlet selection
          if (mounted && !_isDisposed && !_isNavigating) {
            _safeSetState(() {
              _isNavigating = true;
            });
            context.go('/outlet-selection');
          }
        }
      } else {
        _showErrorSnackBar('Sorry! We currently do not serve in your area: $pincode');
      }
    } catch (e) {
      logger.error('Error detecting location: $e');
      
      if (mounted && !_isDisposed) {
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
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
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
  
  void _showNonServiceableAreaModal(BuildContext context) {
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
                    Expanded(
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
                Navigator.pop(dialogContext);
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
                    Expanded(
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Choose Manually'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                // Open location settings
                final opened = await Geolocator.openLocationSettings();
                if (!opened && mounted && !_isDisposed) {
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
              const Text('Location Permission Required'),
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
                    Expanded(
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Choose Manually'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                // Open app settings
                final opened = await Geolocator.openAppSettings();
                if (!opened && mounted && !_isDisposed) {
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
                    Expanded(
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Choose Manually'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
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
}