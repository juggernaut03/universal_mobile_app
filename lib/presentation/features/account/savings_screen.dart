// lib/presentation/features/account/savings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:patelmart/presentation/providers/reorder_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../providers/auth_providers.dart';

// Provider for the profile repository (removed local definition, use the global one from profile_repository.dart)

// Provider to fetch user profile details from API
final userProfileDetailsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authRepository = ref.read(authRepositoryProvider);
  final userProfile = await authRepository.getUserProfile();
  
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
  final authRepository = ref.read(authRepositoryProvider);
  final userProfile = await authRepository.getUserProfile();
  
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

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsStats = ref.watch(savingsStatsProvider);
    final orderHistoryAsync = ref.watch(orderHistoryProvider);
    final userProfileDetailsAsync = ref.watch(userProfileDetailsProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Your Savings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: orderHistoryAsync.when(
        data: (_) => _buildSavingsContent(context, savingsStats, userProfileDetailsAsync),
        loading: () => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        error: (error, _) => _buildErrorState(context, ref, error.toString()),
      ),
    );
  }
  
  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load savings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => ref.refresh(orderHistoryProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSavingsContent(BuildContext context, SavingsStats stats, AsyncValue<Map<String, dynamic>> userProfileDetailsAsync) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero savings card
          _buildHeroSavingsCard(context, stats, userProfileDetailsAsync),
          
          const SizedBox(height: 24),
          
          // Statistics grid
          _buildStatsGrid(context, stats),
          
          const SizedBox(height: 24),
          
          // Motivational section
          _buildMotivationalSection(context),
          
          const SizedBox(height: 32),
          
          // Shop now button
          _buildShopNowButton(context),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildHeroSavingsCard(BuildContext context, SavingsStats stats, AsyncValue<Map<String, dynamic>> userProfileDetailsAsync) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Dynamic greeting with username
            userProfileDetailsAsync.when(
              data: (profileData) {
                // Extract username from profile data
                String username = 'User'; // Default fallback
                
                if (profileData.isNotEmpty) {
                  // Try to construct full name from first and last name
                  final firstName = profileData['first_name']?.toString().trim() ?? '';
                  final lastName = profileData['last_name']?.toString().trim() ?? '';
                  
                  if (firstName.isNotEmpty && lastName.isNotEmpty) {
                    username = '$firstName $lastName';
                  } else if (firstName.isNotEmpty) {
                    username = firstName;
                  } else if (lastName.isNotEmpty) {
                    username = lastName;
                  } else {
                    // If no name data, try to use mobile number as fallback
                    final mobile = profileData['mobile_number']?.toString() ?? '';
                    if (mobile.isNotEmpty) {
                      // Show only last 4 digits for privacy
                      username = mobile.length > 4 ? '***${mobile.substring(mobile.length - 4)}' : mobile;
                    }
                  }
                }
                
                return RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Hurry! '),
                      TextSpan(
                        text: username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Text(
                'Hurry! Loading...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              error: (error, _) => const Text(
                'Hurry! User',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 4),
            
            const Text(
              'Your Life Time Savings',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '₹',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  NumberFormat('#,##,###').format(stats.totalSavings.toInt()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsGrid(BuildContext context, SavingsStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Spent',
                  value: '₹${NumberFormat('#,##,###').format(stats.totalSpent.toInt())}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'MRP Value',
                  value: '₹${NumberFormat('#,##,###').format(stats.totalMrp.toInt())}',
                  icon: Icons.local_offer_rounded,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Orders',
                  value: stats.orderCount.toString(),
                  icon: Icons.shopping_bag_rounded,
                  color: const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Avg Savings',
                  value: '₹${NumberFormat('#,###').format(stats.avgSavingsPerOrder.toInt())}',
                  icon: Icons.savings_rounded,
                  color: const Color(0xFF9C27B0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMotivationalSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keep it up!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Continue shopping to save even more on your favorite products',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShopNowButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, const Color(0xFF1976D2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/home'),
            borderRadius: BorderRadius.circular(16),
            child: const Center(
              child: Text(
                'Continue Shopping',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}