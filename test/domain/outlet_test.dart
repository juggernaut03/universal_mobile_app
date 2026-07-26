// test/domain/outlet_test.dart
//
// Outlet and Pincode business rules. Pure Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/domain/entities/outlet.dart';
import 'package:patelmart/domain/entities/pincode.dart';

Outlet buildOutlet({
  String storeCode = 'KLK',
  int minOrderAmount = 200,
  bool isEnabled = true,
  Set<FulfilmentMethod> methods = const {FulfilmentMethod.homeDelivery},
  String storeMessage = '',
  GeoPoint? location,
}) =>
    Outlet(
      id: 'id-$storeCode',
      storeCode: storeCode,
      name: 'Store $storeCode',
      address: '1 Example Road',
      minOrderAmount: minOrderAmount,
      isEnabled: isEnabled,
      fulfilmentMethods: methods,
      storeMessage: storeMessage,
      location: location,
    );

void main() {
  group('GeoPoint.tryParse', () {
    test('parses a valid string pair', () {
      // OutletModel carries coordinates as Strings; parsing happens once here.
      expect(
        GeoPoint.tryParse('19.076', '72.877'),
        const GeoPoint(latitude: 19.076, longitude: 72.877),
      );
    });

    test('returns null rather than 0,0 for missing values', () {
      // 0,0 is a real point in the Gulf of Guinea — defaulting to it would
      // silently corrupt any distance calculation.
      expect(GeoPoint.tryParse(null, null), isNull);
      expect(GeoPoint.tryParse('', ''), isNull);
    });

    test('returns null for unparseable values', () {
      expect(GeoPoint.tryParse('not-a-number', '72.877'), isNull);
    });

    test('rejects out-of-range coordinates', () {
      expect(GeoPoint.tryParse('91.0', '0'), isNull);
      expect(GeoPoint.tryParse('0', '181.0'), isNull);
    });

    test('tolerates surrounding whitespace', () {
      expect(GeoPoint.tryParse(' 19.076 ', ' 72.877 '), isNotNull);
    });
  });

  group('canAcceptOrders', () {
    test('accepts when enabled with a fulfilment method', () {
      expect(buildOutlet().canAcceptOrders, isTrue);
    });

    test('refuses when disabled', () {
      expect(buildOutlet(isEnabled: false).canAcceptOrders, isFalse);
    });

    test('refuses when enabled but offering no fulfilment method', () {
      expect(buildOutlet(methods: const {}).canAcceptOrders, isFalse);
    });
  });

  group('minimum order', () {
    test('meets the minimum at exactly the threshold', () {
      expect(buildOutlet(minOrderAmount: 200).meetsMinimumOrder(200), isTrue);
    });

    test('does not meet it below the threshold', () {
      expect(buildOutlet(minOrderAmount: 200).meetsMinimumOrder(199.99), isFalse);
    });

    test('reports the shortfall', () {
      expect(buildOutlet(minOrderAmount: 200).amountBelowMinimum(150), 50);
    });

    test('reports no shortfall once met', () {
      expect(buildOutlet(minOrderAmount: 200).amountBelowMinimum(500), 0);
    });

    test('a zero minimum is always met', () {
      expect(buildOutlet(minOrderAmount: 0).meetsMinimumOrder(0), isTrue);
    });
  });

  group('statusMessage', () {
    test('prefers the operator message when closed', () {
      expect(
        buildOutlet(isEnabled: false, storeMessage: 'Back at 9am').statusMessage,
        'Back at 9am',
      );
    });

    test('falls back to a default when closed with no message', () {
      expect(
        buildOutlet(isEnabled: false).statusMessage,
        contains('temporarily closed'),
      );
    });

    test('names the single available method', () {
      expect(
        buildOutlet(methods: const {FulfilmentMethod.selfPickup}).statusMessage,
        'Only Store Pickup is available',
      );
    });

    test('reports all services when both are offered', () {
      expect(
        buildOutlet(methods: const {
          FulfilmentMethod.homeDelivery,
          FulfilmentMethod.selfPickup,
        }).statusMessage,
        'All services are available',
      );
    });
  });

  group('identity', () {
    test('store code is the identity', () {
      expect(buildOutlet(storeCode: 'KLK'), buildOutlet(storeCode: 'KLK'));
      expect(
        buildOutlet(storeCode: 'KLK', minOrderAmount: 100),
        buildOutlet(storeCode: 'KLK', minOrderAmount: 900),
      );
      expect(buildOutlet(storeCode: 'KLK'), isNot(buildOutlet(storeCode: 'AND')));
    });
  });

  group('Pincode', () {
    test('accepts a valid 6-digit code', () {
      expect(Pincode.tryParse('400001')?.value, '400001');
      expect(Pincode.isValid('400001'), isTrue);
    });

    test('trims whitespace', () {
      expect(Pincode.tryParse('  400001  ')?.value, '400001');
    });

    test('rejects wrong lengths', () {
      expect(Pincode.tryParse('40001'), isNull);
      expect(Pincode.tryParse('4000012'), isNull);
    });

    test('rejects non-numeric input', () {
      expect(Pincode.tryParse('4000A1'), isNull);
    });

    test('rejects a leading zero — no Indian pincode starts with 0', () {
      expect(Pincode.tryParse('040001'), isNull);
    });

    test('rejects null and empty', () {
      expect(Pincode.tryParse(null), isNull);
      expect(Pincode.tryParse(''), isNull);
    });

    test('is a value type', () {
      expect(Pincode.tryParse('400001'), Pincode.tryParse('400001'));
      expect(Pincode.tryParse('400001'), isNot(Pincode.tryParse('400002')));
    });
  });

  group('Serviceability', () {
    test('states the answer as a boolean, not count == 1', () {
      final pincode = Pincode.tryParse('400001')!;

      expect(
        Serviceability(pincode: pincode, isServiceable: true).isServiceable,
        isTrue,
      );
    });

    test('prefers the backend message when unavailable', () {
      final pincode = Pincode.tryParse('400001')!;
      const message = 'Coming to your area soon!';

      expect(
        Serviceability(pincode: pincode, isServiceable: false, message: message)
            .unavailableMessage,
        message,
      );
    });

    test('falls back to a default message naming the pincode', () {
      final pincode = Pincode.tryParse('400001')!;

      expect(
        Serviceability(pincode: pincode, isServiceable: false)
            .unavailableMessage,
        contains('400001'),
      );
    });
  });
}
