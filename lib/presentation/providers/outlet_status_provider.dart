import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../data/models/outlet_status_model.dart';
import '../../data/services/outlet_status_service.dart';
import 'launch_flow_provider.dart';
import 'outlet_provider.dart';

// Provider for the OutletStatusService
final outletStatusServiceProvider = Provider<OutletStatusService>((ref) {
  final logger = ref.watch(loggerProvider);
  return OutletStatusService(
    client: http.Client(),
    logger: logger,
  );
});

// Provider for current outlet status based on selected outlet
final currentOutletStatusProvider = FutureProvider<OutletStatus?>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  final outletStatusService = ref.watch(outletStatusServiceProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        return null;
      }
      
      return await outletStatusService.checkOutletStatus(
        storeCode: outlet.storeCode,
      );
    },
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

// Provider for outlet status by store code (family provider)
final outletStatusProvider = FutureProvider.family<OutletStatus?, String>((ref, storeCode) async {
  final outletStatusService = ref.watch(outletStatusServiceProvider);
  return await outletStatusService.checkOutletStatus(storeCode: storeCode);
});

// Provider to check if cart functionality should be enabled
final isCartEnabledProvider = Provider<bool>((ref) {
  final outletStatusAsync = ref.watch(currentOutletStatusProvider);
  
  return outletStatusAsync.when(
    data: (status) {
      if (status == null) {
        // If we can't fetch status, allow cart (fail-safe approach)
        return true;
      }
      return status.isFullyOperational;
    },
    loading: () => true, // Allow cart while loading
    error: (error, stackTrace) => true, // Allow cart on error (fail-safe)
  );
});

// Provider to get available delivery methods
final availableDeliveryMethodsProvider = Provider<List<String>>((ref) {
  final outletStatusAsync = ref.watch(currentOutletStatusProvider);
  
  return outletStatusAsync.when(
    data: (status) {
      if (status == null) {
        // Default to both methods if status unknown
        return ['Home Delivery', 'Store Pickup'];
      }
      return status.availableDeliveryMethods;
    },
    loading: () => [], // No methods while loading
    error: (error, stackTrace) => ['Home Delivery', 'Store Pickup'], // Default on error
  );
});

// Provider to get outlet status message for UI display
final outletStatusMessageProvider = Provider<String?>((ref) {
  final outletStatusAsync = ref.watch(currentOutletStatusProvider);
  
  return outletStatusAsync.when(
    data: (status) => status?.statusMessage,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

// Provider to refresh outlet status manually
final refreshOutletStatusProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.refresh(currentOutletStatusProvider);
  };
});
