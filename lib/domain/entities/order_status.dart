// lib/domain/entities/order_status.dart
//
// Order status, parsed once.
//
// `Order.status` is a raw String from the backend. OrderStatusUtils then
// substring-matched it in SIX separate if/else chains — getStatusColor,
// getStatusIcon, getStatusDescription, canCancelOrder, isOrderInProgress,
// isOrderCompleted — each re-deriving the same classification.
//
// Four of those chains also carry `contains('proocessing')`, a workaround for a
// misspelled backend value. Two of them do not. Any status matching only the
// typo is therefore classified inconsistently depending on which helper is
// asked, and a seventh chain added tomorrow would forget it again.
//
// Parsing happens once, here.

import 'package:meta/meta.dart';

/// Where an order is in its lifecycle.
enum OrderStatus {
  /// Placed, awaiting acceptance. The backend calls this "Order Confirmed"; the
  /// UI has always displayed it as "Pending".
  pending,

  /// Accepted and being prepared.
  processing,

  /// Being packed.
  packaging,

  /// With the delivery rider.
  outForDelivery,

  /// Completed.
  delivered,

  /// Cancelled by customer or store.
  cancelled,

  /// The backend sent something we do not recognise.
  ///
  /// Explicit rather than silently folded into a default branch, so an
  /// unexpected value is visible instead of rendering as grey "info".
  unknown;

  /// Classifies a raw backend status.
  ///
  /// Substring matching is kept because the backend sends free text, but it now
  /// happens in exactly one place. The `proocessing` misspelling is handled here
  /// once, for every consumer.
  static OrderStatus parse(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return OrderStatus.unknown;

    // Order matters: 'out for delivery' must be tested before 'delivered',
    // since the former contains the latter as a substring.
    if (value.contains('cancel')) return OrderStatus.cancelled;
    if (value.contains('out for delivery') ||
        value.contains('dispatch') ||
        value.contains('shipped')) {
      return OrderStatus.outForDelivery;
    }
    if (value.contains('delivered')) return OrderStatus.delivered;
    if (value.contains('packaging') || value.contains('packing')) {
      return OrderStatus.packaging;
    }
    if (value.contains('processing') || value.contains('proocessing')) {
      return OrderStatus.processing;
    }
    if (value.contains('pending') || value.contains('confirmed')) {
      return OrderStatus.pending;
    }
    return OrderStatus.unknown;
  }

  /// Label shown to the user.
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.processing => 'Processing',
        OrderStatus.packaging => 'Packaging',
        OrderStatus.outForDelivery => 'Out for delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.unknown => 'Order placed',
      };

  /// Sentence explaining the state.
  String get description => switch (this) {
        OrderStatus.pending => 'Your order is pending confirmation',
        OrderStatus.processing => 'Your order is being processed and prepared',
        OrderStatus.packaging => 'Your order is being packaged for delivery',
        OrderStatus.outForDelivery => 'Your order is out for delivery',
        OrderStatus.delivered => 'Your order has been delivered successfully',
        OrderStatus.cancelled => 'Your order has been cancelled',
        OrderStatus.unknown => 'Your order has been placed',
      };

  /// Whether the order is still moving.
  bool get isInProgress =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;

  /// Whether the order has reached a terminal state.
  bool get isCompleted => !isInProgress;

  /// Whether the customer may still cancel.
  ///
  /// Once packing starts the order is physically committed.
  bool get canCancel =>
      this == OrderStatus.pending || this == OrderStatus.processing;

  /// Whether the order's contents can be re-added to a cart.
  bool get canReorder => this != OrderStatus.cancelled;

  /// Whether tracking is meaningful.
  bool get canTrack => isInProgress;
}

/// Presentation hints for a status.
///
/// Colours and icons are UI decisions, so they stay out of the entity — but the
/// mapping is exhaustive over the enum, which is what stopped it drifting
/// between the three chains that previously each defined it.
@immutable
final class OrderStatusAppearance {
  final OrderStatus status;

  const OrderStatusAppearance(this.status);

  /// Semantic colour name. The widget layer maps this to a real Color.
  String get colorName => switch (status) {
        OrderStatus.pending => 'orange',
        OrderStatus.processing => 'blue',
        OrderStatus.packaging => 'purple',
        OrderStatus.outForDelivery => 'amber',
        OrderStatus.delivered => 'green',
        OrderStatus.cancelled => 'red',
        OrderStatus.unknown => 'grey',
      };
}
