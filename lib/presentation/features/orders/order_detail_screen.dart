// lib/presentation/features/orders/order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../cart/widgets/persistent_cart_widget.dart';
import '../../../di/infrastructure_providers.dart';
import 'package:flutter/foundation.dart';

class OrderDetailScreen extends ConsumerWidget {
  final Order order;

  const OrderDetailScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    logger.log('Building OrderDetailScreen for order: ${order.displayOrderId}');

    // Use order_date_time if available, otherwise fallback to orderDate
    final displayDate = order.orderDateTime ?? order.orderDate;
    final dateFormatter = DateFormat('dd-MMM-yyyy');
    final timeFormatter = DateFormat('hh:mm a');
    final fullDateFormatter = DateFormat('EEEE, dd MMMM yyyy');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.push('/help-support');
            },
            child: Text(
              'NEED HELP?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content in a scrollable view
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          _buildStatusChip(order.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Order Number - Use actual_order_id if available
                      _buildInfoRow(
                        'Order Number:', 
                        order.actualOrderId != null 
                            ? '#${order.actualOrderId}' 
                            : '#${order.orderId}'
                      ),
                      const SizedBox(height: 12),
                      
                      // Order Date and Time - Use order_date_time
                      _buildInfoRow(
                        'Ordered Date:', 
                        dateFormatter.format(displayDate)
                      ),
                      const SizedBox(height: 12),
                      
                      // Order Time
                      _buildInfoRow(
                        'Ordered Time:', 
                        timeFormatter.format(displayDate)
                      ),
                      const SizedBox(height: 12),
                      
                      // Full Date Display
                      _buildInfoRow(
                        'Order Day:', 
                        fullDateFormatter.format(displayDate)
                      ),
                      const SizedBox(height: 12),

                      _buildInfoRow('Total Amount:', '₹${order.totalAmount.toStringAsFixed(order.totalAmount.truncateToDouble() == order.totalAmount ? 0 : 2)}'),
                      const SizedBox(height: 12),
                      if ((order.refundAmount ?? 0) > 0) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                'Refund Amount:',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '₹${order.refundAmount!.toStringAsFixed(order.refundAmount!.truncateToDouble() == order.refundAmount! ? 0 : 2)}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildInfoRow('Payment Mode:', order.paymentMethod),
                      const SizedBox(height: 12),
                      _buildInfoRow('Delivery Slot:', order.deliverySlot),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Delivery Address Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                        Text(
                          order.deliveryAddress!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        )
                      else
                        const Text(
                          'No delivery address provided',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Order Timing Information Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Timeline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Recent order indicator
                      if (order.isRecent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Recent Order (Last 24 hours)',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // Time since order
                      Text(
                        'Ordered ${_getTimeAgo(displayDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Payment Details Section (Collapsible)
                _buildExpandableSection(
                  title: 'Payment Details',
                  initiallyExpanded: false,
                  children: [
                    _buildPaymentDetails(order),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Order Items Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Items (${order.items.length} Items)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildItemsList(order),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Reorder Button
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: InkWell(
                    onTap: () => _reorderItems(context, ref, order),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: Text(
                        'REORDER',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          // Position the persistent cart widget at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const PersistentCartWidget(),
          ),
        ],
      ),
    );
  }

  // Helper method to get time ago string
  String _getTimeAgo(DateTime orderDate) {
    final now = DateTime.now();
    final difference = now.difference(orderDate);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    // Determine color based on status
    switch (status.toLowerCase()) {
      case 'delivered':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'shipped':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue;
        icon = Icons.local_shipping;
        break;
      case 'processing':
      case 'confirmed':
      case 'order confirmed':
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case 'cancelled':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 12),
          const SizedBox(width: 3),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required List<Widget> children,
    Widget? trailing,
    bool initiallyExpanded = false,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: trailing,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: initiallyExpanded,
        children: children,
      ),
    );
  }

  Widget _buildPaymentDetails(Order order) {
    final delivery = order.deliveryAmount ?? 0.0;
    final cartTotal = order.totalAmount - delivery;
    final savings = order.savings;
    final refund = order.refundAmount ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow('Payment Mode:', order.paymentMethod),
          const SizedBox(height: 12),
          _buildInfoRow('Total Amount:', '₹${order.totalAmount.toStringAsFixed(order.totalAmount.truncateToDouble() == order.totalAmount ? 0 : 2)}'),
          const SizedBox(height: 12),
          _buildInfoRow('Cart Total:', '₹${cartTotal.toStringAsFixed(cartTotal.truncateToDouble() == cartTotal ? 0 : 2)}'),
          const SizedBox(height: 12),
          
          // Delivery Charges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  'Delivery Charges:',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (delivery == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Special Offer',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      delivery > 0 ? '₹${delivery.toStringAsFixed(delivery.truncateToDouble() == delivery ? 0 : 2)}' : '₹49',
                      style: TextStyle(
                        color: delivery > 0 ? Colors.black : Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: delivery > 0 ? TextDecoration.none : TextDecoration.lineThrough,
                      ),
                    ),
                    if (delivery == 0)
                      const Text(
                        ' ₹0',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          if (savings > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.amber[50],
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber[700], size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Total Savings',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${savings.toStringAsFixed(savings.truncateToDouble() == savings ? 0 : 2)}',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (refund > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.green[50],
              child: Row(
                children: [
                  Icon(Icons.currency_rupee, color: Colors.green[700], size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Refund Amount',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${refund.toStringAsFixed(refund.truncateToDouble() == refund ? 0 : 2)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
Widget _buildItemsList(Order order) {
    // DEBUG: Let's see what the actual status is
    if (kDebugMode) print('DEBUG: Original status: "${order.status}"');
    if (kDebugMode) print('DEBUG: Status length: ${order.status.length}');
    if (kDebugMode) print('DEBUG: Status toLowerCase: "${order.status.toLowerCase()}"');
    if (kDebugMode) print('DEBUG: Status trim toLowerCase: "${order.status.trim().toLowerCase()}"');
    
    // Check if we should show prices based on order status
    final shouldShowPrices = _shouldShowItemPrices(order.status);
    if (kDebugMode) print('DEBUG: shouldShowPrices result: $shouldShowPrices');
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: order.items.length,
      separatorBuilder: (context, index) => const Divider(height: 16, thickness: 0.5),
      itemBuilder: (context, index) {
        final item = order.items[index];
        final mrp = item.product.productMrp;
        final sellingPrice = item.product.ourPrice;
        final savings = (mrp - sellingPrice) * item.quantity;
        final isUnavailable = order.unavailableItems.contains(item.product.pCode);

        return Opacity(
          opacity: isUnavailable ? 0.55 : 1.0,
          child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ColorFiltered(
                      colorFilter: isUnavailable
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                      child: item.product.pcodeImg.isNotEmpty
                          ? Image.network(
                              item.product.pcodeImg,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported_outlined, size: 20),
                            )
                          : const Icon(Icons.image_not_supported_outlined, size: 20),
                    ),
                  ),
                  if (isUnavailable)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 70,
                          height: 1.5,
                          color: Colors.red.withOpacity(0.6),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        height: 1.3,
                        decoration: isUnavailable ? TextDecoration.lineThrough : TextDecoration.none,
                        color: isUnavailable ? Colors.grey[700] : Colors.black,
                      ),
                    ),
                    if (isUnavailable) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          'Not Available',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else if (order.updatedQuantities[item.product.pCode] != null &&
                        order.updatedQuantities[item.product.pCode] != item.quantity) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Qty Updated',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.error,
                              size: 12,
                              color: Colors.orange[700],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${item.product.packageSize} ${item.product.packageUnit}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        decoration: isUnavailable ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Builder(
                      builder: (context) {
                        if (isUnavailable) {
                          return Text(
                            'Quantity: ${item.quantity}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          );
                        }
                        final updatedQty = order.updatedQuantities[item.product.pCode];
                        final hasUpdate = updatedQty != null && updatedQty != item.quantity;
                        if (!hasUpdate) {
                          return Text(
                            'Quantity: ${item.quantity}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Quantity: ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${item.quantity}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$updatedQty',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'Available',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    // DEBUG: Always show what status check result is
                    const SizedBox(height: 6),
                    // Container(
                    //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    //   decoration: BoxDecoration(
                    //     color: Colors.yellow[100],
                    //     borderRadius: BorderRadius.circular(12),
                    //     border: Border.all(color: Colors.yellow[300]!),
                    //   ),
                    //   child: Text(
                    //     'DEBUG: Status="${order.status}" | ShowPrices=$shouldShowPrices',
                    //     style: TextStyle(
                    //       color: Colors.black,
                    //       fontSize: 9,
                    //       fontWeight: FontWeight.bold,
                    //     ),
                    //   ),
                    // ),
                    
                    // Conditional price display based on order status
                    if (shouldShowPrices) ...[
                      const SizedBox(height: 6),
                      // Price information - only show for processing orders
                      Row(
                        children: [
                          Text(
                            '₹${(sellingPrice * item.quantity).toStringAsFixed((sellingPrice * item.quantity).truncateToDouble() == (sellingPrice * item.quantity) ? 0 : 2)}',
                            style: TextStyle(
                              color: isUnavailable ? Colors.grey[600] : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: isUnavailable ? TextDecoration.lineThrough : TextDecoration.none,
                            ),
                          ),
                          if (savings > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '₹${(mrp * item.quantity).toStringAsFixed((mrp * item.quantity).truncateToDouble() == (mrp * item.quantity) ? 0 : 2)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      // For delivered/cancelled orders, show a subtle message instead of prices
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _getPriceHiddenMessage(order.status),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  // Helper method to determine if prices should be shown based on order status
  bool _shouldShowItemPrices(String status) {
    // Clean the status string - remove any whitespace and convert to lowercase
    final cleanStatus = status.trim().toLowerCase();
    
    if (kDebugMode) print('DEBUG _shouldShowItemPrices: cleanStatus = "$cleanStatus"');
    
    // Check if status contains certain keywords instead of exact match
    if (cleanStatus.contains('delivered')) {
      if (kDebugMode) print('DEBUG: Found "delivered" in status');
      return false;
    }
    
    if (cleanStatus.contains('cancelled') || cleanStatus.contains('canceled')) {
      if (kDebugMode) print('DEBUG: Found "cancelled" or "canceled" in status');
      return false;
    }
    
    // If it's processing, confirmed, preparing, shipped, etc., show prices
    if (cleanStatus.contains('processing') || 
        cleanStatus.contains('confirmed') || 
        cleanStatus.contains('preparing') || 
        cleanStatus.contains('shipped')) {
      if (kDebugMode) print('DEBUG: Found active status in status');
      return true;
    }
    
    // Default to showing prices for unknown statuses
    if (kDebugMode) print('DEBUG: Unknown status, defaulting to show prices');
    return true;
  }


  String _getPriceHiddenMessage(String status) {
    final cleanStatus = status.trim().toLowerCase();
    
    if (cleanStatus.contains('delivered')) {
      return 'Order completed';
    }
    
    if (cleanStatus.contains('cancelled') || cleanStatus.contains('canceled')) {
      return 'Order cancelled';
    }
    
    return 'Price not available';
  }
  // Method to add items to cart again
  void _reorderItems(BuildContext context, WidgetRef ref, Order order) {
    final cartNotifier = ref.read(cartProvider.notifier);
    
    for (final item in order.items) {
      cartNotifier.addItemWithQuantity(item.product, item.quantity);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All items added to cart!'),
        duration: Duration(seconds: 2),
      ),
    );
    
    context.push('/cart');
  }
}