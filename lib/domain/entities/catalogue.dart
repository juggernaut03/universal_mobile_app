// lib/domain/entities/catalogue.dart
//
// The browse taxonomy: Department > Category > Subcategory > Product.
//
// All three levels are immutable. `DepartmentModel.isSelected` was a mutable
// field on the DTO — UI selection state stored on shared data, flippable by
// anything holding a reference. Selection is presentation state and belongs in
// a provider, not on the entity.

import 'package:meta/meta.dart';

/// Shared shape of a browse level: an identity, a label, artwork and a
/// display position.
@immutable
sealed class CatalogueNode {
  /// Backend document id.
  final String id;

  /// Business identifier used in catalogue queries.
  final String code;

  /// Label shown to the user.
  final String name;

  /// Artwork URL. May be empty.
  final String imageUrl;

  /// Display order. Lower sorts first.
  final int sequence;

  const CatalogueNode({
    required this.id,
    required this.code,
    required this.name,
    required this.imageUrl,
    required this.sequence,
  });

  /// Whether this node is fit to display: it needs a code to query by and a
  /// name to label it with.
  bool get isDisplayable => code.isNotEmpty && name.trim().isNotEmpty;
}

/// Top level of the taxonomy — "Grocery", "Personal Care".
final class Department extends CatalogueNode {
  const Department({
    required super.id,
    required super.code,
    required super.name,
    required super.imageUrl,
    required super.sequence,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Department && other.code == code;

  @override
  int get hashCode => Object.hash(Department, code);

  @override
  String toString() => 'Department($code, $name)';
}

/// Second level, belonging to a [Department].
final class Category extends CatalogueNode {
  /// Code of the owning department.
  final String departmentCode;

  /// Grid columns the backend suggests for this category's tiles.
  ///
  /// Arrives as a string (`no_of_col`) and is parsed once here. Null means the
  /// backend expressed no preference, so the UI picks its own.
  final int? preferredColumns;

  const Category({
    required super.id,
    required super.code,
    required super.name,
    required super.imageUrl,
    required super.sequence,
    required this.departmentCode,
    this.preferredColumns,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Category && other.code == code;

  @override
  int get hashCode => Object.hash(Category, code);

  @override
  String toString() => 'Category($code, $name)';
}

/// Third level, belonging to a [Category]. Products hang off this.
final class Subcategory extends CatalogueNode {
  /// Code of the owning category.
  final String categoryCode;

  /// Name of the owning category, denormalised by the backend for headers.
  final String categoryName;

  const Subcategory({
    required super.id,
    required super.code,
    required super.name,
    required this.categoryCode,
    this.categoryName = '',
    super.imageUrl = '',
    super.sequence = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Subcategory && other.code == code;

  @override
  int get hashCode => Object.hash(Subcategory, code);

  @override
  String toString() => 'Subcategory($code, $name)';
}

/// Ordering and filtering shared by every catalogue level.
extension CatalogueNodeList<T extends CatalogueNode> on List<T> {
  /// Displayable nodes only, in the backend's intended order.
  ///
  /// Every screen previously did this filtering and sorting inline, or forgot
  /// to — which is how unnamed placeholder rows reached the UI.
  List<T> get displayable {
    final result = where((n) => n.isDisplayable).toList();
    result.sort((a, b) => a.sequence.compareTo(b.sequence));
    return List.unmodifiable(result);
  }
}
