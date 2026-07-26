import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_method_model.dart';
import '../../di/service_providers.dart';

// Provider for PaymentMethodService

// Provider for fetching payment methods
final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) async {
  final service = ref.watch(paymentMethodServiceProvider);
  return await service.getPaymentMethods();
});

// Provider for selected payment method
final selectedPaymentMethodProvider = StateProvider<PaymentMethod?>((ref) => null);

// Helper provider to get payment method by ID
final paymentMethodByIdProvider = Provider.family<PaymentMethod?, int>((ref, id) {
  final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
  return paymentMethodsAsync.when(
    data: (methods) => methods.firstWhere(
      (method) => method.idPaymentMode == id,
      orElse: () => methods.isNotEmpty ? methods.first : PaymentMethod(
        id: '',
        idPaymentMode: 0,
        paymentModeName: 'Unknown',
      ),
    ),
    loading: () => null,
    error: (_, __) => null,
  );
});