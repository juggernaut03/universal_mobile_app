// lib/presentation/features/checkout/steps/order_success_dialog.dart
//
// Order confirmation dialog, split out of payment_step.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/order_providers.dart';
import '../checkout_models.dart';

/// Shows the order-placed confirmation.
///
/// Was a 193-line method on _PaymentStepState. It only reads three providers
/// and the checkout data, so it becomes a free function taking them — no State
/// involvement, and payment_step keeps only the call.
void showOrderSuccessDialog(
  BuildContext context,
  WidgetRef ref,
  CheckoutData checkoutData,
  String orderId,
) {
  final paymentResult = ref.read(paymentResultProvider);
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 32,
            ),
            SizedBox(width: 12),
            Text(
              'Order Placed Successfully!',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your order has been successfully placed and is being processed.',
              style: AppTextStyles.bodyMedium,
            ),
            SizedBox(height: 12),
            
            // Order ID
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: $orderId',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  
                  // Payment information
                  if (paymentResult != null && paymentResult.success) ...[
                    SizedBox(height: 8),
                    Text(
                      'Payment ID: ${paymentResult.paymentId}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'Payment Status: Confirmed',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (checkoutData.paymentMethod?.toLowerCase().contains('cod') == true ||
                            checkoutData.paymentMethod?.toLowerCase().contains('pod') == true) ...[
                    SizedBox(height: 8),
                    Text(
                      'Payment: Cash on Delivery',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  
                  // Database status confirmation
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.green[700],
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Order Status: Confirmed',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            Text(
              'You will receive a confirmation message shortly.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            
            // Show delivery information
            if (checkoutData.deliveryMethod == DeliveryMethod.homeDelivery) ...[
              SizedBox(height: 12),
              Text(
                'Delivery Details:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Date: ${checkoutData.deliveryDate != null ? formatOrderDate(checkoutData.deliveryDate!) : "Tomorrow"}',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                'Time: ${checkoutData.deliveryTimeSlot ?? "9:00 AM - 10:00 PM"}',
                style: AppTextStyles.bodySmall,
              ),
            ] else ...[
              SizedBox(height: 12),
              Text(
                'Pickup Details:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ready for pickup within 2-4 hours',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                'Store will call when ready',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              context.go('/'); // Navigate to home
            },
            child: Text(
              'Continue Shopping',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              context.go('/'); // Navigate to home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('View Orders'),
          ),
        ],
      );
    },
  );
}

// Helper method to format date for display

/// Formats a delivery date as Today / Tomorrow / "Jan 15, 2025".
String formatOrderDate(DateTime date) {
  final now = DateTime.now();
  
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today';
  }
  
  if (date.year == now.year && date.month == now.month && date.day == now.day + 1) {
    return 'Tomorrow';
  }
  
  // Format as "Jan 15, 2025"
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

// Enhanced error display method
// Enhanced order success dialog

