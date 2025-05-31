// lib/presentation/providers/delivery_slot_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../data/models/delivery_slot_model.dart';
import '../../data/services/delivery_slot_service.dart';
import 'launch_flow_provider.dart';
import 'outlet_provider.dart';

// Provider for the DeliverySlotService
final deliverySlotServiceProvider = Provider<DeliverySlotService>((ref) {
  final logger = ref.watch(loggerProvider);
  return DeliverySlotService(
    client: http.Client(),
    logger: logger,
  );
});

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

// Provider to refresh delivery slots manually
final refreshDeliverySlotsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.refresh(deliverySlotsProvider);
    ref.refresh(deliverySlotsGroupedProvider);
  };
});