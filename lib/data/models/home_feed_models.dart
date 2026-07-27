// lib/data/models/home_feed_models.dart
//
// The home screen as the backend describes it: an ordered list of typed
// sections (POST /api/home/feed).
//
// The app must treat an unrecognised `type` as "skip this section", never as
// an error — that is what lets the backend ship a new section type before the
// app that renders it exists.

/// Section types this app build can render. Anything else is skipped.
class HomeSectionType {
  static const String heroCarousel = 'hero_carousel';

  /// A second banner placement, and how advertisements reach the home screen.
  static const String bannerStrip = 'banner_strip';
  static const String categoryStrip = 'category_strip';
  static const String categoryGrid = 'category_grid';
  static const String productRail = 'product_rail';
  static const String offerStrip = 'offer_strip';
  static const String seasonalPicks = 'seasonal_picks';

  // Merchandising sections.
  static const String flashSale = 'flash_sale';
  static const String dealOfDay = 'deal_of_day';
  static const String buyAgain = 'buy_again';
  static const String recentlyViewed = 'recently_viewed';
  static const String freeDeliveryProgress = 'free_delivery_progress';
  static const String couponStrip = 'coupon_strip';
  static const String brandStrip = 'brand_strip';
  static const String uspStrip = 'usp_strip';
}

/// Which admin collection backs a section.
///
/// One section type can be fed by more than one collection — a product rail is
/// either best sellers or top sellers — and the two are indistinguishable by
/// sequence alone, so a renderer that guessed would draw the wrong rail.
class HomeSectionSource {
  static const String popularCategories = 'popular_categories';
  static const String seasonalCategories = 'seasonal_categories';
  static const String bestSellers = 'best_sellers';
  static const String topSellers = 'top_sellers';
  static const String banners = 'banners';
  static const String advertisements = 'advertisements';
}

/// Who a section is meant for. Matched on the device, because the feed itself
/// is public and cacheable and so cannot be filtered per user server-side.
class HomeSectionAudience {
  static const String all = 'all';
  static const String newUser = 'new';
  static const String returning = 'returning';
  static const String hasCart = 'has_cart';
}

class HomeSectionStyle {
  final String backgroundColor;

  const HomeSectionStyle({this.backgroundColor = ''});

  factory HomeSectionStyle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeSectionStyle();
    return HomeSectionStyle(
      backgroundColor: (json['background_color'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'background_color': backgroundColor};
}

class HomeSection {
  final String id;
  final String type;
  final int slot;
  final String title;
  final String description;
  final HomeSectionStyle style;

  /// Which source document this section came from. Phase 1 renderers address
  /// their data by this sequence, the same way the old hardcoded widgets did.
  final int? sourceSequence;

  /// Index within its own type, for placeholder sections that have no source
  /// document (offer slots).
  final int? sourceIndex;

  /// Which collection supplied this section; see [HomeSectionSource]. Empty
  /// when the backend did not say, in which case the renderer falls back to
  /// whatever the type has always meant.
  final String sourceCollection;

  /// True for sections the server deliberately left empty because filling them
  /// would make the feed user-specific. The client supplies the content.
  final bool personalized;

  /// End of the campaign window, when there is one. Drives countdowns.
  final DateTime? endsAt;

  /// Who should see this section; see [HomeSectionAudience].
  final String audience;

  /// Per-type settings the backend can add without an app change.
  final Map<String, dynamic> config;

  final List<Map<String, dynamic>> items;

  const HomeSection({
    required this.id,
    required this.type,
    required this.slot,
    this.title = '',
    this.description = '',
    this.style = const HomeSectionStyle(),
    this.sourceSequence,
    this.sourceIndex,
    this.sourceCollection = '',
    this.personalized = false,
    this.endsAt,
    this.audience = HomeSectionAudience.all,
    this.config = const {},
    this.items = const [],
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final source = json['source'] is Map<String, dynamic>
        ? json['source'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return HomeSection(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      slot: int.tryParse('${json['slot']}') ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      style: HomeSectionStyle.fromJson(
        json['style'] is Map<String, dynamic>
            ? json['style'] as Map<String, dynamic>
            : null,
      ),
      sourceSequence: int.tryParse('${source['sequence']}'),
      sourceIndex: int.tryParse('${source['index']}'),
      sourceCollection: (source['collection_name'] ?? '').toString(),
      personalized: json['personalized'] == true,
      endsAt: DateTime.tryParse('${json['ends_at']}')?.toLocal(),
      audience: (json['audience'] ?? HomeSectionAudience.all).toString(),
      config: json['config'] is Map<String, dynamic>
          ? json['config'] as Map<String, dynamic>
          : const <String, dynamic>{},
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'slot': slot,
        'title': title,
        'description': description,
        'style': style.toJson(),
        'source': {
          'sequence': sourceSequence,
          'index': sourceIndex,
          'collection_name': sourceCollection,
        },
        'personalized': personalized,
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'audience': audience,
        'config': config,
        'items': items,
      };
}

class HomeFeed {
  final int schemaVersion;
  final List<HomeSection> sections;

  const HomeFeed({this.schemaVersion = 1, this.sections = const []});

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    final sections = (json['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HomeSection.fromJson)
        .where((s) => s.type.isNotEmpty)
        .toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));

    return HomeFeed(
      schemaVersion: int.tryParse('${json['schema_version']}') ?? 1,
      sections: sections,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'data': sections.map((s) => s.toJson()).toList(),
      };

  bool get isEmpty => sections.isEmpty;

  /// Whether a campaign section has already finished.
  ///
  /// The feed is cached and can outlive its own window, so a countdown that
  /// has run out must not keep rendering.
  bool sectionHasExpired(HomeSection section, {DateTime? now}) {
    final endsAt = section.endsAt;
    if (endsAt == null) return false;
    return endsAt.isBefore(now ?? DateTime.now());
  }

  /// The section of [type] whose source sequence is [sequence], if the feed
  /// carries one. Used by the data providers to serve themselves from the feed
  /// instead of making their own call.
  ///
  /// [collection] disambiguates types that more than one collection can fill:
  /// a best-seller rail and a top-seller rail are both `product_rail` and can
  /// share a sequence, so matching on type alone would hand a provider the
  /// other collection's products. A section whose source the backend did not
  /// name still matches, so an older backend keeps working.
  HomeSection? bySequence(String type, int sequence, {String? collection}) {
    for (final section in sections) {
      if (section.type != type || section.sourceSequence != sequence) continue;
      if (collection != null &&
          section.sourceCollection.isNotEmpty &&
          section.sourceCollection != collection) {
        continue;
      }
      return section;
    }
    return null;
  }

  /// The layout the app shipped with, used when the feed cannot be reached and
  /// nothing is cached. Mirrors the order the home screen hardcoded before the
  /// feed existed, so a total backend outage still renders the normal home.
  static HomeFeed get fallback {
    final sections = <HomeSection>[];
    var slot = 0;

    HomeSection make(String type, {int? sequence, int? index}) => HomeSection(
          id: '$type-${sequence ?? index ?? 0}',
          type: type,
          slot: slot++,
          sourceSequence: sequence,
          sourceIndex: index,
          personalized: type == HomeSectionType.offerStrip,
        );

    sections.add(make(HomeSectionType.categoryStrip, sequence: 1));
    sections.add(make(HomeSectionType.heroCarousel, sequence: 0));
    for (var i = 0; i < 4; i++) {
      sections.add(make(HomeSectionType.categoryGrid, sequence: i + 2));
      sections.add(make(HomeSectionType.productRail, sequence: i + 1));
      sections.add(make(HomeSectionType.offerStrip, index: i));
    }
    sections.add(make(HomeSectionType.seasonalPicks, sequence: 1));

    return HomeFeed(sections: sections);
  }
}
