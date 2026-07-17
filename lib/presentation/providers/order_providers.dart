// lib/presentation/providers/order_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/payment_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/order_payment_processing_service.dart';
import 'auth_providers.dart';
import 'cart_provider.dart';
import 'launch_flow_provider.dart';

// Enhanced payment service provider
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final logger = ref.watch(loggerProvider);
  final apiClient = ref.watch(apiClientProvider);
  return PaymentService(logger: logger, apiClient: apiClient);
});

// Order service provider
final orderServiceProvider = Provider<OrderService>((ref) {
  final logger = ref.watch(loggerProvider);
  final apiClient = ref.watch(apiClientProvider);
  return OrderService(logger: logger, apiClient: apiClient);
});

// Order payment processing service provider (pre-payment server cart sync)
final orderPaymentProcessingServiceProvider = Provider<OrderPaymentProcessingService>((ref) {
  final logger = ref.watch(loggerProvider);
  final cartValidator = ref.watch(cartValidatorProvider);
  return OrderPaymentProcessingService(logger: logger, cartValidator: cartValidator);
});

// Updated enum to track the current status of the order process
enum OrderProcessStatus {
  initial,
  validatingCart,
  markingPaymentProcessing, // Status for marking order as payment processing
  processingPayment,
  enhancingPaymentData,
  confirmingOrder,
  completed,
  failed,
}

// Provider to track the current order process status
final orderProcessStatusProvider = StateProvider<OrderProcessStatus>((ref) {
  return OrderProcessStatus.initial;
});

// Provider to store any error message during the order process
final orderErrorMessageProvider = StateProvider<String?>((ref) {
  return null;
});

// Provider to store payment result for access in different parts of the flow
final paymentResultProvider = StateProvider<PaymentResult?>((ref) {
  return null;
});

// Provider to store order confirmation result
final orderConfirmationResultProvider = StateProvider<OrderConfirmationResponse?>((ref) {
  return null;
});

// Provider to store payment processing result
final orderPaymentProcessingResultProvider = StateProvider<OrderPaymentProcessingResponse?>((ref) {
  return null;
});

// Provider to check if the order was successfully placed
final isOrderSuccessfulProvider = Provider<bool>((ref) {
  final orderStatus = ref.watch(orderProcessStatusProvider);
  final orderConfirmation = ref.watch(orderConfirmationResultProvider);
  
  return orderStatus == OrderProcessStatus.completed && 
         orderConfirmation != null && 
         orderConfirmation.success;
});

// Provider to clear all order-related state after completion
final resetOrderStateProvider = Provider<void Function()>((ref) {
  return () {
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.initial;
    ref.read(orderErrorMessageProvider.notifier).state = null;
    ref.read(paymentResultProvider.notifier).state = null;
    ref.read(orderConfirmationResultProvider.notifier).state = null;
    ref.read(orderPaymentProcessingResultProvider.notifier).state = null;
  };
});