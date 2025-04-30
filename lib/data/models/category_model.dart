// lib/data/models/category_model.dart

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
      id: json['_id'] ?? '',
      categoryId: json['idcategory_master'] ?? '',
      categoryName: json['category_name'] ?? '',
      departmentId: json['dept_id'] ?? '',
      sequenceId: json['sequence_id'] ?? 0,
      storeCode: json['store_code'] ?? '',
      numberOfColumns: json['no_of_col'] ?? '',
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
}