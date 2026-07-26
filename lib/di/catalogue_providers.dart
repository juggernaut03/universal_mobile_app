// lib/di/catalogue_providers.dart
//
// Composition root — the catalogue slice (Phase 4).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/catalogue_repository_impl.dart';
import '../domain/repositories/i_catalogue_repository.dart';
import '../domain/usecases/catalogue/get_categories.dart';
import '../domain/usecases/catalogue/get_departments.dart';
import '../domain/usecases/catalogue/get_subcategories.dart';
import 'repository_providers.dart';

final catalogueRepositoryProvider = Provider<ICatalogueRepository>((ref) {
  return CatalogueRepositoryImpl(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    subcategoryRepository: ref.watch(subcategoryRepositoryProvider),
  );
});

final getDepartmentsUseCaseProvider = Provider<GetDepartments>(
  (ref) => GetDepartments(ref.watch(catalogueRepositoryProvider)),
);

final getCategoriesUseCaseProvider = Provider<GetCategories>(
  (ref) => GetCategories(ref.watch(catalogueRepositoryProvider)),
);

final getSubcategoriesUseCaseProvider = Provider<GetSubcategories>(
  (ref) => GetSubcategories(ref.watch(catalogueRepositoryProvider)),
);
