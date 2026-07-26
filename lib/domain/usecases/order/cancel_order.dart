// lib/domain/usecases/order/cancel_order.dart

import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/order_summary.dart';
import '../../repositories/i_order_repository.dart';

final class CancelOrderParams extends UseCaseParams {
  final OrderSummary order;
  final String reason;

  const CancelOrderParams({required this.order, required this.reason});

  @override
  List<Object?> get props => [order.id, reason];
}

/// Cancels an order, refusing when its status no longer permits it.
///
/// The rule lives here rather than in the screen, so a cancel button rendered
/// in the wrong state cannot send a request that the backend will reject.
final class CancelOrder extends UseCase<void, CancelOrderParams> {
  final IOrderRepository _repository;

  const CancelOrder(this._repository);

  @override
  Future<Result<void>> call(CancelOrderParams params) async {
    if (!params.order.canCancel) {
      return Err(ValidationFailure(
        'This order can no longer be cancelled — it is already '
        '${params.order.status.label.toLowerCase()}.',
      ));
    }
    if (params.reason.trim().isEmpty) {
      return const Err(ValidationFailure('Please tell us why you are cancelling.'));
    }
    return _repository.cancel(
      orderNumber: params.order.displayNumber,
      reason: params.reason.trim(),
    );
  }
}
