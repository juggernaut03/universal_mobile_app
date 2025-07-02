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
    
    // Filter out orders with "In Cart" status only - keep Pending as valid orders
    // Updated to match new status values: Pending, Proocessing, In Packaging, Out for Delivery, Delivered
    final filteredOrders = allOrders.where((order) => 
        order.status.toLowerCase() != 'in cart').toList();
    
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

// Provider for filtering orders by status with new status values
final orderStatusFilterProvider = StateProvider<String>((ref) => 'All');

// Provider for filtered orders based on new status values
final filteredOrdersByStatusProvider = Provider<List<Order>>((ref) {
  final ordersAsync = ref.watch(orderHistoryProvider);
  final selectedFilter = ref.watch(orderStatusFilterProvider);
  
  return ordersAsync.when(
    data: (orders) {
      if (selectedFilter == 'All') {
        return orders;
      }
      
      return orders.where((order) {
        final status = order.status.toLowerCase();
        switch (selectedFilter) {
          case 'Pending':
            return status.contains('pending');
          case 'Proocessing':
            return status.contains('Proocessing');
          case 'In Packaging':
            return status.contains('in packaging') || status.contains('packaging');
          case 'Out for Delivery':
            return status.contains('out for delivery') || 
                   status.contains('dispatched') || 
                   status.contains('shipped');
          case 'Delivered':
            return status.contains('delivered');
          case 'Cancelled':
            return status.contains('cancelled');
          default:
            return true;
        }
      }).toList();
    },
    loading: () => <Order>[],
    error: (_, __) => <Order>[],
  );
});

// Provider to get order counts by status
final orderStatusCountsProvider = Provider<Map<String, int>>((ref) {
  final ordersAsync = ref.watch(orderHistoryProvider);
  
  return ordersAsync.when(
    data: (orders) {
      final counts = <String, int>{
        'All': orders.length,
        'Pending': 0,
        'Proocessing': 0,
        'In Packaging': 0,
        'Out for Delivery': 0,
        'Delivered': 0,
        'Cancelled': 0,
      };
      
      for (final order in orders) {
        final status = order.status.toLowerCase();
        if (status.contains('pending')) {
          counts['Pending'] = (counts['Pending'] ?? 0) + 1;
        } else if (status.contains('Proocessing')) {
          counts['Processing'] = (counts['Processing'] ?? 0) + 1;
        } else if (status.contains('in packaging') || status.contains('packaging')) {
          counts['In Packaging'] = (counts['In Packaging'] ?? 0) + 1;
        } else if (status.contains('out for delivery') || status.contains('dispatched') || status.contains('shipped')) {
          counts['Out for Delivery'] = (counts['Out for Delivery'] ?? 0) + 1;
        } else if (status.contains('delivered')) {
          counts['Delivered'] = (counts['Delivered'] ?? 0) + 1;
        } else if (status.contains('cancelled')) {
          counts['Cancelled'] = (counts['Cancelled'] ?? 0) + 1;
        }
      }
      
      return counts;
    },
    loading: () => <String, int>{},
    error: (_, __) => <String, int>{},
  );
});