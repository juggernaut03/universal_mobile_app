import '../../domain/entities/promo_section.dart';

// lib/data/models/popular_category_models.dart

class PopularCategoryResponse {
  final String title;

  /// Section background colour. Only the seasonal strip renders it, but it
  /// belongs here because that strip is section 1 of this same response.
  final String categoryBgColor;

  final List<PopularCategoryItem> categoriesDetails;

  PopularCategoryResponse({
    required this.title,
    required this.categoriesDetails,
    this.categoryBgColor = '#FFFFFF',
  });

  factory PopularCategoryResponse.fromJson(Map<String, dynamic> json) {
    return PopularCategoryResponse(
      title: (json['title'] as String?)?.replaceAll('Cateogory', 'Category') ?? '',
      categoryBgColor: (json['category_bg_color'] as String?) ?? '#FFFFFF',
      categoriesDetails: (json['categories_details'] as List?)
          ?.map((item) => PopularCategoryItem.fromJson(item))
          .toList() ?? [],
    );
  }

  /// Returns an empty response — used when outlet is not yet available
  /// to prevent providers from throwing and stalling the RefreshIndicator.
  factory PopularCategoryResponse.empty() {
    return PopularCategoryResponse(
      title: '',
      categoriesDetails: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category_bg_color': categoryBgColor,
      'categories_details': categoriesDetails.map((item) => item.toJson()).toList(),
    };
  }
  /// Converts to the domain section.
  ///
  /// The `Cateogory` -> `Category` correction on the title stays in the DTO:
  /// it is a fix for how the backend spells a field, which is exactly what a
  /// DTO is for.
  PromoSection toEntity(int sectionId) => PromoSection(
        sectionId: sectionId,
        title: title.trim(),
        items: categoriesDetails.map((i) => i.toEntity()).toList(growable: false),
      );

}

class PopularCategoryItem {
  final String id;
  final String categoryId;
  final String categoryName;
  final String deptId;
  final int sequenceId;
  final String storeCode;
  final String numberOfColumns;
  final String imageLink;

  PopularCategoryItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.deptId,
    required this.sequenceId,
    required this.storeCode,
    required this.numberOfColumns,
    required this.imageLink,
  });

  factory PopularCategoryItem.fromJson(Map<String, dynamic> json) {
    return PopularCategoryItem(
      id: json['_id'] ?? '',
      categoryId: json['idcategory_master'] ?? '',
      categoryName: json['category_name'] ?? '',
      deptId: json['dept_id'] ?? '',
      sequenceId: json['sequence_id'] ?? 0,
      storeCode: json['store_code'] ?? '',
      numberOfColumns: json['no_of_col'] ?? '4',
      imageLink: json['image_link'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'idcategory_master': categoryId,
      'category_name': categoryName,
      'dept_id': deptId,
      'sequence_id': sequenceId,
      'store_code': storeCode,
      'no_of_col': numberOfColumns,
      'image_link': imageLink,
    };
  }
  /// Converts to the domain tile.
  PromoItem toEntity() => PromoItem(
        id: id,
        categoryCode: categoryId,
        departmentCode: deptId,
        label: categoryName,
        imageUrl: imageLink,
      );

}