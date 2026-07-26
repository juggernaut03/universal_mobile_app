// lib/data/models/category_model.dart

import '../../domain/entities/catalogue.dart' as domain;

class CategoryModel {
  final String id;
  final String categoryId;
  final String categoryName;
  final String departmentId;
  final int sequenceId;
  final String storeCode;
  final String numberOfColumns;
  final String imageLink;

  CategoryModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.departmentId,
    required this.sequenceId,
    required this.storeCode,
    required this.numberOfColumns,
    required this.imageLink,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      categoryId: (json['idcategory_master'] ?? '').toString(),
      categoryName: json['category_name'] ?? '',
      departmentId: (json['dept_id'] ?? '').toString(),
      sequenceId: json['sequence_id'] is int
          ? json['sequence_id']
          : int.tryParse(json['sequence_id']?.toString() ?? '') ?? 0,
      storeCode: json['store_code'] ?? '',
      numberOfColumns: (json['no_of_col'] ?? '').toString(),
      imageLink: json['image_link'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'idcategory_master': categoryId,
      'category_name': categoryName,
      'dept_id': departmentId,
      'sequence_id': sequenceId,
      'store_code': storeCode,
      'no_of_col': numberOfColumns,
      'image_link': imageLink,
    };
  }

  /// Converts to the domain entity.
  ///
  /// `no_of_col` arrives as a string; it is parsed once here and becomes null
  /// when the backend expressed no preference.
  domain.Category toEntity() => domain.Category(
        id: id,
        code: categoryId,
        name: categoryName,
        imageUrl: imageLink,
        sequence: sequenceId,
        departmentCode: departmentId,
        preferredColumns: int.tryParse(numberOfColumns),
      );
}
