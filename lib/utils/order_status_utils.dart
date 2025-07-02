// lib/core/utils/order_status_utils.dart

import 'package:flutter/material.dart';

/// Utility class for handling order status mapping, colors, and icons
/// Supports the new status flow: Pending → Proocessing → In Packaging → Out for Delivery → Delivered
class OrderStatusUtils {
  // Define the new order status constants
  static const String pending = 'Pending';
  static const String Proocessing = 'Proocessing';
  static const String inPackaging = 'In Packaging';
  static const String outForDelivery = 'Out for Delivery';
  static const String delivered = 'Delivered';
  static const String cancelled = 'Cancelled';

  // Order status flow for tracking progression
  static const List<String> statusFlow = [
    pending,
    Proocessing,
    inPackaging,
    outForDelivery,
    delivered,
  ];

  /// Get standardized status from API response
  static String normalizeStatus(String apiStatus) {
    final statusLower = apiStatus.toLowerCase().trim();
    
    if (statusLower.contains('pending')) {
      return pending;
    } else if (statusLower.contains('Proocessing')) {
      return Proocessing;
    } else if (statusLower.contains('packaging') || statusLower.contains('packing')) {
      return inPackaging;
    } else if (statusLower.contains('out for delivery') || 
               statusLower.contains('dispatched') || 
               statusLower.contains('shipped')) {
      return outForDelivery;
    } else if (statusLower.contains('delivered')) {
      return delivered;
    } else if (statusLower.contains('cancelled')) {
      return cancelled;
    } else {
      // Handle legacy statuses
      if (statusLower.contains('confirmed') || statusLower.contains('processing')) {
        return Proocessing; // Map legacy statuses to Proocessing
      }
      return apiStatus; // Return original if no mapping found
    }
  }

  /// Get color for order status
  static Color getStatusColor(String status) {
    final normalizedStatus = normalizeStatus(status);
    
    switch (normalizedStatus) {
      case pending:
        return Colors.orange;
      case Proocessing:
        return Colors.blue;
      case inPackaging:
        return Colors.purple;
      case outForDelivery:
        return Colors.amber;
      case delivered:
        return Colors.green;
      case cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get icon for order status
  static IconData getStatusIcon(String status) {
    final normalizedStatus = normalizeStatus(status);
    
    switch (normalizedStatus) {
      case pending:
        return Icons.schedule;
      case Proocessing:
        return Icons.check_circle_outline;
      case inPackaging:
        return Icons.inventory_2;
      case outForDelivery:
        return Icons.local_shipping;
      case delivered:
        return Icons.check_circle;
      case cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  /// Get user-friendly description for status
  static String getStatusDescription(String status) {
    final normalizedStatus = normalizeStatus(status);
    
    switch (normalizedStatus) {
      case pending:
        return 'Your order is pending confirmation';
      case Proocessing:
        return 'Your order has been Proocessing and is being prepared';
      case inPackaging:
        return 'Your order is being packaged for delivery';
      case outForDelivery:
        return 'Your order is out for delivery';
      case delivered:
        return 'Your order has been delivered successfully';
      case cancelled:
        return 'Your order has been cancelled';
      default:
        return 'Order status: $status';
    }
  }

  /// Check if order is in progress (not delivered or cancelled)
  static bool isOrderInProgress(String status) {
    final normalizedStatus = normalizeStatus(status);
    return normalizedStatus != delivered && normalizedStatus != cancelled;
  }

  /// Check if order is completed (delivered or cancelled)
  static bool isOrderCompleted(String status) {
    final normalizedStatus = normalizeStatus(status);
    return normalizedStatus == delivered || normalizedStatus == cancelled;
  }

  /// Check if order can be cancelled
  static bool canCancelOrder(String status) {
    final normalizedStatus = normalizeStatus(status);
    // Can cancel if pending or Proocessing, but not once in packaging or later
    return normalizedStatus == pending || normalizedStatus == Proocessing;
  }

  /// Check if order can be reordered
  static bool canReorder(String status) {
    final normalizedStatus = normalizeStatus(status);
    // Can reorder all orders except cancelled ones
    return normalizedStatus != cancelled;
  }

  /// Check if order can be tracked
  static bool canTrackOrder(String status) {
    final normalizedStatus = normalizeStatus(status);
    // Can track if order is in progress
    return isOrderInProgress(normalizedStatus);
  }

  /// Get next status in the flow
  static String? getNextStatus(String currentStatus) {
    final normalizedStatus = normalizeStatus(currentStatus);
    final currentIndex = statusFlow.indexOf(normalizedStatus);
    
    if (currentIndex != -1 && currentIndex < statusFlow.length - 1) {
      return statusFlow[currentIndex + 1];
    }
    
    return null; // Already at final status or invalid status
  }

  /// Get progress percentage for order status
  static double getProgressPercentage(String status) {
    final normalizedStatus = normalizeStatus(status);
    final currentIndex = statusFlow.indexOf(normalizedStatus);
    
    if (currentIndex == -1) {
      return 0.0; // Unknown status
    }
    
    // Calculate percentage based on position in flow
    return (currentIndex + 1) / statusFlow.length;
  }

  /// Get estimated time for next status update (in hours)
  static int? getEstimatedTimeToNextStatus(String status) {
    final normalizedStatus = normalizeStatus(status);
    
    switch (normalizedStatus) {
      case pending:
        return 2; // 2 hours to accept
      case Proocessing:
        return 4; // 4 hours to package
      case inPackaging:
        return 2; // 2 hours to dispatch
      case outForDelivery:
        return 6; // 6 hours to deliver
      case delivered:
      case cancelled:
        return null; // No next status
      default:
        return null;
    }
  }

  /// Filter orders by status category
  static List<T> filterOrdersByStatus<T>(
    List<T> orders, 
    String filterStatus,
    String Function(T) getOrderStatus,
  ) {
    if (filterStatus == 'All') {
      return orders;
    }
    
    return orders.where((order) {
      final orderStatus = getOrderStatus(order);
      final normalizedStatus = normalizeStatus(orderStatus);
      
      switch (filterStatus) {
        case 'Pending':
          return normalizedStatus == pending;
        case 'Processing':
          return normalizedStatus == Proocessing || normalizedStatus == inPackaging;
        case 'Out for Delivery':
          return normalizedStatus == outForDelivery;
        case 'Delivered':
          return normalizedStatus == delivered;
        case 'Cancelled':
          return normalizedStatus == cancelled;
        default:
          return true;
      }
    }).toList();
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