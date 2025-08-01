// lib/presentation/features/location/outlet_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/outlet_model.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/launch_flow_provider.dart';

class OutletSelectionScreen extends ConsumerStatefulWidget {
  final String pincode;

  const OutletSelectionScreen({
    Key? key,
    required this.pincode,
  }) : super(key: key);

  @override
  ConsumerState<OutletSelectionScreen> createState() => _OutletSelectionScreenState();
}

class _OutletSelectionScreenState extends ConsumerState<OutletSelectionScreen> {
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkForSingleOutlet();
  }
  
  Future<void> _checkForSingleOutlet() async {
    final logger = ref.read(loggerProvider);
    
    try {
      // Validate pincode is not empty
      if (widget.pincode.isEmpty) {
        logger.error('Empty pincode provided to outlet selection');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      logger.log('Loading outlets for pincode: ${widget.pincode}');
      
      // Get all outlets for the pincode
      final outlets = await ref.read(availableOutletsProvider(widget.pincode).future);
      
      logger.log('Found ${outlets.length} outlets for pincode: ${widget.pincode}');
      
      // Don't auto-select single outlets - always show the selection screen
      // This ensures users can see store details and make an informed choice
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      logger.error('Error checking for outlets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(availableOutletsProvider(widget.pincode));
    final isScreenSmall = ResponsiveUtils.isSmall(context);
    final launchState = ref.watch(launchFlowProvider);
    
    // Check if we're in a state where going back is allowed
    final canGoBack = launchState == AppLaunchState.readyToLaunch || 
                     launchState == AppLaunchState.subsequentLaunch;
                     
    // Determine the appropriate back navigation route
    final backRoute = canGoBack ? '/location-change' : '/pincode-selection';
    
    // If we're still checking for a single outlet, show loading
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white, // Set white background
        appBar: AppBar(
          title: const Text('Checking Stores'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.go(backRoute);
            },
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking available stores...'),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          context.go(backRoute);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Set white background
        appBar: AppBar(
          title: Consumer(
            builder: (context, ref, _) {
              final outletsAsync = ref.watch(availableOutletsProvider(widget.pincode));
              return outletsAsync.when(
                data: (outlets) => Text(
                  outlets.length == 1 ? 'Confirm Store' : 'Select Store',
                ),
                loading: () => const Text('Loading Stores'),
                error: (_, __) => const Text('Select Store'),
              );
            },
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.go(backRoute);
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final outletsAsync = ref.watch(availableOutletsProvider(widget.pincode));
                  
                  return Padding(
                padding: EdgeInsets.all(isScreenSmall ? 16.0 : 24.0),
                    child: outletsAsync.when(
                      data: (outlets) {
                        if (outlets.isEmpty) {
                          return Column(
                            children: [
                              Text(
                                'No Stores Available',
                                style: AppTextStyles.h5.copyWith(
                                  color: AppColors.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unfortunately, we don\'t have any stores serving pincode ${widget.pincode} at the moment.',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        } else if (outlets.length == 1) {
                          return Column(
                            children: [
                              Text(
                                'Store Available in ${widget.pincode}',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please review the store details below and tap to confirm your selection',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Text(
                                '${outlets.length} Stores Available in ${widget.pincode}',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please select your preferred store for delivery',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        }
                      },
                      loading: () => Text(
                        'Loading available stores in ${widget.pincode}...',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      error: (_, __) => Text(
                  'Please select your preferred store for delivery in ${widget.pincode}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                    ),
                  );
                },
              ),
              Expanded(
                child: Container(
                  color: Colors.white, // Ensure container background is white
                  child: outletsAsync.when(
                    data: (outlets) {
                      if (outlets.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      
                      return ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isScreenSmall ? 16.0 : 24.0,
                        ),
                        itemCount: outlets.length,
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          return _buildOutletCard(context, ref, outlet, isSingleOutlet: outlets.length == 1);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stackTrace) => _buildErrorState(context, ref, error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOutletCard(BuildContext context, WidgetRef ref, OutletModel outlet, {bool isSingleOutlet = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = ResponsiveUtils.getResponsiveValue(
      context: context,
      small: screenWidth * 0.9,
      medium: screenWidth * 0.7,
      large: screenWidth * 0.5,
    );

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white, // Set card background to white
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSingleOutlet ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade200, // Highlight border for single outlet
          width: isSingleOutlet ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSingleOutlet ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade200, // Enhanced shadow for single outlet
            blurRadius: isSingleOutlet ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectOutlet(context, ref, outlet),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSingleOutlet)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.store,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Available Store',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        outlet.name,
                        style: AppTextStyles.h5.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        outlet.offerName,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  outlet.address,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    _buildInfoItem(
                      Icons.access_time,
                      'Open: ${outlet.openTime}',
                    ),
                    const SizedBox(width: 16),
                    _buildInfoItem(
                      Icons.delivery_dining,
                      'Delivery: ${outlet.deliveryTime}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoItem(
                  Icons.shopping_bag,
                  'Min. Order: ₹${outlet.minOrderAmount}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      color: Colors.white, // White background for empty state
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.store_mall_directory_outlined,
                size: 72,
                color: AppColors.neutral400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Stores Available',
                style: AppTextStyles.h5,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We couldn\'t find any stores serving this pincode. Please try a different pincode.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.go('/pincode-selection');
                },
                child: const Text('Change Pincode'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Container(
      color: Colors.white, // White background for error state
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 72,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Stores',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ref.refresh(availableOutletsProvider(widget.pincode));
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () {
                      context.go('/pincode-selection');
                    },
                    child: const Text('Change Pincode'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectOutlet(BuildContext context, WidgetRef ref, OutletModel outlet) async {
    // Track if we're already processing the selection
    bool isProcessing = false;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      if (isProcessing) return; // Prevent double-selection
      isProcessing = true;
      
      // Save the selected outlet
      final result = await ref.read(selectedOutletProvider.notifier).selectOutlet(outlet);
      
      // Dismiss loading indicator if context is still mounted
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      if (result) {
        // Update the launch flow state
        ref.read(launchFlowProvider.notifier).outletSelected();
        
        // Determine where to navigate based on user flow
        if (context.mounted) {
          // Check if user came from location change (subsequentLaunch means they were already using the app)
          final launchState = ref.read(launchFlowProvider);
          final isFromLocationChange = launchState == AppLaunchState.readyToLaunch || 
                                      launchState == AppLaunchState.subsequentLaunch;
          
          // Show a success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFromLocationChange 
                  ? '✓ ${outlet.name} confirmed! Returning to location settings...'
                  : '✓ ${outlet.name} confirmed for delivery',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: isFromLocationChange ? 3 : 2),
            ),
          );
          
          // Add a small delay to ensure the UI updates properly
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (isFromLocationChange) {
            // User came from location change screen, return there to show updated info
            // Show a brief delay to allow the success message to be seen
            await Future.delayed(const Duration(milliseconds: 1500));
            if (context.mounted) {
              context.go('/location-change');
            }
          } else {
            // User is in initial setup flow, go to home
            context.go('/home');
          }
        }
      } else {
        // Show error message if unable to save outlet
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to select store. Please try again.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss loading indicator if context is still mounted
      if (context.mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error selecting store: ${e.toString()}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.white,
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      isProcessing = false;
    }
  }
}