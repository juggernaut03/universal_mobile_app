// Feed payloads arriving over postMessage are not shaped like decoded JSON.
//
// dart:html converts an inbound JS object into Map<dynamic, dynamic>, all the
// way down. jsonDecode produces Map<String, dynamic>. Parsers written against
// the second shape compile fine and then silently drop everything from the
// first, which is why the live preview rendered its empty state while the
// admin panel was sending a full feed.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/data/models/home_feed_models.dart';
import 'package:patelmart/preview/preview_protocol.dart';

void main() {
  // What the admin panel posts: {schema_version: 1, data: [...]}.
  List<Map<String, dynamic>> sections() => [
        {
          'id': 'sec-1',
          'type': 'product_rail',
          'title': 'Dairy Products',
          'slot': 1,
          'items': const [],
        },
      ];

  group('HomeFeed.fromJson', () {
    test('parses a jsonDecode-shaped payload', () {
      final feed = HomeFeed.fromJson({
        'schema_version': 1,
        'data': sections(),
      });

      expect(feed.sections, hasLength(1));
      expect(feed.sections.single.title, 'Dairy Products');
    });

    test('parses a postMessage-shaped payload', () {
      // The same feed as dart:html delivers it: every map dynamic-keyed.
      final payload = <dynamic, dynamic>{
        'schema_version': 1,
        'data': <dynamic>[
          <dynamic, dynamic>{
            'id': 'sec-1',
            'type': 'product_rail',
            'title': 'Dairy Products',
            'slot': 1,
            'items': const <dynamic>[],
          },
        ],
      };

      // What the transport did before the fix: a shallow cast, which leaves
      // the sections inside `data` dynamic-keyed.
      final shallow = HomeFeed.fromJson(payload.cast<String, dynamic>());
      expect(
        shallow.sections,
        isEmpty,
        reason: 'the regression this guards: a shallow cast loses every section',
      );

      // What it does now.
      final feed = HomeFeed.fromJson(normalisePayload(payload));
      expect(
        feed.sections,
        hasLength(1),
        reason: 'sections dropped — the preview would render its empty state',
      );
      expect(feed.sections.single.title, 'Dairy Products');
    });

    test('normalisePayload leaves a jsonDecode-shaped payload alone', () {
      final feed = HomeFeed.fromJson(
        normalisePayload({'schema_version': 1, 'data': sections()}),
      );

      expect(feed.sections, hasLength(1));
    });

    test('normalisePayload survives a payload that is not an object', () {
      // An older or hostile sender: must yield an empty feed, not throw.
      expect(normalisePayload(null), isEmpty);
      expect(normalisePayload('nonsense'), isEmpty);
      expect(HomeFeed.fromJson(normalisePayload(null)).sections, isEmpty);
    });
  });
}
