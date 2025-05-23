// lib/data/models/popular_category_models.dart

class PopularCategoryResponse {
  final String title;
  final List<PopularCategoryItem> categoriesDetails;

  PopularCategoryResponse({
    required this.title,
    required this.categoriesDetails,
  });

  factory PopularCategoryResponse.fromJson(Map<String, dynamic> json) {
    return PopularCategoryResponse(
      title: json['title'] ?? '',
      categoriesDetails: (json['categories_details'] as List?)
          ?.map((item) => PopularCategoryItem.fromJson(item))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'categories_details': categoriesDetails.map((item) => item.toJson()).toList(),
    };
  }
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
}