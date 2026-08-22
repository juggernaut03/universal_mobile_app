// lib/presentation/providers/delivery_charges_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/address_model.dart';
import '../../data/services/delivery_charges_service.dart';
import 'cart_provider.dart';
import 'outlet_provider.dart';
import '../../di/service_providers.dart';
import '../../di/infrastructure_providers.dart';

// Provider for the DeliveryChargesService

// State for storing delivery charges
class DeliveryChargesState {
  final bool isLoading;
  final double deliveryCharge;
  final String? error;
  final bool freeDeliveryEligible;
  final double distance;

  /// The three components of [deliveryCharge], for a line-item breakdown.
  /// handlingFee/packageFee are store-configured flat charges that are NOT
  /// waived by free delivery — see the note on DeliveryChargeQuote.
  final double distanceCharge;
  final double handlingFee;
  final double packageFee;

  DeliveryChargesState({
    required this.isLoading,
    required this.deliveryCharge,
    this.error,
    required this.freeDeliveryEligible,
    required this.distance,
    this.distanceCharge = 0.0,
    this.handlingFee = 0.0,
    this.packageFee = 0.0,
  });

  DeliveryChargesState copyWith({
    bool? isLoading,
    double? deliveryCharge,
    String? error,
    bool? freeDeliveryEligible,
    double? distance,
    double? distanceCharge,
    double? handlingFee,
    double? packageFee,
  }) {
    return DeliveryChargesState(
      isLoading: isLoading ?? this.isLoading,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      error: error ?? this.error,
      freeDeliveryEligible: freeDeliveryEligible ?? this.freeDeliveryEligible,
      distance: distance ?? this.distance,
      distanceCharge: distanceCharge ?? this.distanceCharge,
      handlingFee: handlingFee ?? this.handlingFee,
      packageFee: packageFee ?? this.packageFee,
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
        distanceCharge: quote.distanceCharge,
        handlingFee: quote.handlingFee,
        packageFee: quote.packageFee,
      );

      logger.log(
          'Delivery charges updated - Distance: ${quote.distanceKm}km, Charge: ₹${quote.charge}, Free: ${quote.freeDelivery}');
    } catch (e) {
      logger.error('Error calculating delivery charges: $e');
      // Strip Dart's "Exception: " wrapper — the underlying message (e.g.
      // "Delivery not available beyond 5 km") is already user-facing text
      // from the backend's `reason` field.
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
        // A failed calculation must not leave a stale charge on screen —
        // this used to leave deliveryCharge/handlingFee/packageFee at
        // whatever they last were (often the 0.0 initial default), so an
        // address outside the delivery radius silently showed "Delivery
        // Fee: ₹0.00" and a correct-looking ₹0 total instead of blocking
        // checkout.
        deliveryCharge: 0.0,
        distanceCharge: 0.0,
        handlingFee: 0.0,
        packageFee: 0.0,
        freeDeliveryEligible: false,
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