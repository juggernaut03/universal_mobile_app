// lib/domain/repositories/i_order_repository.dart

import '../../core/result/result.dart';
import '../entities/order_summary.dart';

/// Order history and post-purchase actions.
abstract interface class IOrderRepository {
  /// The customer's past orders, newest first.
  Future<Result<List<OrderSummary>>> history({int limit = 50});

  /// One order in full.
  ///
  /// Yields `Err(NotFoundFailure)` when the order does not exist — the previous
  /// `Future<Order?>` could not distinguish that from a network failure.
  Future<Result<OrderSummary>> detail(String orderNumber);

  /// Cancels an order.
  ///
  /// Returned failures carry why it was refused; the previous `Future<bool>`
  /// discarded that, so the UI showed one generic message whether the order was
  /// already dispatched or the request simply failed.
  Future<Result<void>> cancel({
    required String orderNumber,
    required String reason,
  });
}
