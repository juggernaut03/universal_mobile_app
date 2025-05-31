import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../data/models/payment_method_model.dart';
import '../../data/services/payment_method_service.dart';
import 'launch_flow_provider.dart';

// Provider for PaymentMethodService
final paymentMethodServiceProvider = Provider<PaymentMethodService>((ref) {
  final logger = ref.watch(loggerProvider);
  return PaymentMethodService(
    client: http.Client(),
    logger: logger,
  );
});

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