// test/data/recently_viewed_service_test.dart
//
// Browsing history is the most personal thing the app stores, and it never
// leaves the device — so its correctness is only ever checked here.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/data/services/recently_viewed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductModel product(String code, {String store = 'S1', String name = 'Item'}) =>
    ProductModel.fromJson({
      'p_code': code,
      'product_name': '$name $code',
      'store_code': store,
      'our_price': 10,
      'product_mrp': 12,
      'pcode_status': 'Y',
    });

void main() {
  late RecentlyViewedService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = RecentlyViewedService();
  });

  test('records a view and reads it back', () async {
    await service.record(product('A'));

    final viewed = await service.load(storeCode: 'S1');

    expect(viewed.map((p) => p.pCode), ['A']);
  });

  test('most recently viewed comes first', () async {
    await service.record(product('A'));
    await service.record(product('B'));

    final viewed = await service.load(storeCode: 'S1');

    expect(viewed.map((p) => p.pCode), ['B', 'A']);
  });

  test('re-viewing a product moves it to the front rather than duplicating it', () async {
    await service.record(product('A'));
    await service.record(product('B'));
    await service.record(product('A'));

    final viewed = await service.load(storeCode: 'S1');

    expect(viewed.map((p) => p.pCode), ['A', 'B']);
  });

  test('the list is capped so the stored history cannot grow without bound', () async {
    for (var i = 0; i < RecentlyViewedService.maxEntries + 5; i++) {
      await service.record(product('P$i'));
    }

    final viewed = await service.load(storeCode: 'S1');

    expect(viewed, hasLength(RecentlyViewedService.maxEntries));
    // The newest survive; the oldest fall off the end.
    expect(viewed.first.pCode, 'P${RecentlyViewedService.maxEntries + 4}');
  });

  test('products from another store are not offered', () async {
    // They are not purchasable here, so tapping one would dead-end.
    await service.record(product('A', store: 'S1'));
    await service.record(product('B', store: 'S2'));

    expect((await service.load(storeCode: 'S1')).map((p) => p.pCode), ['A']);
    expect((await service.load(storeCode: 'S2')).map((p) => p.pCode), ['B']);
  });

  test('a product with no code is ignored', () async {
    await service.record(product(''));

    expect(await service.load(storeCode: 'S1'), isEmpty);
  });

  test('unreadable stored history yields an empty list rather than throwing', () async {
    SharedPreferences.setMockInitialValues({'recently_viewed_products': 'not json'});

    expect(await RecentlyViewedService().load(storeCode: 'S1'), isEmpty);
  });

  test('clear removes everything', () async {
    await service.record(product('A'));
    await service.clear();

    expect(await service.load(storeCode: 'S1'), isEmpty);
  });
}
