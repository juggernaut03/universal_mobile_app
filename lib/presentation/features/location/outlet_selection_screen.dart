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
      // Get all outlets for the pincode
      final outlets = await ref.read(availableOutletsProvider(widget.pincode).future);
      
      if (outlets.length == 1) {
        logger.log('Single outlet found for pincode ${widget.pincode}, auto-selecting');
        
        // Auto-select the outlet
        await ref.read(selectedOutletProvider.notifier).selectOutlet(outlets[0]);
        
        // Update launch flow state
        ref.read(launchFlowProvider.notifier).outletSelected();
        
        // Navigate to store info
        if (mounted) {
          // Show a snackbar to inform the user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Store "${outlets[0].name}" selected automatically'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Add a small delay to show the snackbar
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              context.go('/store-info');
            }
          });
        }
      } else {
        // More than one outlet, let the user choose
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.error('Error checking for single outlet: $e');
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
        appBar: AppBar(
          title: const Text('Select Store'),
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
              Padding(
                padding: EdgeInsets.all(isScreenSmall ? 16.0 : 24.0),
                child: Text(
                  'Please select your preferred store for delivery in ${widget.pincode}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
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
                        return _buildOutletCard(context, ref, outlet);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => _buildErrorState(context, ref, error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Other methods remain the same as the original
  // ...
  
  Widget _buildOutletCard(BuildContext context, WidgetRef ref, OutletModel outlet) {
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.1),
            blurRadius: 8,
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
    return Center(
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
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
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
    );
  }

  void _selectOutlet(BuildContext context, WidgetRef ref, OutletModel outlet) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Save the selected outlet - Fixed to use ref.read instead of context.read
      final result = await ref.read(selectedOutletProvider.notifier).selectOutlet(outlet);
      
      // Dismiss loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      if (result) {
        // Update the launch flow state - Fixed to use ref.read
        ref.read(launchFlowProvider.notifier).outletSelected();
        
        // Navigate to store info screen
        if (context.mounted) {
  context.go('/home');
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
      // Dismiss loading indicator
      if (context.mounted) {
        Navigator.pop(context);
        
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
    }
  }
}