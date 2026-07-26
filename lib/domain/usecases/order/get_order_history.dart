// lib/domain/usecases/order/get_order_history.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/order_summary.dart';
import '../../repositories/i_order_repository.dart';

final class GetOrderHistoryParams extends UseCaseParams {
  final int limit;

  const GetOrderHistoryParams({this.limit = 50});

  @override
  List<Object?> get props => [limit];
}

/// The customer's orders, newest first.
///
/// Sorting used to be re-applied in each screen — reorder_provider had a
/// comment shouting "WITH LATEST DATE FIRST SORTING" precisely because it was
/// easy to forget.
final class GetOrderHistory
    extends UseCase<List<OrderSummary>, GetOrderHistoryParams> {
  final IOrderRepository _repository;

  const GetOrderHistory(this._repository);

  @override
  Future<Result<List<OrderSummary>>> call(GetOrderHistoryParams params) async {
    final result = await _repository.history(limit: params.limit);
    return result.map((orders) => orders.newestFirst);
  }
}
