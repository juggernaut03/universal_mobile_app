// lib/presentation/features/orders/my_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/reorder_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/launch_flow_provider.dart';
import 'order_card_widget.dart';
import 'order_detail_screen.dart';

// Provider for fetching orders
final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final logger = ref.read(loggerProvider);
  logger.log('Fetching orders list');
  
  try {
    // Check if user is logged in
    final authRepository = ref.read(authRepositoryProvider);
    final isLoggedIn = await authRepository.isLoggedIn();
    logger.log('User login status: $isLoggedIn');
    
    if (!isLoggedIn) {
      logger.log('User not logged in, returning empty orders list');
      return [];
    }
    
    // Get the repository
    final repository = ref.watch(orderRepositoryProvider);
    
    // Fetch orders
    final allOrders = await repository.getOrderHistory();
    
    // Filter out orders with "In Cart" status
    final filteredOrders = allOrders.where((order) => 
        order.status.toLowerCase() != 'in cart' && 
        order.status.toLowerCase() != 'pending').toList();
    
    logger.log('Orders fetched successfully. Total: ${filteredOrders.length}');
    
    return filteredOrders;
  } catch (e, stacktrace) {
    logger.error('Error fetching orders: $e');
    logger.error('Stack trace: $stacktrace');
    throw e;
  }
});

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Navigate to help screen
              context.push('/help-support');
            },
            child: const Text(
              'NEED HELP?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick reorder and savings cards
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Quick Reorder Card
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.refresh,
                    iconColor: Colors.blue,
                    title: 'Quick Reorder',
                    subtitle: 'Reorder From\nPast & Saved Items',
                    onTap: () => context.push('/reorder'),
                  ),
                ),
                const SizedBox(width: 12),
                // My Savings Card
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.savings_outlined,
                    iconColor: AppColors.primary,
                    title: 'My Savings',
                    subtitle: 'Explore Your\nSavings With Us',
                    onTap: () => context.push('/savings'),// Add savings screen functionality if needed
                  ),
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return _buildEmptyState(context);
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    // Refresh the orders
                    return ref.refresh(ordersProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return OrderCardWidget(
                        order: orders[index],
                        onOrderTap: (order) {
                          _navigateToOrderDetail(context, order);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading your orders...'),
                  ],
                ),
              ),
              error: (error, stack) => _buildErrorState(context, error, ref),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToOrderDetail(BuildContext context, Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: order),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 20,
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your order history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.refresh(ordersProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}