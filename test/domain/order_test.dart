// test/domain/order_test.dart
//
// Order status classification and order/address rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/domain/entities/customer_address.dart';
import 'package:patelmart/domain/entities/order_status.dart';
import 'package:patelmart/domain/entities/order_summary.dart';
import 'package:patelmart/domain/repositories/i_address_repository.dart';
import 'package:patelmart/domain/repositories/i_order_repository.dart';
import 'package:patelmart/domain/usecases/address/save_address.dart';
import 'package:patelmart/domain/usecases/order/cancel_order.dart';
import 'package:patelmart/utils/order_status_utils.dart';

OrderSummary order({
  String id = 'O1',
  OrderStatus status = OrderStatus.pending,
  DateTime? placedAt,
}) =>
    OrderSummary(
      id: id,
      displayNumber: id,
      placedAt: placedAt ?? DateTime(2026, 7, 1),
      status: status,
      lines: const [],
      totalAmount: 100,
    );

CustomerAddress address({
  String fullName = 'A Person',
  String mobile = '9876543210',
  String line1 = '1 Example Road',
  String pincode = '400001',
}) =>
    CustomerAddress(
      id: 'a1',
      fullName: fullName,
      mobileNumber: mobile,
      line1: line1,
      city: 'Mumbai',
      pincode: pincode,
    );

final class _FakeOrderRepo implements IOrderRepository {
  String? cancelled;

  @override
  Future<Result<List<OrderSummary>>> history({int limit = 50}) async =>
      const Ok([]);

  @override
  Future<Result<OrderSummary>> detail(String orderNumber) async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<void>> cancel({
    required String orderNumber,
    required String reason,
  }) async {
    cancelled = orderNumber;
    return const Ok(null);
  }
}

final class _FakeAddressRepo implements IAddressRepository {
  CustomerAddress? added;
  CustomerAddress? updated;

  @override
  Future<Result<List<CustomerAddress>>> list() async => const Ok([]);

  @override
  Future<Result<void>> add(CustomerAddress a) async {
    added = a;
    return const Ok(null);
  }

  @override
  Future<Result<void>> update(CustomerAddress a) async {
    updated = a;
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String addressId) async => const Ok(null);

  @override
  Future<Result<void>> setDefault(String addressId) async => const Ok(null);
}

void main() {
  group('OrderStatus.parse', () {
    test('maps the backend spellings', () {
      expect(OrderStatus.parse('Pending'), OrderStatus.pending);
      expect(OrderStatus.parse('Order Confirmed'), OrderStatus.pending);
      expect(OrderStatus.parse('Processing'), OrderStatus.processing);
      expect(OrderStatus.parse('Packaging'), OrderStatus.packaging);
      expect(OrderStatus.parse('Out for Delivery'), OrderStatus.outForDelivery);
      expect(OrderStatus.parse('Delivered'), OrderStatus.delivered);
      expect(OrderStatus.parse('Cancelled'), OrderStatus.cancelled);
    });

    test('maps the snake_case admin statuses', () {
      // The admin panel's vocabulary is stored verbatim on the order, so the
      // underscored spellings have to classify the same as the free-text ones.
      expect(OrderStatus.parse('placed'), OrderStatus.pending);
      expect(OrderStatus.parse('accepted'), OrderStatus.accepted);
      expect(OrderStatus.parse('accepted_by_store'), OrderStatus.acceptedByStore);
      expect(OrderStatus.parse('in_packaging'), OrderStatus.packaging);
      expect(OrderStatus.parse('out_for_delivery'), OrderStatus.outForDelivery);
      expect(
        OrderStatus.parse('payment_processing'),
        OrderStatus.paymentProcessing,
      );
      expect(OrderStatus.parse('cancelled'), OrderStatus.cancelled);
    });

    test('longer statuses win over the shorter ones they contain', () {
      // 'accepted_by_store' contains 'accepted', and 'payment_processing'
      // contains 'processing'; matching the shorter value first would collapse
      // three distinct states into two.
      expect(OrderStatus.parse('accepted_by_store'), isNot(OrderStatus.accepted));
      expect(
        OrderStatus.parse('payment_processing'),
        isNot(OrderStatus.processing),
      );
    });

    test('handles the "proocessing" misspelling', () {
      // Four of the six OrderStatusUtils chains handled this typo and two did
      // not, so the same status classified differently depending on which
      // helper was called. Handled once now.
      expect(OrderStatus.parse('Proocessing'), OrderStatus.processing);
    });

    test('"out for delivery" is not misread as "delivered"', () {
      // 'out for delivery' contains 'delivery' but must not match 'delivered'
      // — an order still with the rider would otherwise show as complete and
      // lose its cancel and track affordances.
      expect(OrderStatus.parse('Out For Delivery'), OrderStatus.outForDelivery);
      expect(OrderStatus.parse('Out For Delivery').isInProgress, isTrue);
    });

    test('is case and whitespace insensitive', () {
      expect(OrderStatus.parse('  DELIVERED  '), OrderStatus.delivered);
    });

    test('an unrecognised status is displayed verbatim, not replaced', () {
      // The backend adds statuses without a client release, so a new one must
      // reach the user rather than being flattened to a generic label.
      expect(OrderStatusUtils.normalizeStatus('Awaiting Pickup'),
          'Awaiting Pickup');
      expect(OrderStatusUtils.getStatusDescription('Awaiting Pickup'),
          contains('Awaiting Pickup'));
    });

    test('a recognised status uses its canonical label', () {
      expect(OrderStatusUtils.normalizeStatus('Order Confirmed'), 'Pending');
      expect(OrderStatusUtils.normalizeStatus('Proocessing'), 'Processing');
    });

    test('unrecognised and empty values become unknown', () {
      expect(OrderStatus.parse('banana'), OrderStatus.unknown);
      expect(OrderStatus.parse(''), OrderStatus.unknown);
      expect(OrderStatus.parse(null), OrderStatus.unknown);
    });
  });

  group('OrderStatus rules', () {
    test('in-progress excludes terminal states', () {
      expect(OrderStatus.pending.isInProgress, isTrue);
      expect(OrderStatus.outForDelivery.isInProgress, isTrue);
      expect(OrderStatus.delivered.isInProgress, isFalse);
      expect(OrderStatus.cancelled.isInProgress, isFalse);
      expect(OrderStatus.delivered.isCompleted, isTrue);
    });

    test('cancellation stops once packing begins', () {
      expect(OrderStatus.pending.canCancel, isTrue);
      expect(OrderStatus.processing.canCancel, isTrue);
      expect(OrderStatus.packaging.canCancel, isFalse);
      expect(OrderStatus.outForDelivery.canCancel, isFalse);
      expect(OrderStatus.delivered.canCancel, isFalse);
    });

    test('everything except a cancelled order can be reordered', () {
      expect(OrderStatus.delivered.canReorder, isTrue);
      expect(OrderStatus.cancelled.canReorder, isFalse);
    });

    test('every status has a label and description', () {
      for (final status in OrderStatus.values) {
        expect(status.label, isNotEmpty, reason: '$status');
        expect(status.description, isNotEmpty, reason: '$status');
        expect(OrderStatusAppearance(status).colorName, isNotEmpty);
      }
    });
  });

  group('OrderSummary', () {
    test('savings never go negative when the total exceeds MRP', () {
      final o = OrderSummary(
        id: 'O',
        displayNumber: 'O',
        placedAt: DateTime(2026),
        status: OrderStatus.delivered,
        lines: const [],
        totalAmount: 120,
        totalAtMrp: 100,
      );
      expect(o.savings, 0);
    });

    test('computes savings', () {
      final o = OrderSummary(
        id: 'O',
        displayNumber: 'O',
        placedAt: DateTime(2026),
        status: OrderStatus.delivered,
        lines: const [],
        totalAmount: 80,
        totalAtMrp: 100,
      );
      expect(o.savings, 20);
    });

    test('newestFirst sorts descending by placement time', () {
      final list = [
        order(id: 'old', placedAt: DateTime(2026, 1, 1)),
        order(id: 'new', placedAt: DateTime(2026, 7, 1)),
        order(id: 'mid', placedAt: DateTime(2026, 4, 1)),
      ].newestFirst;

      expect(list.map((o) => o.id), ['new', 'mid', 'old']);
    });

    test('inProgress filters terminal orders out', () {
      final list = [
        order(id: 'a', status: OrderStatus.pending),
        order(id: 'b', status: OrderStatus.delivered),
      ].inProgress;

      expect(list.map((o) => o.id), ['a']);
    });
  });

  group('CancelOrder', () {
    late _FakeOrderRepo repo;
    setUp(() => repo = _FakeOrderRepo());

    test('cancels a pending order', () async {
      final result = await CancelOrder(repo)(
        CancelOrderParams(order: order(), reason: 'Changed my mind'),
      );

      expect(result.isOk, isTrue);
      expect(repo.cancelled, 'O1');
    });

    test('refuses once the order is out for delivery', () async {
      final result = await CancelOrder(repo)(
        CancelOrderParams(
          order: order(status: OrderStatus.outForDelivery),
          reason: 'Changed my mind',
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.cancelled, isNull);
    });

    test('requires a reason', () async {
      final result = await CancelOrder(repo)(
        CancelOrderParams(order: order(), reason: '   '),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.cancelled, isNull);
    });
  });

  group('SaveAddress', () {
    late _FakeAddressRepo repo;
    setUp(() => repo = _FakeAddressRepo());

    test('adds a valid new address', () async {
      final result = await SaveAddress(repo)(
        SaveAddressParams(address: address(), isNew: true),
      );

      expect(result.isOk, isTrue);
      expect(repo.added, isNotNull);
      expect(repo.updated, isNull);
    });

    test('updates rather than adds when editing', () async {
      await SaveAddress(repo)(
        SaveAddressParams(address: address(), isNew: false),
      );

      expect(repo.updated, isNotNull);
      expect(repo.added, isNull);
    });

    test('reports every invalid field at once', () async {
      final result = await SaveAddress(repo)(
        SaveAddressParams(
          address: address(fullName: '', mobile: '123', pincode: '99'),
          isNew: true,
        ),
      );

      final failure = result.failureOrNull as ValidationFailure;
      expect(failure.fieldErrors.keys,
          containsAll(['fullName', 'mobileNumber', 'pincode']));
      expect(repo.added, isNull);
    });

    test('rejects a bad pincode using the shared Pincode rule', () async {
      final result = await SaveAddress(repo)(
        SaveAddressParams(address: address(pincode: '040001'), isNew: true),
      );

      expect((result.failureOrNull as ValidationFailure).fieldErrors,
          contains('pincode'));
    });
  });

  group('CustomerAddress', () {
    test('isDeliverable requires the essential fields', () {
      expect(address().isDeliverable, isTrue);
      expect(address(fullName: '  ').isDeliverable, isFalse);
      expect(address(line1: '').isDeliverable, isFalse);
    });

    test('singleLine skips empty parts', () {
      expect(address().singleLine, '1 Example Road, Mumbai, 400001');
    });
  });
}
