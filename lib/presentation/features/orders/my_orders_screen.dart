// lib/presentation/features/orders/my_orders_screen.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/cart_provider.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/launch_flow_provider.dart';

// Define the LoggingInterceptor class to debug HTTP requests
class LoggingInterceptor extends http.BaseClient {
  final http.Client _client;
  final Logger _logger;

  LoggingInterceptor(this._client, this._logger);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Log the request details
    _logger.log('🔴🔴🔴 HTTP DEBUG: Request: ${request.method} ${request.url}');
    _logger.log('🔴🔴🔴 HTTP DEBUG: Headers: ${request.headers}');
    
    // Force print to console
    print('🔴🔴🔴 HTTP DEBUG: Request: ${request.method} ${request.url}');
    print('🔴🔴🔴 HTTP DEBUG: Headers: ${request.headers}');
    
    if (request is http.Request && request.body.isNotEmpty) {
      _logger.log('🔴🔴🔴 HTTP DEBUG: Body: ${request.body}');
      print('🔴🔴🔴 HTTP DEBUG: Body: ${request.body}');
    }
    
    try {
      // Send the request and get the response
      final streamedResponse = await _client.send(request);
      
      // Create a buffer to store the response body
      final buffer = <int>[];
      await streamedResponse.stream.forEach(buffer.addAll);
      
      // Create a new response with the same data
      final responseBody = utf8.decode(buffer);
      _logger.log('🔴🔴🔴 HTTP DEBUG: Response Status: ${streamedResponse.statusCode}');
      _logger.log('🔴🔴🔴 HTTP DEBUG: Response Headers: ${streamedResponse.headers}');
      
      // Force print to console
      print('🔴🔴🔴 HTTP DEBUG: Response Status: ${streamedResponse.statusCode}');
      print('🔴🔴🔴 HTTP DEBUG: Response Headers: ${streamedResponse.headers}');
      
      // Log only a preview of large responses to avoid console flooding
      if (responseBody.length > 1000) {
        _logger.log('🔴🔴🔴 HTTP DEBUG: Response Body (Preview): ${responseBody.substring(0, 1000)}...');
        print('🔴🔴🔴 HTTP DEBUG: Response Body (Preview): ${responseBody.substring(0, 500)}...');
      } else {
        _logger.log('🔴🔴🔴 HTTP DEBUG: Response Body: $responseBody');
        print('🔴🔴🔴 HTTP DEBUG: Response Body: $responseBody');
      }
      
      // Return the response with the buffered data
      return http.StreamedResponse(
        Stream.fromIterable([buffer]),
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
        contentLength: buffer.length,
        reasonPhrase: streamedResponse.reasonPhrase,
      );
    } catch (e, stack) {
      _logger.error('🔴🔴🔴 HTTP DEBUG: Error: $e');
      _logger.error('🔴🔴🔴 HTTP DEBUG: Stack: $stack');
      
      // Force print to console
      print('🔴🔴🔴 HTTP DEBUG ERROR: $e');
      print('🔴🔴🔴 HTTP DEBUG STACK: $stack');
      
      rethrow;
    }
  }
}

// Create a provider for order repository
final orderRepositoryProvider = Provider((ref) {
  final logger = ref.read(loggerProvider);
  final authRepository = ref.read(authRepositoryProvider);
  
  logger.log('🔴🔴🔴 ORDERS DEBUG: Creating OrderRepository instance');
  print('🔴🔴🔴 ORDERS DEBUG: Creating OrderRepository instance');
  
  logger.log('🔴🔴🔴 ORDERS DEBUG: AuthRepository instance status: ${authRepository != null ? 'Available' : 'Missing'}');
  print('🔴🔴🔴 ORDERS DEBUG: AuthRepository instance status: ${authRepository != null ? 'Available' : 'Missing'}');
  
  // Create a client with logging interceptor
  final baseClient = http.Client();
  final loggingClient = LoggingInterceptor(baseClient, logger);
  
  return OrderRepository(
    client: loggingClient,
    authRepository: authRepository,
    logger: logger,
  );
});

// Provider for fetching orders
// Provider for fetching orders
final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final logger = ref.read(loggerProvider);
  logger.log('🔴🔴🔴 ORDERS DEBUG: Starting to fetch orders');
  
  try {
    // Check if user is logged in
    final authRepository = ref.read(authRepositoryProvider);
    final isLoggedIn = await authRepository.isLoggedIn();
    logger.log('🔴🔴🔴 ORDERS DEBUG: User login status: $isLoggedIn');
    
    if (!isLoggedIn) {
      logger.log('🔴🔴🔴 ORDERS DEBUG: User not logged in, returning empty orders list');
      return [];
    }
    
    // Get user profile
    final userProfile = await authRepository.getUserProfile();
    if (userProfile == null) {
      logger.log('🔴🔴🔴 ORDERS DEBUG: User profile is null, possibly missing access key');
      return [];
    }
    
    logger.log('🔴🔴🔴 ORDERS DEBUG: User profile retrieved: Mobile=${userProfile.mobile}, AccessKey=${userProfile.accessKey.isNotEmpty ? 'Present (Length: ${userProfile.accessKey.length})' : 'Missing'}');
    
    // Get the repository
    final repository = ref.watch(orderRepositoryProvider);
    
    // Force print to console
    print('🔴🔴🔴 ORDERS DEBUG: About to call repository.getOrderHistory()');
    
    // Fetch orders
    logger.log('🔴🔴🔴 ORDERS DEBUG: Calling repository.getOrderHistory()');
    final orders = await repository.getOrderHistory();
    logger.log('🔴🔴🔴 ORDERS DEBUG: Orders fetched successfully. Count: ${orders.length}');
    
    // Force print to console
    print('🔴🔴🔴 ORDERS DEBUG: Orders count: ${orders.length}');
    
    return orders;
  } catch (e, stacktrace) {
    logger.error('🔴🔴🔴 ORDERS DEBUG: Error fetching orders: $e');
    logger.error('🔴🔴🔴 ORDERS DEBUG: Stack trace: $stacktrace');
    
    // Force print to console 
    print('🔴🔴🔴 ORDERS DEBUG ERROR: $e');
    print('🔴🔴🔴 ORDERS DEBUG STACK: $stacktrace');
    
    throw e;
  }
});

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  // Add this method to explicitly check authentication status
  void _checkAuthStatus(WidgetRef ref) async {
    final logger = ref.read(loggerProvider);
    final authRepository = ref.read(authRepositoryProvider);
    
    try {
      print('🔴🔴🔴 AUTH DEBUG: Checking authentication status manually');
      logger.log('🔴🔴🔴 AUTH DEBUG: Checking authentication status manually');
      
      final isLoggedIn = await authRepository.isLoggedIn();
      print('🔴🔴🔴 AUTH DEBUG: User is logged in: $isLoggedIn');
      logger.log('🔴🔴🔴 AUTH DEBUG: User is logged in: $isLoggedIn');
      
      if (isLoggedIn) {
        final userProfile = await authRepository.getUserProfile();
        if (userProfile != null) {
          print('🔴🔴🔴 AUTH DEBUG: User profile details:');
          print('🔴🔴🔴 AUTH DEBUG: Mobile: ${userProfile.mobile}');
          print('🔴🔴🔴 AUTH DEBUG: Access key present: ${userProfile.accessKey.isNotEmpty}');
          print('🔴🔴🔴 AUTH DEBUG: Access key length: ${userProfile.accessKey.length}');
          if (userProfile.accessKey.isNotEmpty) {
            print('🔴🔴🔴 AUTH DEBUG: Access key first 5 chars: ${userProfile.accessKey.substring(0, min(5, userProfile.accessKey.length))}...');
          }
          
          logger.log('🔴🔴🔴 AUTH DEBUG: User profile found. Mobile: ${userProfile.mobile}');
          logger.log('🔴🔴🔴 AUTH DEBUG: Access key present: ${userProfile.accessKey.isNotEmpty}');
        } else {
          print('🔴🔴🔴 AUTH DEBUG: User profile is null despite logged in status');
          logger.log('🔴🔴🔴 AUTH DEBUG: User profile is null despite logged in status');
        }
      }
    } catch (e, stack) {
      print('🔴🔴🔴 AUTH DEBUG ERROR: $e');
      print('🔴🔴🔴 AUTH DEBUG STACK: $stack');
      logger.error('🔴🔴🔴 AUTH DEBUG ERROR: $e');
      logger.error('🔴🔴🔴 AUTH DEBUG STACK: $stack');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    logger.log('🔴🔴🔴 ORDERS DEBUG: Building MyOrdersScreen widget');
    print('🔴🔴🔴 ORDERS DEBUG: Building MyOrdersScreen widget');
    
    // Check authentication status right away
    _checkAuthStatus(ref);
    
    // Watch the orders provider to get order data
    final ordersAsync = ref.watch(ordersProvider);
    
    logger.log('🔴🔴🔴 ORDERS DEBUG: Orders provider state: ${ordersAsync is AsyncLoading ? 'Loading' : 
                                              ordersAsync is AsyncError ? 'Error' : 
                                              ordersAsync is AsyncData ? 'Data' : 'Unknown'}');
    print('🔴🔴🔴 ORDERS DEBUG: Orders provider state: ${ordersAsync is AsyncLoading ? 'Loading' : 
                                        ordersAsync is AsyncError ? 'Error' : 
                                        ordersAsync is AsyncData ? 'Data' : 'Unknown'}');
    
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
                    onTap: () {}, // Add savings screen functionality if needed
                  ),
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final logger = ref.read(loggerProvider);
                logger.log('🔴🔴🔴 ORDERS DEBUG: Orders data received. Count: ${orders.length}');
                print('🔴🔴🔴 ORDERS DEBUG: Orders data received. Count: ${orders.length}');
                
                if (orders.isEmpty) {
                  logger.log('🔴🔴🔴 ORDERS DEBUG: No orders found, showing empty state');
                  print('🔴🔴🔴 ORDERS DEBUG: No orders found, showing empty state');
                  return _buildEmptyState(context);
                }
                
                logger.log('🔴🔴🔴 ORDERS DEBUG: Showing order list with ${orders.length} items');
                print('🔴🔴🔴 ORDERS DEBUG: Showing order list with ${orders.length} items');
                return RefreshIndicator(
                  onRefresh: () async {
                    // Refresh the orders
                    return ref.refresh(ordersProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(context, ref, orders[index]);
                    },
                  ),
                );
              },
              loading: () {
                ref.read(loggerProvider).log('[DEBUG] Orders are loading...');
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading your orders...'),
                    ],
                  ),
                );
              },
              error: (error, stack) {
                final logger = ref.read(loggerProvider);
                logger.error('[DEBUG] Error in orders display: $error');
                logger.error('[DEBUG] Stack trace: $stack');
                return _buildErrorState(context, error, ref);
              },
            ),
          ),
        ],
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
    final logger = ref.read(loggerProvider);
    logger.log('🔴🔴🔴 DEBUG: Building error state with error: $error');
    print('🔴🔴🔴 DEBUG: Building error state with error: $error');
    
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
              logger.log('🔴🔴🔴 DEBUG: Refreshing orders provider after error');
              print('🔴🔴🔴 DEBUG: Refreshing orders provider after error');
              ref.refresh(ordersProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              logger.log('🔴🔴🔴 DEBUG: User chose to view debug info');
              print('🔴🔴🔴 DEBUG: User chose to view debug info');
              _showDebugInfoDialog(context, error);
            },
            child: const Text('Show Debug Info'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Trigger the manual auth check
              _checkAuthStatus(ref);
            },
            child: const Text('Check Auth Status'),
          ),
        ],
      ),
    );
  }
  
  // Add a method to show debug info in a dialog
  void _showDebugInfoDialog(BuildContext context, Object error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Error Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(error.toString()),
              const SizedBox(height: 16),
              const Text('Troubleshooting Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('1. Check your internet connection'),
              const Text('2. Verify that you are logged in'),
              const Text('3. Ensure your access token is valid'),
              const Text('4. Check if the API server is accessible'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
    final dateFormatter = DateFormat('dd-MMM-yyyy');
    final dateString = dateFormatter.format(order.orderDate);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order number and status
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Order No: ',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '# ${order.orderId}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 9,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey,
                    ),
                  ],
                ),
                // Order status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                    
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.status,
                         maxLines: 2,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Order details
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Order details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Delivery Type
                      Text(
                        'Delivery Type:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.deliveryMethod,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Order Total
                      Text(
                        'Order Total:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Via ${order.paymentMethod}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Time
                      Text(
                        'Time:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateString,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        order.deliverySlot,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right side: Savings circle
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'YOU SAVED',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${order.savings.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Download invoice button
                TextButton.icon(
                  onPressed: () => _downloadInvoice(context, ref, order),
                  icon: const Icon(
                    Icons.download_outlined,
                    color: Colors.grey,
                    size: 18,
                  ),
                  label: const Text(
                    'DOWNLOAD INVOICE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),

                // Reorder button
                TextButton(
                  onPressed: () => _reorderItems(context, ref, order),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text(
                    'REORDER',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(BuildContext context, WidgetRef ref, Order order) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating invoice...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Create PDF document
      final pdf = pw.Document();
      
      // Add invoice content
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Invoice',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'PatelMart',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                pw.SizedBox(height: 20),
                
                // Order details
                pw.Text('Order #: ${order.orderId}'),
                pw.SizedBox(height: 5),
                pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(order.orderDate)}'),
                pw.SizedBox(height: 5),
                pw.Text('Delivery Method: ${order.deliveryMethod}'),
                pw.SizedBox(height: 5),
                pw.Text('Delivery Slot: ${order.deliverySlot}'),
                
                pw.SizedBox(height: 20),
                
                // Items table
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Table header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    
                    // Table rows for each item
                    ...order.items.map((item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.product.productName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.quantity.toString()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('₹${item.product.ourPrice.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('₹${(item.product.ourPrice * item.quantity).toStringAsFixed(2)}'),
                        ),
                      ],
                    )),
                  ],
                ),
                
                pw.SizedBox(height: 20),
                
                // Order summary
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Subtotal: '),
                          pw.SizedBox(width: 50),
                          pw.Text('₹${order.totalAmount.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Delivery: '),
                          pw.SizedBox(width: 50),
                          pw.Text('₹0.00'),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Savings: '),
                          pw.SizedBox(width: 50),
                          pw.Text('₹${order.savings.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Total: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 50),
                          pw.Text('₹${order.totalAmount.toStringAsFixed(2)}', 
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 30),
                
                // Footer
                pw.Center(
                  child: pw.Text('Thank you for shopping with PatelMart!'),
                ),
              ],
            );
          },
        ),
      );

      // Save the PDF to a temporary file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${order.orderId}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invoice downloaded successfully!'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () {
              OpenFile.open(file.path);
            },
          ),
        ),
      );

      // Offer to share the file
      _showShareOptions(context, file);
    } catch (e) {
      ref.read(loggerProvider).error('Error generating invoice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate invoice: $e')),
      );
    }
  }

  void _showShareOptions(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.remove_red_eye),
            title: const Text('View Invoice'),
            onTap: () {
              Navigator.pop(context);
              OpenFile.open(file.path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Invoice'),
            onTap: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(file.path)], text: 'My order invoice from PatelMart');
            },
          ),
        ],
      ),
    );
  }

  void _reorderItems(BuildContext context, WidgetRef ref, Order order) {
    // Add all items from this order to cart
    final cartNotifier = ref.read(cartProvider.notifier);
    
    for (final item in order.items) {
      cartNotifier.addItemWithQuantity(item.product, item.quantity);
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All items added to cart!')),
    );
    
    // Navigate to cart
    context.push('/cart');
  }
}