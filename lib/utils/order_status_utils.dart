// lib/core/utils/order_status_utils.dart

import 'package:flutter/material.dart';

/// Utility class for handling order status mapping, colors, and icons
/// Works with dynamic statuses from API without hard-coded constants
class OrderStatusUtils {

  /// Get normalized status from API response
  static String normalizeStatus(String apiStatus) {
    final trimmedStatus = apiStatus.trim();

    // Special case: Show "Pending" for "Order Confirmed" status
    if (trimmedStatus.toLowerCase() == 'order confirmed') {
      return 'Pending';
    }

    // For all other statuses, return as-is from API
    return trimmedStatus;
  }

  /// Get color for order status
  static Color getStatusColor(String status) {
    final normalizedStatus = normalizeStatus(status).toLowerCase();

    // Use pattern matching to determine colors based on status content
    if (normalizedStatus.contains('pending')) {
      return Colors.orange;
    } else if (normalizedStatus.contains('processing') || normalizedStatus.contains('proocessing')) {
      return Colors.blue;
    } else if (normalizedStatus.contains('packaging') || normalizedStatus.contains('packing')) {
      return Colors.purple;
    } else if (normalizedStatus.contains('out for delivery') || normalizedStatus.contains('dispatched') || normalizedStatus.contains('shipped')) {
      return Colors.amber;
    } else if (normalizedStatus.contains('delivered')) {
      return Colors.green;
    } else if (normalizedStatus.contains('cancelled')) {
      return Colors.red;
    } else if (normalizedStatus.contains('confirmed')) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  /// Get icon for order status
  static IconData getStatusIcon(String status) {
    final normalizedStatus = normalizeStatus(status).toLowerCase();

    // Use pattern matching to determine icons based on status content
    if (normalizedStatus.contains('pending')) {
      return Icons.schedule;
    } else if (normalizedStatus.contains('processing') || normalizedStatus.contains('proocessing')) {
      return Icons.check_circle_outline;
    } else if (normalizedStatus.contains('packaging') || normalizedStatus.contains('packing')) {
      return Icons.inventory_2;
    } else if (normalizedStatus.contains('out for delivery') || normalizedStatus.contains('dispatched') || normalizedStatus.contains('shipped')) {
      return Icons.local_shipping;
    } else if (normalizedStatus.contains('delivered')) {
      return Icons.check_circle;
    } else if (normalizedStatus.contains('cancelled')) {
      return Icons.cancel;
    } else if (normalizedStatus.contains('confirmed')) {
      return Icons.check_circle_outline;
    } else {
      return Icons.info;
    }
  }

  /// Get user-friendly description for status
  static String getStatusDescription(String status) {
    final normalizedStatus = normalizeStatus(status).toLowerCase();

    // Use pattern matching to determine descriptions based on status content
    if (normalizedStatus.contains('pending')) {
      return 'Your order is pending confirmation';
    } else if (normalizedStatus.contains('processing') || normalizedStatus.contains('proocessing')) {
      return 'Your order is being processed and prepared';
    } else if (normalizedStatus.contains('packaging') || normalizedStatus.contains('packing')) {
      return 'Your order is being packaged for delivery';
    } else if (normalizedStatus.contains('out for delivery') || normalizedStatus.contains('dispatched') || normalizedStatus.contains('shipped')) {
      return 'Your order is out for delivery';
    } else if (normalizedStatus.contains('delivered')) {
      return 'Your order has been delivered successfully';
    } else if (normalizedStatus.contains('cancelled')) {
      return 'Your order has been cancelled';
    } else if (normalizedStatus.contains('confirmed')) {
      return 'Your order has been confirmed and is being processed';
    } else {
      return 'Order status: $status';
    }
  }

  /// Check if order is in progress (not delivered or cancelled)
  static bool isOrderInProgress(String status) {
    final normalizedStatus = normalizeStatus(status).toLowerCase();
    return !normalizedStatus.contains('delivered') && !normalizedStatus.contains('cancelled');
  }

  /// Check if order is completed (delivered or cancelled)
  static bool isOrderCompleted(String status) {
    final normalizedStatus = normalizeStatus(status).toLowerCase();
    return normalizedStatus.contains('delivered') || normalizedStatus.contains('cancelled');
  }

  /// Check if order can be cancelled
  static bool canCancelOrder(String status) {
    final normalizedStatus = normalizeStatus(status).toLowerCase();
    // Can cancel if pending or processing, but not once in packaging, out for delivery, or delivered
    return normalizedStatus.contains('pending') ||
           (normalizedStatus.contains('processing') || normalizedStatus.contains('proocessing')) ||
           normalizedStatus.contains('confirmed');
  }

  /// Check if order can be reordered
  static bool canReorder(String status) {
    final normalizedStatus = normalizeStatus(status).toLowerCase();
    // Can reorder all orders except cancelled ones
    return !normalizedStatus.contains('cancelled');
  }

  /// Check if order can be tracked
  static bool canTrackOrder(String status) {
    final normalizedStatus = normalizeStatus(status);
    // Can track if order is in progress
    return isOrderInProgress(normalizedStatus);
  }

  /// Get next status in the flow (deprecated - no fixed flow with dynamic statuses)
  static String? getNextStatus(String currentStatus) {
    // Since we removed fixed status flow, this method now returns null
    // The next status is determined by the API dynamically
    return null;
  }



  /// Get status badge widget
  static Widget getStatusBadge(String status, {double? fontSize}) {
    final normalizedStatus = normalizeStatus(status);
    final color = getStatusColor(status);
    final icon = getStatusIcon(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: fontSize ?? 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            normalizedStatus,
            style: TextStyle(
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}