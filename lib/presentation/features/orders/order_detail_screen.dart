// lib/presentation/features/orders/order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../core/utils/logger.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/cart_provider.dart';
import '../cart/widgets/persistent_cart_widget.dart'; // Import the persistent cart widget


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
      body: Stack(
        children: [
          // Main content in a scrollable view
          SingleChildScrollView(
            // Add bottom padding to ensure content isn't hidden behind the cart widget
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Share Order Button
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.share,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => _shareOrder(context, order),
                      ),
                      const Text(
                        'Share Order',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Order Details Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow('Order Number:', '# ${order.orderId}'),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'Ordered Date:', 
                        DateFormat('dd-MMM-yyyy').format(order.orderDate)
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Total Amount:', '₹${order.totalAmount.toStringAsFixed(0)}'),
                      const SizedBox(height: 16),
                      _buildInfoRow('Payment Mode:', order.paymentMethod),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Delivery Address
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Delivery Address:'),
                      const SizedBox(height: 8),
                      if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                        Text(
                          order.deliveryAddress!,
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        )
                      else
                        const Text(
                          'No delivery address provided',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Action Buttons (Download Invoice & Reorder)
                Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      // Download Invoice button
                      Expanded(
                        child: InkWell(
                          onTap: () => _downloadInvoice(context, ref, order),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey, width: 0.5),
                              ),
                            ),
                            child: const Text(
                              'DOWNLOAD INVOICE',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Reorder button
                      Expanded(
                        child: InkWell(
                          onTap: () => _reorderItems(context, ref, order),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: Text(
                              'REORDER',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Payment Details Expandable Section
                _buildExpandableSection(
                  title: 'Payment Details',
                  initiallyExpanded: false,
                  children: [
                    _buildPaymentDetails(order),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Shipment Details Expandable Section
                _buildExpandableSection(
                  title: 'Shipment 1 (${order.items.length} Items)',
                  trailing: _buildStatusChip('Delivered'),
                  initiallyExpanded: true,
                  children: [
                    _buildShipmentDetails(order),
                    const Divider(height: 1),
                    _buildItemsList(order),
                  ],
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
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 16,
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
            fontSize: 16,
          ),
        ),
        trailing: trailing,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: initiallyExpanded,
        children: children,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(Order order) {
    // Calculate amount breakdown
    final delivery = order.deliveryAmount ?? 0.0;
    final cartTotal = order.totalAmount - delivery;
    final savings = order.savings;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow('Payment Mode:', order.paymentMethod),
          const SizedBox(height: 16),
          _buildInfoRow('Total Amount:', '₹${order.totalAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 16),
          _buildInfoRow('Cart Total:', '₹${cartTotal.toStringAsFixed(0)}'),
          const SizedBox(height: 16),
          
          // Delivery Charges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  'Delivery Charges:',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (delivery == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Special Offer Applied',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      delivery > 0 ? '₹${delivery.toStringAsFixed(0)}' : '₹49',
                      style: TextStyle(
                        color: delivery > 0 ? Colors.black : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: delivery > 0 ? TextDecoration.none : TextDecoration.lineThrough,
                      ),
                    ),
                    if (delivery == 0)
                      const Text(
                        ' ₹0',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          if (savings > 0) ...[
            const SizedBox(height: 16),
            // Total Savings Row
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.amber[50],
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Total Savings',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${savings.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Tax Information
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tax of ₹${(order.totalAmount * 0.05).toStringAsFixed(2)} has been included in the total amount.',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 13,
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

  Widget _buildShipmentDetails(Order order) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildInfoRow('Shipment Id:', '${order.orderId}-1'),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Delivery Date:', 
            DateFormat('dd-MMM-yyyy').format(order.orderDate)
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Time Slot:', order.deliverySlot),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Total Amount:', 
            '₹${order.totalAmount.toStringAsFixed(0)}\n(excluding of delivery charges)'
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Item Details:', '${order.items.length} item(s)'),
        ],
      ),
    );
  }

  Widget _buildItemsList(Order order) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: order.items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = order.items[index];
        // Calculate individual item savings
        final mrp = item.product.productMrp;
        final sellingPrice = item.product.ourPrice;
        final savings = (mrp - sellingPrice) * item.quantity;
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: item.product.pcodeImg.isNotEmpty
                    ? Image.network(
                        item.product.pcodeImg,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported_outlined),
                      )
                    : const Icon(Icons.image_not_supported_outlined),
              ),
              const SizedBox(width: 12),
              
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.product.productName} : ${item.product.packageSize} ${item.product.packageUnit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.product.packageSize} ${item.product.packageUnit}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Quantity ${item.quantity}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Price and Savings
                    if (savings > 0)
                      Row(
                        children: [
                          Text(
                            'You Save ₹${savings.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        Text(
                          'You Pay ₹${(sellingPrice * item.quantity).toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  // Method to share order details
  void _shareOrder(BuildContext context, Order order) {
    Share.share(
      'Order #${order.orderId} placed on ${DateFormat('dd-MMM-yyyy').format(order.orderDate)}\n'
      'Total Amount: ₹${order.totalAmount.toStringAsFixed(0)}\n'
      'Status: ${order.status}\n'
      'Items: ${order.items.length}\n'
      'From PatelMart',
      subject: 'My PatelMart Order #${order.orderId}',
    );
  }

  // Method to download invoice
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
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
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
                          pw.Text('MRP Total: '),
                          pw.SizedBox(width: 50),
                          pw.Text('₹${order.totalMrp.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Our Price: '),
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
                          pw.Text('₹${order.deliveryAmount?.toStringAsFixed(2) ?? "0.00"}'),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('You Saved: '),
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

  // Method to add items to cart again
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
    Navigator.pushNamed(context, '/cart');
  }
}