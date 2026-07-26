// lib/data/models/subcategory_model.dart

import '../../domain/entities/catalogue.dart';
class SubcategoryModel {
  final String id;
  final String subCategoryId;
  final String subCategoryName;
  final String categoryId;
  final String mainCategoryName;

  SubcategoryModel({
    required this.id,
    required this.subCategoryId,
    required this.subCategoryName,
    required this.categoryId,
    required this.mainCategoryName,
  });

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      subCategoryId: (json['idsub_category_master'] ?? '').toString(),
      subCategoryName: json['sub_category_name'] ?? '',
      categoryId: (json['category_id'] ?? '').toString(),
      mainCategoryName: json['main_category_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'idsub_category_master': subCategoryId,
      'sub_category_name': subCategoryName,
      'category_id': categoryId,
      'main_category_name': mainCategoryName,
    };
  }

  /// Converts to the domain entity.
  Subcategory toEntity() => Subcategory(
        id: id,
        code: subCategoryId,
        name: subCategoryName,
        categoryCode: categoryId,
        categoryName: mainCategoryName,
      );
}
