// lib/presentation/providers/orders_screen_providers.dart
//
// Order list for the My Orders screen.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order_model.dart';
import '../../di/auth_providers.dart';
import '../../di/infrastructure_providers.dart';
import '../../di/repository_providers.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final logger = ref.read(loggerProvider);
  logger.log('Fetching orders list');
  
  try {
    // Check if user is logged in
    final isLoggedIn = await ref.read(authRepositoryProvider).isSignedIn();
    logger.log('User login status: $isLoggedIn');
    
    if (!isLoggedIn) {
      logger.log('User not logged in, returning empty orders list');
      return [];
    }
    
    // Get the repository
    final repository = ref.watch(orderRepositoryProvider);
    
    // Fetch orders
    final allOrders = await repository.getOrderHistory();
    
    // Filter out orders with "In Cart" status - keep Pending status as valid order
    final filteredOrders = allOrders
        .where((order) => 
            order.status.toLowerCase() != 'in cart')
        .toList();
    
    // Sort by latest order_date_time first (most recent order first)
    filteredOrders.sort((a, b) {
      final aDateTime = a.orderDateTime ?? a.orderDate;
      final bDateTime = b.orderDateTime ?? b.orderDate;
      
      // Latest date/time comes first (descending order)
      final comparison = bDateTime.compareTo(aDateTime);
      
      logger.log('Comparing orders: '
          'Order ${a.displayOrderId} ($aDateTime) vs '
          'Order ${b.displayOrderId} ($bDateTime) = $comparison');
      
      return comparison;
    });
    
    logger.log('Orders fetched and sorted by latest date/time first. Total: ${filteredOrders.length}');
    
    if (filteredOrders.isNotEmpty) {
      final latest = filteredOrders.first;
      final oldest = filteredOrders.last;
      logger.log('Latest order: ${latest.displayOrderId} - ${latest.orderDateTime ?? latest.orderDate}');
      logger.log('Oldest order: ${oldest.displayOrderId} - ${oldest.orderDateTime ?? oldest.orderDate}');
    }
    
    return filteredOrders;
  } catch (e, stacktrace) {
    logger.error('Error fetching orders: $e');
    logger.error('Stack trace: $stacktrace');
    rethrow;
  }
});
