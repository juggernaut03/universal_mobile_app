// lib/domain/entities/promo_section.dart
//
// A merchandising strip on the home screen: a title plus tappable tiles.
//
// The home screen carries four of these ("popular category sections 2-5"),
// implemented as four copies of the same 200-line widget backed by four
// identical provider families. Nothing about them differed except a section
// number.

import 'package:meta/meta.dart';

/// One tile in a [PromoSection].
@immutable
final class PromoItem {
  final String id;

  /// Category code to open when tapped.
  final String categoryCode;

  /// Department the category belongs to, needed to build the route.
  final String departmentCode;

  final String label;
  final String imageUrl;

  const PromoItem({
    required this.id,
    required this.categoryCode,
    required this.departmentCode,
    required this.label,
    required this.imageUrl,
  });

  /// Whether the tile can be rendered and navigated to.
  bool get isDisplayable =>
      categoryCode.isNotEmpty && label.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PromoItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PromoItem($categoryCode, $label)';
}

/// A titled strip of promoted categories.
@immutable
final class PromoSection {
  /// Which strip this is. The backend keys sections by number.
  final int sectionId;

  /// Title from the backend, already corrected and trimmed.
  final String title;

  final List<PromoItem> items;

  const PromoSection({
    required this.sectionId,
    required this.title,
    required this.items,
  });

  /// An empty strip, for when no outlet is selected yet.
  ///
  /// Rendering nothing is correct here — a merchandising strip with no store to
  /// merchandise for is not an error.
  const PromoSection.empty(this.sectionId)
      : title = '',
        items = const [];

  /// Whether the strip is worth rendering at all.
  ///
  /// A section with a title but no tappable tiles is a blank space with a
  /// heading; each widget copy previously decided this for itself.
  bool get isRenderable => items.any((i) => i.isDisplayable);

  /// Only the tiles fit to show.
  List<PromoItem> get displayableItems =>
      List.unmodifiable(items.where((i) => i.isDisplayable));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromoSection &&
          other.sectionId == sectionId &&
          other.title == title;

  @override
  int get hashCode => Object.hash(sectionId, title);

  @override
  String toString() =>
      'PromoSection($sectionId, "$title", ${items.length} items)';
}
