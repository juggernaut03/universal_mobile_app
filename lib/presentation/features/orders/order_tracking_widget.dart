// lib/presentation/features/orders/order_tracking_widget.dart

import 'package:flutter/material.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';

class OrderTrackingWidget extends StatelessWidget {
  final String orderId;
  final String title;
  final String imageUrl;
  final VoidCallback onViewOrderTap;

  const OrderTrackingWidget({
    Key? key,
    required this.orderId,
    required this.title,
    required this.imageUrl,
    required this.onViewOrderTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Added slightly larger radius
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Order #$orderId •",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onViewOrderTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD814), // Amazon yellow
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          "VIEW ORDER",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider Line
          Divider(color: Colors.grey.shade200, height: 1, thickness: 1),

          // Bottom Timeline Section (now replaced by API Image)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: CachedNetworkImageWidget(
                    imageUrl: imageUrl,
                    height: 50,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
