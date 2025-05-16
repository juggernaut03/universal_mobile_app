// lib/presentation/features/orders/order_navigation_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/order_model.dart';
import 'order_detail_screen.dart';

/// This class handles navigation to the order detail screen
class OrderNavigationHandler {
  /// Navigate to order detail screen
  static void navigateToOrderDetail(BuildContext context, WidgetRef ref, Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: order),
      ),
    );
  }
}