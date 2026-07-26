// lib/data/repositories/catalogue_repository_impl.dart
//
// Implements ICatalogueRepository over the existing CategoryRepository and
// SubcategoryRepository, which between them already own the HTTP calls and the
// cache handling for all three taxonomy levels.
//
// Those two classes stay for now — Phase 4's follow-up splits their caching
// into a datasource the way Product's was. What changes today is the contract:
// callers get entities and typed failures instead of raw DTO lists that throw.

import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../domain/entities/catalogue.dart' as domain;
import '../../domain/repositories/i_catalogue_repository.dart';
import 'category_repository.dart';
import 'subcategory_repository.dart';

final class CatalogueRepositoryImpl implements ICatalogueRepository {
  final CategoryRepository _categoryRepository;
  final SubcategoryRepository _subcategoryRepository;

  CatalogueRepositoryImpl({
    required CategoryRepository categoryRepository,
    required SubcategoryRepository subcategoryRepository,
  })  : _categoryRepository = categoryRepository,
        _subcategoryRepository = subcategoryRepository;

  @override
  Future<Result<List<domain.Department>>> departments(String storeCode) {
    return guard(() async {
      final models = await _categoryRepository.getDepartments(storeCode);
      return models.map((m) => m.toEntity()).toList(growable: false);
    });
  }

  @override
  Future<Result<List<domain.Category>>> categories({
    required String departmentCode,
    required String storeCode,
  }) {
    return guard(() async {
      final models = await _categoryRepository.getCategoriesForDepartment(
        departmentCode,
        storeCode,
      );
      return models.map((m) => m.toEntity()).toList(growable: false);
    });
  }

  @override
  Future<Result<List<domain.Subcategory>>> subcategories(String categoryCode) {
    return guard(() async {
      final models = await _subcategoryRepository.getSubcategories(categoryCode);
      return models.map((m) => m.toEntity()).toList(growable: false);
    });
  }

  @override
  Future<Result<void>> clearCache() {
    return guard(() async {
      // Both levels share a browse session, so clearing one without the other
      // leaves the taxonomy half-stale.
      await _categoryRepository.clearCache();
      await _subcategoryRepository.clearCache();
    });
  }
}
