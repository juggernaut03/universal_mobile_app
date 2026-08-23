// lib/presentation/providers/delivery_slot_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/delivery_slot_model.dart';
import 'outlet_provider.dart';
import '../../di/service_providers.dart';

// Provider for the DeliverySlotService

// Provider for delivery slots based on selected outlet
final deliverySlotsProvider = FutureProvider<List<DeliverySlot>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  final deliverySlotService = ref.watch(deliverySlotServiceProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      return await deliverySlotService.getDeliverySlots(
        storeCode: outlet.storeCode,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// Provider for delivery slots grouped by date
final deliverySlotsGroupedProvider = FutureProvider<Map<String, List<DeliverySlot>>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  final deliverySlotService = ref.watch(deliverySlotServiceProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      return await deliverySlotService.getDeliverySlotsGrouped(
        storeCode: outlet.storeCode,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// Provider for delivery dates based on selected outlet
final deliveryDatesProvider = FutureProvider<List<String>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  final deliverySlotService = ref.watch(deliverySlotServiceProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      return await deliverySlotService.fetchDeliveryDates(
        storeCode: outlet.storeCode,
        startOffsetDays: outlet.deliveryStartOffsetDays,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// Provider for self-pickup delivery slots based on selected outlet
final selfPickupDeliverySlotsProvider = FutureProvider<List<DeliverySlot>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  final deliverySlotService = ref.watch(deliverySlotServiceProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      return await deliverySlotService.getSelfPickupDeliverySlots(
        storeCode: outlet.storeCode,
      );
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// Provider to refresh delivery slots manually
final refreshDeliverySlotsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.invalidate(deliverySlotsProvider);
    ref.invalidate(deliverySlotsGroupedProvider);
    ref.invalidate(deliveryDatesProvider);
    ref.invalidate(selfPickupDeliverySlotsProvider);
  };
});