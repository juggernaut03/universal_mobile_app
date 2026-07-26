// test/data/home_feed_repository_test.dart
//
// Home is where users land, so the feed's job is to degrade to the previous
// home rather than to a blank scroll view: API → cache → shipped layout.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/data/models/home_feed_models.dart';
import 'package:patelmart/data/repositories/home_feed_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _section(
  String type, {
  required int slot,
  int? sequence,
  int? index,
  bool personalized = false,
  List<Map<String, dynamic>> items = const [],
}) =>
    {
      'id': '$type-${sequence ?? index ?? slot}',
      'type': type,
      'slot': slot,
      'title': 'Section $slot',
      'style': {'background_color': '#FFFFFF'},
      'source': {'sequence': sequence, 'index': index},
      'personalized': personalized,
      'items': items,
    };

String _body(List<Map<String, dynamic>> sections) => jsonEncode({
      'success': true,
      'schema_version': 1,
      'count': sections.length,
      'data': sections,
    });

HomeFeedRepository _build(MockClient client) => HomeFeedRepository(
      apiClient: ApiClient(client: client, logger: Logger()),
      logger: Logger(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('renders sections in the order the server assigned', () async {
    final repository = _build(MockClient((_) async => http.Response(
          _body([
            _section(HomeSectionType.productRail, slot: 2, sequence: 1),
            _section(HomeSectionType.heroCarousel, slot: 0),
            _section(HomeSectionType.categoryGrid, slot: 1, sequence: 2),
          ]),
          200,
          headers: {'content-type': 'application/json'},
        )));

    final feed = await repository.getFeed(storeCode: 'KLK');

    // Sorted by slot regardless of the order they arrived in.
    expect(
      feed.sections.map((s) => s.type),
      [
        HomeSectionType.heroCarousel,
        HomeSectionType.categoryGrid,
        HomeSectionType.productRail,
      ],
    );
  });

  test('an unknown section type survives parsing for the UI to skip', () async {
    final repository = _build(MockClient((_) async => http.Response(
          _body([
            _section(HomeSectionType.heroCarousel, slot: 0),
            _section('flash_sale_v9', slot: 1),
          ]),
          200,
          headers: {'content-type': 'application/json'},
        )));

    final feed = await repository.getFeed(storeCode: 'KLK');

    // Parsing must not throw on a type this build predates; filtering happens
    // in the section registry.
    expect(feed.sections.length, 2);
    expect(feed.sections.last.type, 'flash_sale_v9');
  });

  test('a server with no sections falls back to the shipped layout', () async {
    final repository = _build(MockClient((_) async => http.Response(
          _body([]),
          200,
          headers: {'content-type': 'application/json'},
        )));

    final feed = await repository.getFeed(storeCode: 'KLK');

    expect(feed.sections.length, HomeFeed.fallback.sections.length);
  });

  test('a failed request falls back to the last good feed', () async {
    var failing = false;
    final repository = _build(MockClient((_) async {
      if (failing) return http.Response('nope', 500);
      return http.Response(
        _body([_section(HomeSectionType.heroCarousel, slot: 0)]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));

    await repository.getFeed(storeCode: 'KLK'); // primes the cache
    failing = true;

    final feed = await repository.getFeed(storeCode: 'KLK');
    expect(feed.sections.length, 1);
    expect(feed.sections.single.type, HomeSectionType.heroCarousel);
  });

  test('the cache is per store, so switching store does not reuse a layout', () async {
    var body = _body([_section(HomeSectionType.heroCarousel, slot: 0)]);
    final repository = _build(MockClient((_) async =>
        http.Response(body, 200, headers: {'content-type': 'application/json'})));

    await repository.getFeed(storeCode: 'KLK');

    body = _body([
      _section(HomeSectionType.categoryGrid, slot: 0, sequence: 2),
      _section(HomeSectionType.productRail, slot: 1, sequence: 1),
    ]);
    final other = await repository.getFeed(storeCode: 'OTHER');

    expect(other.sections.length, 2);
  });

  test('a failure with no cache still yields the shipped layout', () async {
    final repository = _build(MockClient((_) async => http.Response('nope', 500)));

    final feed = await repository.getFeed(storeCode: 'KLK');

    expect(feed.sections, isNotEmpty);
    expect(feed.sections.first.type, HomeSectionType.categoryStrip);
  });

  test('a malformed body degrades instead of crashing', () async {
    final repository = _build(MockClient((_) async => http.Response(
          '{"success": true, "data": "not-a-list"}',
          200,
          headers: {'content-type': 'application/json'},
        )));

    final feed = await repository.getFeed(storeCode: 'KLK');
    expect(feed.sections, isNotEmpty);
  });

  group('shipped fallback layout', () {
    test('matches the order the app hardcoded before the feed existed', () {
      final types = HomeFeed.fallback.sections.map((s) => s.type).toList();

      expect(types, [
        HomeSectionType.categoryStrip,
        HomeSectionType.heroCarousel,
        HomeSectionType.categoryGrid,
        HomeSectionType.productRail,
        HomeSectionType.offerStrip,
        HomeSectionType.categoryGrid,
        HomeSectionType.productRail,
        HomeSectionType.offerStrip,
        HomeSectionType.categoryGrid,
        HomeSectionType.productRail,
        HomeSectionType.offerStrip,
        HomeSectionType.categoryGrid,
        HomeSectionType.productRail,
        HomeSectionType.offerStrip,
        HomeSectionType.seasonalPicks,
      ]);
    });

    test('addresses popular sections 2-5 and best sellers 1-4', () {
      final sections = HomeFeed.fallback.sections;

      expect(
        sections
            .where((s) => s.type == HomeSectionType.categoryGrid)
            .map((s) => s.sourceSequence),
        [2, 3, 4, 5],
      );
      expect(
        sections
            .where((s) => s.type == HomeSectionType.productRail)
            .map((s) => s.sourceSequence),
        [1, 2, 3, 4],
      );
    });

    test('offer slots are personalized and carry no items', () {
      final offers = HomeFeed.fallback.sections
          .where((s) => s.type == HomeSectionType.offerStrip);

      expect(offers.every((s) => s.personalized), isTrue);
      expect(offers.every((s) => s.items.isEmpty), isTrue);
      expect(offers.map((s) => s.sourceIndex), [0, 1, 2, 3]);
    });
  });
}
