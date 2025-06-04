// lib/presentation/features/orders/order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../core/utils/logger.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/cart_provider.dart';
import '../cart/widgets/persistent_cart_widget.dart';

class OrderDetailScreen extends ConsumerWidget {
  final Order order;

  const OrderDetailScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    logger.log('Building OrderDetailScreen for order: ${order.orderId}');

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
            child: const Text(
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
                      _buildInfoRow('Order Number:', '# ${order.orderId}'),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Ordered Date:', 
                        DateFormat('dd-MMM-yyyy').format(order.orderDate)
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Total Amount:', '₹${order.totalAmount.toStringAsFixed(0)}'),
                      const SizedBox(height: 12),
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

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow('Payment Mode:', order.paymentMethod),
          const SizedBox(height: 12),
          _buildInfoRow('Total Amount:', '₹${order.totalAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          _buildInfoRow('Cart Total:', '₹${cartTotal.toStringAsFixed(0)}'),
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
                      delivery > 0 ? '₹${delivery.toStringAsFixed(0)}' : '₹49',
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
                    '₹${savings.toStringAsFixed(0)}',
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
          
          // Tax Information
          const SizedBox(height: 12),
          // Container(
          //   padding: const EdgeInsets.all(10),
          //   color: Colors.blue[50],
          //   child: Row(
          //     children: [
          //       const Icon(Icons.info_outline, color: Colors.blue, size: 16),
          //       const SizedBox(width: 6),
          //       Expanded(
          //         child: Text(
          //           'Tax of ₹${(order.totalAmount * 0.05).toStringAsFixed(2)} has been included in the total amount.',
          //           style: const TextStyle(
          //             color: Colors.blue,
          //             fontSize: 11,
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildItemsList(Order order) {
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
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: item.product.pcodeImg.isNotEmpty
                    ? Image.network(
                        item.product.pcodeImg,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported_outlined, size: 20),
                      )
                    : const Icon(Icons.image_not_supported_outlined, size: 20),
              ),
              const SizedBox(width: 12),
              
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.product.productName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.product.packageSize} ${item.product.packageUnit}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quantity: ${item.quantity}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Price and Savings
                    if (savings > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            // Text(
                            //   'You Save ₹${savings.toStringAsFixed(0)}',
                            //   style: TextStyle(
                            //     color: Colors.amber[700],
                            //     fontSize: 11,
                            //     fontWeight: FontWeight.w500,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        // Text(
                        //   'You Pay ₹${(sellingPrice * item.quantity).toStringAsFixed(0)}',
                        //   style: TextStyle(
                        //     color: Colors.green[700],
                        //     fontSize: 11,
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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