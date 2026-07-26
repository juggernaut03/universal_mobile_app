// lib/domain/entities/order_summary.dart

import 'package:meta/meta.dart';

import 'cart.dart';
import 'order_status.dart';

/// A placed order.
///
/// Named OrderSummary rather than Order to avoid colliding with the existing
/// data-layer `Order` DTO while both exist.
@immutable
final class OrderSummary {
  /// Internal order id.
  final String id;

  /// Human-facing order number, when the backend assigned one.
  ///
  /// The DTO carried `actualOrderId` as an `int?` alongside `orderId`, and a
  /// `displayOrderId` getter picked between them. That choice happens once, at
  /// the boundary.
  final String displayNumber;

  /// When the order was placed. The DTO had both `orderDate` and a nullable
  /// `orderDateTime`, with a `sortableDateTime` getter to pick — collapsed to
  /// one authoritative value.
  final DateTime placedAt;

  final OrderStatus status;

  /// What was ordered.
  final List<CartLine> lines;

  final double totalAmount;
  final double totalAtMrp;
  final double deliveryCharge;

  /// Refunded to the customer, when a refund was issued.
  final double? refundAmount;

  final String deliveryMethod;
  final String deliverySlot;
  final String paymentMethod;
  final String? deliveryAddress;

  const OrderSummary({
    required this.id,
    required this.displayNumber,
    required this.placedAt,
    required this.status,
    required this.lines,
    required this.totalAmount,
    this.totalAtMrp = 0,
    this.deliveryCharge = 0,
    this.refundAmount,
    this.deliveryMethod = '',
    this.deliverySlot = '',
    this.paymentMethod = '',
    this.deliveryAddress,
  });

  /// Units ordered across all lines.
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  /// Distinct products ordered.
  int get lineCount => lines.length;

  /// Saved against MRP. Never negative.
  double get savings {
    final diff = totalAtMrp - totalAmount;
    return diff > 0 ? diff : 0;
  }

  /// Whether a refund was issued.
  bool get wasRefunded => (refundAmount ?? 0) > 0;

  /// Placed within the last 24 hours.
  bool isRecentAt(DateTime now) =>
      now.difference(placedAt) < const Duration(days: 1);

  // Status questions delegate to the enum, so there is one definition of each.
  bool get canCancel => status.canCancel;
  bool get canReorder => status.canReorder;
  bool get canTrack => status.canTrack;
  bool get isInProgress => status.isInProgress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OrderSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'OrderSummary($displayNumber, ${status.label})';
}

/// Sorting for order lists.
extension OrderSummaryList on List<OrderSummary> {
  /// Newest first — how order history is always displayed.
  List<OrderSummary> get newestFirst {
    final sorted = [...this]..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return List.unmodifiable(sorted);
  }

  /// Orders still moving.
  List<OrderSummary> get inProgress =>
      List.unmodifiable(where((o) => o.isInProgress));
}
