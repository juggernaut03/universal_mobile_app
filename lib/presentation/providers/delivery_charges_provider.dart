// lib/presentation/providers/delivery_charges_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../data/models/address_model.dart';
import '../../data/models/outlet_model.dart';
import '../../data/services/delivery_charges_service.dart';
import 'cart_provider.dart';
import 'launch_flow_provider.dart';
import 'outlet_provider.dart';

// Provider for the DeliveryChargesService
final deliveryChargesServiceProvider = Provider<DeliveryChargesService>((ref) {
  final logger = ref.watch(loggerProvider);
  return DeliveryChargesService(
    client: http.Client(),
    logger: logger,
  );
});

// State for storing delivery charges
class DeliveryChargesState {
  final bool isLoading;
  final double deliveryCharge;
  final String? error;
  final bool freeDeliveryEligible;
  final double distance;

  DeliveryChargesState({
    required this.isLoading,
    required this.deliveryCharge,
    this.error,
    required this.freeDeliveryEligible,
    required this.distance,
  });

  DeliveryChargesState copyWith({
    bool? isLoading,
    double? deliveryCharge,
    String? error,
    bool? freeDeliveryEligible,
    double? distance,
  }) {
    return DeliveryChargesState(
      isLoading: isLoading ?? this.isLoading,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      error: error ?? this.error,
      freeDeliveryEligible: freeDeliveryEligible ?? this.freeDeliveryEligible,
      distance: distance ?? this.distance,
    );
  }
}

// Notifier for managing delivery charges state
class DeliveryChargesNotifier extends StateNotifier<DeliveryChargesState> {
  final DeliveryChargesService _deliveryChargesService;
  final Ref _ref;

  DeliveryChargesNotifier(this._deliveryChargesService, this._ref)
      : super(DeliveryChargesState(
          isLoading: false,
          deliveryCharge: 0.0,
          freeDeliveryEligible: false,
          distance: 0.0,
        ));

  // Calculate delivery charges based on user address and order amount
  Future<void> calculateDeliveryCharges({
    required Address userAddress,
    double? orderAmount,
  }) async {
    // Get the logger instance
    final logger = _ref.read(loggerProvider);
    
    // Set loading state
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Get the selected outlet
      final selectedOutletAsync = _ref.read(selectedOutletProvider);
      
      final selectedOutlet = selectedOutletAsync.valueOrNull;
      if (selectedOutlet == null) {
        throw Exception('No outlet selected');
      }
      
      // If order amount is not provided, get it from the cart
      final double calculatedOrderAmount = orderAmount ?? _ref.read(cartTotalProvider);

      // The universal backend computes road distance server-side from the
      // address coordinates — resolve them (stored lat/lng, else geocode).
      final coords =
          await _deliveryChargesService.resolveAddressCoordinates(userAddress);
      if (coords == null) {
        throw Exception(
            'Could not locate this address on the map. Please edit the address and set its location.');
      }

      final quote = await _deliveryChargesService.getDeliveryChargesForCoordinates(
        addressLatitude: coords.latitude,
        addressLongitude: coords.longitude,
        storeCode: selectedOutlet.storeCode,
        orderAmount: calculatedOrderAmount,
      );

      if (!quote.available) {
        throw Exception(quote.reason.isNotEmpty
            ? quote.reason
            : 'Delivery is not available to this address.');
      }

      // Update state with the calculated values
      state = state.copyWith(
        isLoading: false,
        deliveryCharge: quote.charge,
        freeDeliveryEligible: quote.freeDelivery || quote.charge <= 0,
        distance: quote.distanceKm,
      );

      logger.log(
          'Delivery charges updated - Distance: ${quote.distanceKm}km, Charge: ₹${quote.charge}, Free: ${quote.freeDelivery}');
    } catch (e) {
      logger.error('Error calculating delivery charges: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to calculate delivery charges: $e',
      );
    }
  }

  // Kept for call-site compatibility — the server computes distance now, so
  // rounding no longer applies.
  Future<void> calculateDeliveryChargesWithRounding({
    required Address userAddress,
    double? orderAmount,
    bool roundDistance = false,
  }) async {
    await calculateDeliveryCharges(
        userAddress: userAddress, orderAmount: orderAmount);
  }

  // Reset delivery charges state
  void reset() {
    state = DeliveryChargesState(
      isLoading: false,
      deliveryCharge: 0.0,
      freeDeliveryEligible: false,
      distance: 0.0,
    );
  }
}

// Provider for delivery charges state
final deliveryChargesProvider = StateNotifierProvider<DeliveryChargesNotifier, DeliveryChargesState>((ref) {
  final deliveryChargesService = ref.watch(deliveryChargesServiceProvider);
  return DeliveryChargesNotifier(deliveryChargesService, ref);
});

// Provider for delivery charges calculation
final deliveryChargesCalculatorProvider = Provider.family<Future<void>, Address>((ref, address) async {
  final notifier = ref.read(deliveryChargesProvider.notifier);
  return notifier.calculateDeliveryCharges(userAddress: address);
});