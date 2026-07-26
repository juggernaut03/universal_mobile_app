// lib/domain/repositories/i_catalogue_repository.dart

import '../../core/result/result.dart';
import '../entities/catalogue.dart';

/// Browsing the product taxonomy.
///
/// One interface for all three levels rather than three near-identical ones:
/// they are always used together to build a browse path, and no consumer needs
/// only a slice of it.
abstract interface class ICatalogueRepository {
  /// Departments carried by a store.
  Future<Result<List<Department>>> departments(String storeCode);

  /// Categories within a department.
  Future<Result<List<Category>>> categories({
    required String departmentCode,
    required String storeCode,
  });

  /// Subcategories within a category.
  ///
  /// [departmentCode] and [storeCode] let the backend answer for this category
  /// alone; without them the whole taxonomy has to be fetched and filtered.
  Future<Result<List<Subcategory>>> subcategories(
    String categoryCode, {
    String? departmentCode,
    String? storeCode,
  });

  /// Drops cached taxonomy data.
  Future<Result<void>> clearCache();
}
