// lib/presentation/providers/savings_providers.dart
//
// Savings summary, moved out of savings_screen.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order_model.dart';
import '../../di/auth_providers.dart';
import '../../di/repository_providers.dart';

// Model to hold savings statistics
class SavingsStats {
  final double totalSavings;
  final double totalSpent;
  final double totalMrp;
  final int orderCount;
  final double avgSavingsPerOrder;
  
  SavingsStats({
    required this.totalSavings,
    required this.totalSpent,
    required this.totalMrp,
    required this.orderCount,
    required this.avgSavingsPerOrder,
  });
  
  factory SavingsStats.empty() {
    return SavingsStats(
      totalSavings: 0,
      totalSpent: 0,
      totalMrp: 0,
      orderCount: 0,
      avgSavingsPerOrder: 0,
    );
  }
}

final userProfileDetailsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userProfile = (await ref.read(authRepositoryProvider).currentSession()).valueOrNull;
  
  if (userProfile == null) {
    return {};
  }
  
  final profileRepository = ref.read(profileRepositoryProvider);
  try {
    final profileData = await profileRepository.getUserProfile();
    return profileData;
  } catch (e) {
    // Return basic info if API call fails
    return {
      'mobile_number': userProfile.mobile,
      'first_name': '',
      'last_name': '',
    };
  }
});

// Provider to fetch all orders for calculating savings
final orderHistoryProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final userProfile = (await ref.read(authRepositoryProvider).currentSession()).valueOrNull;
  
  if (userProfile == null) {
    return [];
  }
  
  final orderRepository = ref.read(orderRepositoryProvider);
  final orders = await orderRepository.getOrderHistory();
  
  // Filter out orders with "In Cart" status
  return orders.where((order) => 
    order.status.toLowerCase() != 'in cart' && 
    order.status.toLowerCase() != 'pending'
  ).toList();
});

// Provider for calculating savings statistics
final savingsStatsProvider = Provider.autoDispose<SavingsStats>((ref) {
  final ordersAsyncValue = ref.watch(orderHistoryProvider);
  
  return ordersAsyncValue.when(
    data: (orders) {
      if (orders.isEmpty) {
        return SavingsStats.empty();
      }
      
      double totalSpent = 0;
      double totalMrp = 0;
      
      for (final order in orders) {
        totalSpent += order.totalAmount;
        totalMrp += order.totalMrp;
      }
      
      final totalSavings = totalMrp - totalSpent;
      final double avgSavingsPerOrder = orders.isEmpty ? 0 : totalSavings / orders.length;
      
      return SavingsStats(
        totalSavings: totalSavings,
        totalSpent: totalSpent,
        totalMrp: totalMrp,
        orderCount: orders.length,
        avgSavingsPerOrder: avgSavingsPerOrder,
      );
    },
    loading: () => SavingsStats.empty(),
    error: (_, __) => SavingsStats.empty(),
  );
});
