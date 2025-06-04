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

// Provider for order filtering
final orderFilterProvider = StateProvider<String>((ref) => 'All');

// Provider for fetching and filtering orders
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
    final filteredOrders = allOrders
        .where((order) => 
            order.status.toLowerCase() != 'in cart' && 
            order.status.toLowerCase() != 'pending')
        .toList();
    
    // Sort by latest first (most recent order date first) - FRONTEND SORTING
    filteredOrders.sort((a, b) {
      // Compare dates - latest date comes first
      final comparison = b.orderDate.compareTo(a.orderDate);
      logger.log('Comparing order dates: ${a.orderId} (${a.orderDate}) vs ${b.orderId} (${b.orderDate}) = $comparison');
      return comparison;
    });
    
    logger.log('Orders fetched and sorted by latest date first. Total: ${filteredOrders.length}');
    if (filteredOrders.isNotEmpty) {
      logger.log('Latest order: ${filteredOrders.first.orderId} - ${filteredOrders.first.orderDate}');
      logger.log('Oldest order: ${filteredOrders.last.orderId} - ${filteredOrders.last.orderDate}');
    }
    
    return filteredOrders;
  } catch (e, stacktrace) {
    logger.error('Error fetching orders: $e');
    logger.error('Stack trace: $stacktrace');
    throw e;
  }
});

// Provider for filtered orders based on selected filter
final filteredOrdersProvider = Provider<List<Order>>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  final selectedFilter = ref.watch(orderFilterProvider);
  
  return ordersAsync.when(
    data: (orders) {
      List<Order> filteredList;
      
      if (selectedFilter == 'All') {
        filteredList = orders;
      } else {
        // Filter orders based on status
        filteredList = orders.where((order) {
          switch (selectedFilter) {
            case 'Delivered':
              return order.status.toLowerCase().contains('delivered');
            case 'Processing':
              return order.status.toLowerCase().contains('processing') ||
                     order.status.toLowerCase().contains('confirmed') ||
                     order.status.toLowerCase().contains('preparing');
            case 'Cancelled':
              return order.status.toLowerCase().contains('cancelled');
            default:
              return true;
          }
        }).toList();
      }
      
      // Ensure filtered list is also sorted by latest date first
      filteredList.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      
      return filteredList;
    },
    loading: () => <Order>[],
    error: (_, __) => <Order>[],
  );
});

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final filteredOrders = ref.watch(filteredOrdersProvider);
    final selectedFilter = ref.watch(orderFilterProvider);
    
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
            fontSize: 18,
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
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick reorder and savings cards - Reduced height and cleaner design
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                // Quick Reorder Card - Sleeker design
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.refresh,
                    iconColor: Colors.blue,
                    title: 'Reorder',
                    subtitle: 'From Past Orders',
                    onTap: () => context.push('/reorder'),
                  ),
                ),
                const SizedBox(width: 8),
                // My Savings Card - Sleeker design
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.savings_outlined,
                    iconColor: AppColors.primary,
                    title: 'My Savings',
                    subtitle: 'Track  Savings',
                    onTap: () => context.push('/savings'),
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(ref, 'All', selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip(ref, 'Delivered', selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip(ref, 'Processing', selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip(ref, 'Cancelled', selectedFilter),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Orders list
          Expanded(
            child: ordersAsync.when(
              data: (allOrders) {
                if (allOrders.isEmpty) {
                  return _buildEmptyState(context);
                }
                
                if (filteredOrders.isEmpty && selectedFilter != 'All') {
                  return _buildNoResultsState(context, selectedFilter);
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    // Refresh the orders
                    return ref.refresh(ordersProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      return OrderCardWidget(
                        order: filteredOrders[index],
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

  Widget _buildFilterChip(WidgetRef ref, String filter, String selectedFilter) {
    final isSelected = selectedFilter == filter;
    
    return FilterChip(
      label: Text(
        filter,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        ref.read(orderFilterProvider.notifier).state = filter;
      },
      backgroundColor: Colors.grey[100],
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      side: BorderSide.none,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                icon,
                color: iconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey[400],
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

  Widget _buildNoResultsState(BuildContext context, String filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No $filter orders found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different filter',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
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