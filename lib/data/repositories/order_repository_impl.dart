// lib/data/repositories/order_repository_impl.dart
//
// Implements IOrderRepository over the existing OrderRepository.

import '../../core/error/exceptions.dart';
import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../domain/entities/order_summary.dart';
import '../../domain/repositories/i_order_repository.dart';
import 'order_repository.dart';

final class OrderRepositoryImpl implements IOrderRepository {
  final OrderRepository _delegate;

  OrderRepositoryImpl({required OrderRepository delegate})
      : _delegate = delegate;

  @override
  Future<Result<List<OrderSummary>>> history({int limit = 50}) =>
      guard(() async {
        final orders = await _delegate.getOrderHistory(limit: limit);
        return orders.map((o) => o.toEntity()).toList(growable: false);
      });

  @override
  Future<Result<OrderSummary>> detail(String orderNumber) => guard(() async {
        final order = await _delegate.getOrderDetails(orderNumber);
        // The delegate returns null for both "no such order" and "the call
        // failed"; only the first is knowable here, so it is reported as
        // not-found and a genuine transport error surfaces from guard().
        if (order == null) {
          throw NotFoundException('No order $orderNumber');
        }
        return order.toEntity();
      });

  @override
  Future<Result<void>> cancel({
    required String orderNumber,
    required String reason,
  }) =>
      guard(() async {
        final ok = await _delegate.cancelOrder(orderNumber, reason);
        if (!ok) {
          throw ServerException('Order $orderNumber could not be cancelled');
        }
      });
}
