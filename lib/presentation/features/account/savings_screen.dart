// lib/presentation/features/account/savings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:patelmart/presentation/providers/reorder_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/order_model.dart';
import '../../providers/auth_providers.dart';

// Provider to fetch all orders for calculating savings
final orderHistoryProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final authRepository = ref.read(authRepositoryProvider);
  final userProfile = await authRepository.getUserProfile();
  
  if (userProfile == null) {
    return [];
  }
  
  // You would need to create an OrderRepository and inject it 
  // or use the existing one from my_orders_screen.dart
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
  // Get the async value of orders
  final ordersAsyncValue = ref.watch(orderHistoryProvider);
  
  // Default values if no orders or loading/error state
  return ordersAsyncValue.when(
    data: (orders) {
      if (orders.isEmpty) {
        return SavingsStats.empty();
      }
      
      // Calculate statistics
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
  
  // Empty stats for loading or error states
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

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Format currency values
    final currencyFormatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );
    
    // Watch the savings stats provider
    final savingsStats = ref.watch(savingsStatsProvider);
    
    // Watch the order history loading state
    final orderHistoryAsync = ref.watch(orderHistoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings on Pate RMart'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Cart button with total amount
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                
                
              ],
            ),
          ),
        ],
      ),
      body: orderHistoryAsync.when(
        data: (_) => _buildSavingsContent(context, savingsStats, currencyFormatter),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading savings: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(orderHistoryProvider),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSavingsContent(
    BuildContext context, 
    SavingsStats stats, 
    NumberFormat formatter
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero banner section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(
              color: Color(0xFF4D9EA8), // Teal background from the UI
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Wow! Look How\nMuch You Saved',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore your savings with us',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Savings callout bubble
                Container(
                  width: 300,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(75),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Main savings amount
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'You have saved',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatter.format(stats.totalSavings),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Text(
                              'with us so far',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Bottom callout decoration
                      Positioned(
                        bottom: 0,
                        right: 70,
                        child: CustomPaint(
                          size: const Size(40, 30),
                          painter: SpeechBubbleArrowPainter(
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Stats grid
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // First row: Total Spends and Actual MRP
                Row(
                  children: [
                    // Total Spends
                    Expanded(
                      child: _buildStatTile(
                        icon: Icons.account_balance_wallet,
                        iconColor: Colors.green,
                        title: 'Total Spends',
                        value: formatter.format(stats.totalSpent),
                      ),
                    ),
                    
                    // Actual MRP Value
                    Expanded(
                      child: _buildStatTile(
                        icon: Icons.price_check,
                        iconColor: Colors.green,
                        title: 'Actual MRP Value',
                        value: formatter.format(stats.totalMrp),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Second row: Order Count and Avg Savings
                Row(
                  children: [
                    // Total Order Count
                    Expanded(
                      child: _buildStatTile(
                        icon: Icons.shopping_bag_outlined,
                        iconColor: Colors.green,
                        title: 'Total Order Count',
                        value: stats.orderCount.toString(),
                        isNumber: true,
                      ),
                    ),
                    
                    // Avg Savings per order
                    Expanded(
                      child: _buildStatTile(
                        icon: Icons.savings_outlined,
                        iconColor: Colors.green,
                        title: 'Avg Savings',
                        value: formatter.format(stats.avgSavingsPerOrder),
                        suffix: '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Additional help text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Continue shopping to save more on your favorite products!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
              ),
            ),
          ),
          
          // Shop now button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'SHOP NOW',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatTile({
    required IconData icon, 
    required Color iconColor, 
    required String title, 
    required String value,
    String? suffix,
    bool isNumber = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isNumber ? 28 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom painter for the speech bubble arrow
class SpeechBubbleArrowPainter extends CustomPainter {
  final Color color;
  
  SpeechBubbleArrowPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}