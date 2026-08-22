// Checkout step 3 of 4 — delivery slot. Split out of checkout_flow_screen.dart.
// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'package:flutter/material.dart';
import 'package:patelmart/main.dart' show scaffoldMessengerKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/models/delivery_slot_model.dart';
import 'package:patelmart/presentation/providers/delivery_charges_provider.dart';
import 'package:patelmart/presentation/providers/delivery_slot_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../providers/cart_provider.dart';
// FACEBOOK PIXEL IMPORTS
import '../../../../di/infrastructure_providers.dart';
import '../checkout_models.dart';

// Checkout step enum to track progress

class DeliveryTimeStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;
  final VoidCallback onContinue;

  const DeliveryTimeStep({
    super.key,
    required this.checkoutData,
    required this.onContinue,
  });

  @override
  ConsumerState<DeliveryTimeStep> createState() => _DeliveryTimeStepState();
}

class _DeliveryTimeStepState extends ConsumerState<DeliveryTimeStep> {
  DateTime? _selectedDate;
  DeliverySlot? _selectedSlot;
  List<DateTime> _availableDates = [];
  final Map<String, List<DeliverySlot>> _timeSlots = {};
  bool _isLoadingSlots = false;
  bool _isLoadingDates = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.checkoutData.deliveryDate;
    
    // Load data asynchronously
    _loadData();
    
    // Ensure delivery charges are calculated on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only calculate if we have a selected address in checkout data
      if (widget.checkoutData.selectedAddress != null) {
        ref.read(deliveryChargesProvider.notifier).calculateDeliveryCharges(
          userAddress: widget.checkoutData.selectedAddress!,
        );
      }
    });
  }

  Future<void> _loadData() async {
    // Load available dates first
    await _loadAvailableDates();
    
    // Then load delivery slots
    await _loadDeliverySlots();
  }

  Future<void> _loadAvailableDates() async {
    setState(() {
      _isLoadingDates = true;
    });

    try {
      // Fetch delivery dates from API
      final dateStrings = await ref.read(deliveryDatesProvider.future);
      
      // Parse dd/MM/yyyy format to DateTime
      final parsedDates = <DateTime>[];
      for (final dateStr in dateStrings) {
        try {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            parsedDates.add(DateTime(year, month, day));
          }
        } catch (e) {
          ref.read(loggerProvider).error('Error parsing date $dateStr: $e');
        }
      }
      
      if (parsedDates.isNotEmpty) {
        _availableDates = parsedDates;
        ref.read(loggerProvider).log('Loaded ${_availableDates.length} delivery dates from API');
      } else {
        // Fallback to local generation if no dates returned
        _initializeAvailableDates();
        ref.read(loggerProvider).log('Using fallback dates (API returned no dates)');
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error loading delivery dates from API: $e');
      // Fallback to local generation on error
      _initializeAvailableDates();
    }
    
    // If we don't have a selected date yet, select the first available one
    if (_selectedDate == null && _availableDates.isNotEmpty) {
      _selectedDate = _availableDates.first;
      widget.checkoutData.deliveryDate = _selectedDate;
    }
    
    setState(() {
      _isLoadingDates = false;
    });
  }

  void _initializeAvailableDates() {
    // Generate dates for the next 3 days (fallback)
    final now = DateTime.now();
    _availableDates = List.generate(3, (index) {
      return DateTime(now.year, now.month, now.day + index);
    });
  }

  Future<void> _loadDeliverySlots() async {
    setState(() {
      _isLoadingSlots = true;
    });

    try {
      // Determine which slots to load based on delivery method
      final isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
      
      // Get appropriate delivery slots from API
      final slots = isSelfPickup
          ? await ref.read(selfPickupDeliverySlotsProvider.future)
          : await ref.read(deliverySlotsProvider.future);
      
      // Organize slots by date (for now, same slots available for all dates)
      _timeSlots.clear();
      for (final date in _availableDates) {
        final key = _formatDateKey(date);
        _timeSlots[key] = List.from(slots);
      }
      
      // If we don't have a selected slot yet, select the first available one
      if (_selectedSlot == null && slots.isNotEmpty) {
        final dateSlotsKey = _formatDateKey(_selectedDate!);
        if (_timeSlots.containsKey(dateSlotsKey) && _timeSlots[dateSlotsKey]!.isNotEmpty) {
          _selectedSlot = _timeSlots[dateSlotsKey]!.first;
          widget.checkoutData.deliveryTimeSlot = _selectedSlot!.displayText;
          widget.checkoutData.deliverySlotId = _selectedSlot!.id;
        }
      } else if (widget.checkoutData.deliveryTimeSlot != null) {
        // Try to find the previously selected slot
        final previousSlotText = widget.checkoutData.deliveryTimeSlot!;
        for (final slot in slots) {
          if (slot.displayText == previousSlotText) {
            _selectedSlot = slot;
            widget.checkoutData.deliverySlotId = slot.id;
            break;
          }
        }
      }
      
      final slotType = isSelfPickup ? 'self-pickup' : 'delivery';
      ref.read(loggerProvider).log('Loaded ${slots.length} $slotType slots from API');
    } catch (e) {
      ref.read(loggerProvider).error('Error loading delivery slots: $e');
      // Show error to user
      {
        // App-level messenger: this runs after awaiting the slots call, and a
        // `mounted` check does not cover the deactivated window that makes a
        // route-scoped messenger throw. See scaffoldMessengerKey in main.dart.
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to load delivery slots. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadDeliverySlots,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}_${date.month}_${date.day}';
  }

  String _formatDateDisplay(DateTime date) {
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    
    if (date.year == now.year && date.month == now.month && date.day == now.day + 1) {
      return 'Tomorrow';
    }
    
    // May 01, 2025 format
    return '${_getMonthName(date.month)} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      
      // Reset time slot if the date changes
      final key = _formatDateKey(date);
      if (_timeSlots.containsKey(key) && _timeSlots[key]!.isNotEmpty) {
        _selectedSlot = _timeSlots[key]!.first;
      } else {
        _selectedSlot = null;
      }
    });
    
    // Update checkout data
    widget.checkoutData.deliveryDate = date;
    widget.checkoutData.deliveryTimeSlot = _selectedSlot?.displayText;
    widget.checkoutData.deliverySlotId = _selectedSlot?.id;
  }

  void _selectTimeSlot(DeliverySlot slot) {
    setState(() {
      _selectedSlot = slot;
    });
    widget.checkoutData.deliveryTimeSlot = slot.displayText;
    widget.checkoutData.deliverySlotId = slot.id;
  }

  @override
  Widget build(BuildContext context) {
    final isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isSelfPickup ? 'Choose Pickup Time' : 'Choose Delivery Time',
            style: AppTextStyles.h5,
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            isSelfPickup ? 'Select pickup time slot' : 'Select delivery time slot',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Date tabs
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _isLoadingDates
            ? ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: index < 2 ? 12.0 : 0),
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  );
                },
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableDates.length,
                itemBuilder: (context, index) {
                  final date = _availableDates[index];
                  final isSelected = _selectedDate?.day == date.day && 
                                    _selectedDate?.month == date.month &&
                                    _selectedDate?.year == date.year;
                  
                  return Padding(
                    padding: EdgeInsets.only(right: index < _availableDates.length - 1 ? 12.0 : 0),
                    child: InkWell(
                      onTap: () => _selectDate(date),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            _formatDateDisplay(date),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
        
        const SizedBox(height: 24),
        
        // Time slots
        Expanded(
          child: _buildTimeSlots(),
        ),
        
        // Order Total Section
        _buildOrderTotal(),
        
        // Continue Button
        Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: MediaQuery.of(context).padding.bottom + 16.0,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: Consumer(
              builder: (context, ref, child) {
                final deliveryChargesState = ref.watch(deliveryChargesProvider);
                final isCalculating = deliveryChargesState.isLoading;
                // Blocks Continue when the address can't actually be
                // delivered to — this used to only check isCalculating, so
                // an out-of-range address (isLoading false, error set) let
                // checkout proceed anyway.
                final deliveryUnavailable = deliveryChargesState.error != null;

                return ElevatedButton(
                  onPressed: (_selectedSlot == null || isCalculating || deliveryUnavailable || _isLoadingSlots || _isLoadingDates)
                    ? null
                    : widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: (isCalculating || _isLoadingSlots || _isLoadingDates)
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('CONTINUE'),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlots() {
    if (_selectedDate == null) {
      return const Center(
        child: Text('Please select a date first'),
      );
    }
    
    if (_isLoadingSlots) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading delivery slots...'),
          ],
        ),
      );
    }
    
    final key = _formatDateKey(_selectedDate!);
    final slots = _timeSlots[key] ?? [];
    
    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No time slots available',
              style: AppTextStyles.h6,
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a different date or try again later',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDeliverySlots,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Show date heading
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateDisplay(_selectedDate!),
                style: AppTextStyles.h6,
              ),
              if (_isLoadingSlots)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Time slot grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.isSmall(context) ? 2 : 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final isSelected = _selectedSlot?.id == slot.id;
              
              return InkWell(
                onTap: () => _selectTimeSlot(slot),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot.displayText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Available',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.green[700],
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTotal() {
    return Consumer(
      builder: (context, ref, _) {
        final cartTotal = ref.watch(cartTotalProvider);
        final cartSavings = ref.watch(cartSavingsProvider);
        
        // Get delivery charges from provider
        final deliveryChargesState = ref.watch(deliveryChargesProvider);
        final deliveryCharge = deliveryChargesState.deliveryCharge;
        final isLoading = deliveryChargesState.isLoading;
        final isFreeDelivery = deliveryChargesState.freeDeliveryEligible;
        final distance = deliveryChargesState.distance;
        // Handling/packaging are store-configured flat fees (admin panel)
        // that are NOT waived by free delivery — only the distance-based
        // component is, so they're broken out as their own line items
        // rather than folded into "Delivery Fee" where free delivery would
        // otherwise misleadingly read as "FREE" while still being charged.
        final distanceCharge = deliveryChargesState.distanceCharge;
        final handlingFee = deliveryChargesState.handlingFee;
        final packageFee = deliveryChargesState.packageFee;
        
        // Calculate final total with delivery charges
        final finalTotal = cartTotal + deliveryCharge;
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Cart subtotal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Subtotal',
                    style: AppTextStyles.bodyMedium,
                  ),
                  Text(
                    '₹${cartTotal.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              
              // Distance information
              if (distance > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Distance:',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ],
              
              // Delivery fee
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Delivery Fee:',
                        style: AppTextStyles.bodyMedium,
                      ),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    isLoading
                      ? 'Calculating...'
                      // Only the distance-based charge is waived by free
                      // delivery — handling/packaging fees below are not.
                      : (isFreeDelivery && distanceCharge <= 0)
                        ? 'FREE'
                        : '₹${distanceCharge.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: (isFreeDelivery && distanceCharge <= 0) ? Colors.green : null,
                      fontWeight: (isFreeDelivery && distanceCharge <= 0) ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),

              // Handling fee — store-configured flat charge (admin panel),
              // shown only when the store actually has one set.
              if (!isLoading && handlingFee > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.build_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Handling Fee:',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                    Text(
                      '₹${handlingFee.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ],

              // Packaging fee — same idea, shown only when set.
              if (!isLoading && packageFee > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Packaging Fee:',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                    Text(
                      '₹${packageFee.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ],

              // Delivery error — see the matching comment in
              // delivery_address_step.dart.
              if (deliveryChargesState.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deliveryChargesState.error!,
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Savings
              if (cartSavings > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.savings,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'You Save:',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                    Text(
                      '₹${cartSavings.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
              
              const Divider(height: 24),
              
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${finalTotal.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              
              // Free delivery message for eligible orders
              if (isFreeDelivery && distance > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Free delivery for this order',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
// STEP 4: Payment Step
// Updated PaymentStep implementation for the CheckoutFlowScreen

// STEP 4: Updated Payment Step with API Integration
// Replace the existing PaymentStep class in your checkout_flow_screen.dart with this updated version

