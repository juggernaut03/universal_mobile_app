// lib/utils/order_status_utils.dart
//
// Presentation mapping for order status.
//
// Was six independent if/else chains, each substring-matching the raw backend
// string to re-derive the same classification: getStatusColor, getStatusIcon,
// getStatusDescription, canCancelOrder, isOrderInProgress, isOrderCompleted.
//
// Four of those chains carried `contains('proocessing')` — a workaround for a
// misspelled backend value — and two did not, so the same order classified
// differently depending on which helper was asked.
//
// Classification now happens once in OrderStatus.parse; this file only maps an
// already-classified status to Flutter types. Each switch is exhaustive, so a
// new status forces every mapping to be updated.

import 'package:flutter/material.dart';

import '../domain/entities/order_status.dart';

/// Maps order status to the colours, icons and copy the UI needs.
class OrderStatusUtils {
  const OrderStatusUtils._();

  /// Label shown on status chips.
  ///
  /// An unrecognised status is passed through verbatim rather than replaced
  /// with a generic label. The backend adds statuses without a client release,
  /// and the original implementation deliberately displayed them as-is —
  /// substituting "Order placed" would hide a genuinely new state from the user.
  static String normalizeStatus(String apiStatus) {
    final status = OrderStatus.parse(apiStatus);
    return status == OrderStatus.unknown ? apiStatus.trim() : status.label;
  }

  static Color getStatusColor(String status) =>
      colorFor(OrderStatus.parse(status));

  static IconData getStatusIcon(String status) =>
      iconFor(OrderStatus.parse(status));

  static String getStatusDescription(String status) {
    final parsed = OrderStatus.parse(status);
    // Same reasoning as normalizeStatus: keep the backend's own wording when we
    // do not recognise the state.
    return parsed == OrderStatus.unknown
        ? 'Order status: ${status.trim()}'
        : parsed.description;
  }

  static bool isOrderInProgress(String status) =>
      OrderStatus.parse(status).isInProgress;

  static bool isOrderCompleted(String status) =>
      OrderStatus.parse(status).isCompleted;

  static bool canCancelOrder(String status) =>
      OrderStatus.parse(status).canCancel;

  static bool canReorder(String status) => OrderStatus.parse(status).canReorder;

  static bool canTrackOrder(String status) =>
      OrderStatus.parse(status).canTrack;

  /// Colour for a classified status. Exhaustive — no `default:`.
  static Color colorFor(OrderStatus status) => switch (status) {
        OrderStatus.pending => Colors.orange,
        OrderStatus.processing => Colors.blue,
        OrderStatus.packaging => Colors.purple,
        OrderStatus.outForDelivery => Colors.amber,
        OrderStatus.delivered => Colors.green,
        OrderStatus.cancelled => Colors.red,
        OrderStatus.unknown => Colors.grey,
      };

  /// Icon for a classified status. Exhaustive — no `default:`.
  static IconData iconFor(OrderStatus status) => switch (status) {
        OrderStatus.pending => Icons.schedule,
        OrderStatus.processing => Icons.check_circle_outline,
        OrderStatus.packaging => Icons.inventory_2,
        OrderStatus.outForDelivery => Icons.local_shipping,
        OrderStatus.delivered => Icons.check_circle,
        OrderStatus.cancelled => Icons.cancel,
        OrderStatus.unknown => Icons.info,
      };
}
