// test/data/subcategory_repository_test.dart
//
// Opening a category used to download the tenant's entire subcategory table and
// throw away every row but one category's. These tests pin the targeted query,
// the fallback that keeps tenants with unscoped categories working, and the
// caching that stops the fallback from repeating per category.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/data/repositories/subcategory_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _row(String id, String categoryId) => {
      'id': id,
      'idsub_category_master': id,
      'sub_category_name': 'Sub $id',
      'category_id': categoryId,
      'main_category_name': 'Category $categoryId',
    };

String _body(List<Map<String, dynamic>> rows) =>
    jsonEncode({'success': true, 'count': rows.length, 'data': rows});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late bool targetedReturnsRows;

  SubcategoryRepository build() {
    final client = MockClient((request) async {
      final isTargeted = request.url.path.endsWith('/subcategories/get-subcategories');
      calls.add(isTargeted ? 'POST targeted' : 'GET all');

      if (isTargeted) {
        return http.Response(
          _body(targetedReturnsRows ? [_row('a', '10')] : []),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // The tenant-wide list: two categories' worth of rows.
      return http.Response(
        _body([_row('a', '10'), _row('b', '10'), _row('c', '20')]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    return SubcategoryRepository(client: client, logger: Logger());
  }

  setUp(() {
    // A timestamp of "now" keeps the 2 AM scheduled sweep from firing.
    SharedPreferences.setMockInitialValues({
      'last_subcategory_cache_clear_time': DateTime.now().millisecondsSinceEpoch,
    });
    calls = [];
    targetedReturnsRows = true;
  });

  test('asks for one category when the browse context is known', () async {
    final subcategories = await build().getSubcategories(
      '10',
      departmentId: '2',
      storeCode: 'KLK',
    );

    expect(calls, ['POST targeted']);
    expect(subcategories.single.subCategoryName, 'Sub a');
  });

  test('falls back to the full list when the targeted query finds nothing',
      () async {
    targetedReturnsRows = false;

    final subcategories = await build().getSubcategories(
      '10',
      departmentId: '2',
      storeCode: 'KLK',
    );

    expect(calls, ['POST targeted', 'GET all']);
    // Filtered to category 10 — the row for category 20 is dropped.
    expect(subcategories.map((s) => s.subCategoryName), ['Sub a', 'Sub b']);
  });

  test('falls back to the full list when there is no browse context', () async {
    final subcategories = await build().getSubcategories('20');

    expect(calls, ['GET all']);
    expect(subcategories.single.subCategoryName, 'Sub c');
  });

  test('the full list is fetched once, not once per category', () async {
    final repository = build();
    await repository.getSubcategories('10');
    await repository.getSubcategories('20');

    expect(calls, ['GET all']);
  });

  test('a second open of the same category hits no endpoint', () async {
    final repository = build();
    await repository.getSubcategories('10', departmentId: '2', storeCode: 'KLK');
    await repository.getSubcategories('10', departmentId: '2', storeCode: 'KLK');

    expect(calls, ['POST targeted']);
  });

  test('clearCache drops both the per-category and full-list entries', () async {
    final repository = build();
    await repository.getSubcategories('10');
    await repository.clearCache();
    await repository.getSubcategories('10');

    expect(calls, ['GET all', 'GET all']);
  });
}
