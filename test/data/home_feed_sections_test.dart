// test/data/home_feed_sections_test.dart
//
// The rules that decide which admin collection a home section draws from, and
// how its items are read.
//
// These matter because every failure mode here is silent: a section renders
// the wrong collection's content, or renders nothing, with no error anywhere.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/data/models/home_feed_mappers.dart';
import 'package:patelmart/data/models/home_feed_models.dart';

HomeSection section({
  required String type,
  int? sequence,
  String collection = '',
  List<Map<String, dynamic>> items = const [],
}) =>
    HomeSection(
      id: '$type-$sequence',
      type: type,
      slot: 0,
      sourceSequence: sequence,
      sourceCollection: collection,
      items: items,
    );

void main() {
  group('feed parsing', () {
    test('a section carries the collection that filled it', () {
      final parsed = HomeSection.fromJson({
        'id': 'x',
        'type': 'product_rail',
        'slot': 3,
        'source': {'sequence': 2, 'collection_name': 'top_sellers'},
      });

      expect(parsed.sourceCollection, 'top_sellers');
      expect(parsed.sourceSequence, 2);
    });

    test('a section from a backend that does not name its source still parses', () {
      final parsed = HomeSection.fromJson({
        'id': 'x',
        'type': 'product_rail',
        'source': {'sequence': 1},
      });

      expect(parsed.sourceCollection, isEmpty);
    });

    test('banner_strip is a type the app renders, not one it skips', () {
      final parsed = HomeSection.fromJson({'id': 'x', 'type': HomeSectionType.bannerStrip});

      expect(parsed.type, HomeSectionType.bannerStrip);
    });
  });

  group('bySequence', () {
    // A best-seller rail and a top-seller rail are both product_rail and can
    // share a sequence. Matching on type alone hands a provider the other
    // collection's products under its own heading.
    final feed = HomeFeed(sections: [
      section(
        type: HomeSectionType.productRail,
        sequence: 1,
        collection: HomeSectionSource.bestSellers,
        items: const [
          {'p_code': 'best'}
        ],
      ),
      section(
        type: HomeSectionType.productRail,
        sequence: 1,
        collection: HomeSectionSource.topSellers,
        items: const [
          {'p_code': 'top'}
        ],
      ),
    ]);

    test('picks the rail from the collection asked for', () {
      final best = feed.bySequence(
        HomeSectionType.productRail,
        1,
        collection: HomeSectionSource.bestSellers,
      );
      final top = feed.bySequence(
        HomeSectionType.productRail,
        1,
        collection: HomeSectionSource.topSellers,
      );

      expect(best!.items.first['p_code'], 'best');
      expect(top!.items.first['p_code'], 'top');
    });

    test('without a collection it keeps the old first-match behaviour', () {
      final match = feed.bySequence(HomeSectionType.productRail, 1);

      expect(match!.items.first['p_code'], 'best');
    });

    test('a section whose source the backend did not name still matches', () {
      // Otherwise upgrading the app before the backend would blank the screen.
      final older = HomeFeed(sections: [
        section(type: HomeSectionType.productRail, sequence: 1, items: const [
          {'p_code': 'legacy'}
        ]),
      ]);

      final match = older.bySequence(
        HomeSectionType.productRail,
        1,
        collection: HomeSectionSource.bestSellers,
      );

      expect(match!.items.first['p_code'], 'legacy');
    });

    test('asking for a collection the feed does not carry yields nothing', () {
      expect(
        feed.bySequence(
          HomeSectionType.productRail,
          1,
          collection: HomeSectionSource.seasonalCategories,
        ),
        isNull,
      );
    });
  });

  group('banner mapping', () {
    test('reads a banner: image_url and action.value', () {
      final banners = section(type: HomeSectionType.heroCarousel, items: const [
        {
          'id': 'b1',
          'image_url': 'https://cdn/banner.png',
          'action': {'type': 'url', 'value': '/category/5'},
          'sequence': 2,
        }
      ]).toPromotionalBanners('S1');

      expect(banners.single.imageUrl, 'https://cdn/banner.png');
      expect(banners.single.redirectLink, '/category/5');
      expect(banners.single.storeCode, 'S1');
    });

    test('reads an advertisement: banner_url and a flat redirect_url', () {
      // Advertisements name both fields differently from banners, so a mapper
      // that only knew the banner shape dropped every advertisement.
      final banners = section(type: HomeSectionType.bannerStrip, items: const [
        {
          '_id': 'a1',
          'banner_url': 'https://cdn/ad.png',
          'redirect_url': '/product/9',
        }
      ]).toPromotionalBanners('S1');

      expect(banners.single.imageUrl, 'https://cdn/ad.png');
      expect(banners.single.redirectLink, '/product/9');
      expect(banners.single.id, 'a1');
    });

    test('per-breakpoint assets win over the flat url', () {
      final banners = section(type: HomeSectionType.heroCarousel, items: const [
        {
          'id': 'b1',
          'image_url': 'https://cdn/flat.png',
          'banner_urls': {
            'bannerUrl1': {'mobile': 'https://cdn/mobile.png', 'desktop': 'https://cdn/d.png'}
          },
        }
      ]).toPromotionalBanners('S1');

      expect(banners.single.imageUrl, 'https://cdn/mobile.png');
    });

    test("an advertisement's single banner_urls object is read one level up", () {
      final banners = section(type: HomeSectionType.bannerStrip, items: const [
        {
          'id': 'a1',
          'banner_urls': {'mobile': 'https://cdn/admobile.png'},
        }
      ]).toPromotionalBanners('S1');

      expect(banners.single.imageUrl, 'https://cdn/admobile.png');
    });

    test('an item with no usable image is skipped, not rendered blank', () {
      final banners = section(type: HomeSectionType.bannerStrip, items: const [
        {'id': 'a1'},
        {'id': 'a2', 'banner_url': 'https://cdn/ok.png'},
      ]).toPromotionalBanners('S1');

      expect(banners, hasLength(1));
      expect(banners.single.id, 'a2');
    });

    test('banners come back in sequence order', () {
      final banners = section(type: HomeSectionType.bannerStrip, items: const [
        {'id': 'b', 'banner_url': 'https://cdn/2.png', 'sequence': 5},
        {'id': 'a', 'banner_url': 'https://cdn/1.png', 'sequence': 1},
      ]).toPromotionalBanners('S1');

      expect(banners.map((b) => b.id), ['a', 'b']);
    });
  });
}
