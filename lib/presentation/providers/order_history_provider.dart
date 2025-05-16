// lib/presentation/features/orders/providers/order_history_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/repositories/order_repository.dart';


// Provider for the OrderRepository instance
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final logger = ref.read(loggerProvider);
  final authRepository = ref.read(authRepositoryProvider);
  
  // Create a standard client for production use
  final client = http.Client();
  
  return OrderRepository(
    client: client,
    authRepository: authRepository,
    logger: logger,
  );
});

// Provider to fetch all orders
final orderHistoryProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final logger = ref.read(loggerProvider);
  logger.log('Fetching order history');
  
  try {
    // Check if user is logged in
    final authRepository = ref.read(authRepositoryProvider);
    final isLoggedIn = await authRepository.isLoggedIn();
    logger.log('User login status: $isLoggedIn');
    
    if (!isLoggedIn) {
      logger.log('User not logged in, returning empty orders list');
      return [];
    }
    
    // Get user profile
    final userProfile = await authRepository.getUserProfile();
    if (userProfile == null) {
      logger.log('User profile is null, possibly missing access key');
      return [];
    }
    
    // Get the repository
    final repository = ref.watch(orderRepositoryProvider);
    
    // Fetch orders
    logger.log('Calling repository.getOrderHistory()');
    final allOrders = await repository.getOrderHistory();
    
    // Filter out orders with "In Cart" status
    final filteredOrders = allOrders.where((order) => 
        order.status.toLowerCase() != 'in cart' && 
        order.status.toLowerCase() != 'pending').toList();
    
    logger.log('Orders fetched successfully. Total count: ${allOrders.length}, Filtered count: ${filteredOrders.length}');
    
    return filteredOrders;
  } catch (e, stacktrace) {
    logger.error('Error fetching orders: $e');
    logger.error('Stack trace: $stacktrace');
    throw e;
  }
});

// Provider for a single order's details
final orderDetailsProvider = FutureProvider.family<Order?, String>((ref, orderId) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getOrderDetails(orderId);
});

// Provider to expose a reorder function
final reorderFunctionProvider = Provider<Future<bool> Function(String)>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return (String orderId) => repository.reorder(orderId);
});

// Provider to expose a cancel order function
final cancelOrderFunctionProvider = Provider<Future<bool> Function(String, String)>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return (String orderId, String reason) => repository.cancelOrder(orderId, reason);
});