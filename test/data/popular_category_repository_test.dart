// test/data/popular_category_repository_test.dart
//
// The home screen renders five strips off `/popular-categories/list` — sections
// 2-5 plus the seasonal strip, which is section 1. Each used to issue its own
// request for the full section list and keep one section. These tests pin the
// collapsing of those requests down to one.

import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/data/models/popular_category_models.dart';
import 'package:patelmart/data/repositories/popular_category_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One section per sequence, with an empty image_link so pre-caching stays off
/// the network.
Map<String, dynamic> _section(int sequence) => {
      'sequence': sequence,
      'title': 'Section $sequence',
      'background_color': '#AABBCC',
      'subcategories': [
        {
          'position': 1,
          'image_link': '',
          'subcategory_details': {
            'id': 'sub-$sequence',
            'sub_category_name': 'Item $sequence',
            'category_id': '10',
          },
          'category_details': {
            'idcategory_master': '10',
            'dept_id': '2',
            'category_name': 'Category',
          },
        },
      ],
    };

/// Image pre-caching is not under test and the real one needs path_provider.
final class _NoopCacheManager implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

String _payload() => jsonEncode({
      'success': true,
      'count': 5,
      'data': [for (var i = 1; i <= 5; i++) _section(i)],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int requestCount;
  late PopularCategoryRepository repository;

  setUp(() async {
    // A timestamp of "now" keeps the 2 AM scheduled sweep from firing, which
    // would empty the image cache and need platform channels.
    SharedPreferences.setMockInitialValues({
      'last_popular_category_cache_clear_time':
          DateTime.now().millisecondsSinceEpoch,
    });

    requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      return http.Response(_payload(), 200,
          headers: {'content-type': 'application/json'});
    });

    repository = PopularCategoryRepository(
      apiClient: ApiClient(client: client, logger: Logger()),
      logger: Logger(),
      cacheManager: _NoopCacheManager(),
    );
  });

  Future<PopularCategoryResponse> section(int id, {bool forceRefresh = false}) =>
      repository.getPopularCategories(
        sectionId: id,
        departmentId: '1',
        storeCode: 'KLK',
        forceRefresh: forceRefresh,
      );

  test('five concurrent sections share one request', () async {
    final responses = await Future.wait([
      for (var id = 1; id <= 5; id++) repository.getPopularCategories(
            sectionId: id,
            departmentId: '1',
            storeCode: 'KLK',
          ),
    ]);

    expect(requestCount, 1);
    // Every caller still gets its own section, not the first one five times.
    expect(
      responses.map((r) => r.title),
      ['Section 1', 'Section 2', 'Section 3', 'Section 4', 'Section 5'],
    );
    expect(responses.first.categoriesDetails.single.categoryName, 'Item 1');
  });

  test('sequential sections are served from the cache', () async {
    await section(2);
    await section(3);
    await section(4);

    expect(requestCount, 1);
  });

  test('a forced refresh goes back to the network', () async {
    await section(2);
    expect(requestCount, 1);

    await section(2, forceRefresh: true);
    expect(requestCount, 2);
  });

  test('a concurrent forced refresh of every section is still one request',
      () async {
    await section(2); // prime the cache
    requestCount = 0;

    await Future.wait([
      for (var id = 1; id <= 5; id++) section(id, forceRefresh: true),
    ]);

    expect(requestCount, 1);
  });

  test('the section background colour survives the round trip', () async {
    final response = await section(1);
    expect(response.categoryBgColor, '#AABBCC');
  });

  test('a different store does not reuse the previous store\'s response',
      () async {
    await section(2);
    await repository.getPopularCategories(
      sectionId: 2,
      departmentId: '1',
      storeCode: 'OTHER',
    );

    expect(requestCount, 2);
  });
}
