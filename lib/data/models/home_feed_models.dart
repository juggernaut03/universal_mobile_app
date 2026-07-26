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
  static const String categoryStrip = 'category_strip';
  static const String categoryGrid = 'category_grid';
  static const String productRail = 'product_rail';
  static const String offerStrip = 'offer_strip';
  static const String seasonalPicks = 'seasonal_picks';
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

  /// True for sections the server deliberately left empty because filling them
  /// would make the feed user-specific. The client supplies the content.
  final bool personalized;

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
    this.personalized = false,
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
      personalized: json['personalized'] == true,
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
        'source': {'sequence': sourceSequence, 'index': sourceIndex},
        'personalized': personalized,
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

  /// The section of [type] whose source sequence is [sequence], if the feed
  /// carries one. Used by the data providers to serve themselves from the feed
  /// instead of making their own call.
  HomeSection? bySequence(String type, int sequence) {
    for (final section in sections) {
      if (section.type == type && section.sourceSequence == sequence) {
        return section;
      }
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
