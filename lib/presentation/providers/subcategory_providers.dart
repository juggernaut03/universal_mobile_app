// lib/presentation/providers/subcategory_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../core/result/result.dart';
import '../../di/product_providers.dart';
import '../../domain/usecases/product/get_products.dart';
import '../../di/catalogue_providers.dart';
import '../../domain/entities/catalogue.dart';
import '../../domain/usecases/catalogue/get_subcategories.dart';

// Cache manager provider (reuse from category providers if available)

// Repository providers with cache manager

// productRepositoryProvider used to be declared here — a product dependency
// living in the subcategory feature's provider file. It is now wired in
// lib/di/product_providers.dart, typed to the domain interface.

// Provider to force refresh subcategories and products (ignoring cache)
final refreshSubcategoryProvider = StateProvider<bool>((ref) => false);

// Subcategories provider with refresh capability
final subcategoriesProvider =
    FutureProvider.family<List<Subcategory>, String>((ref, categoryId) async {
  // The refresh flag is deliberately not reset here — products still need to
  // see it before it clears.
  if (ref.watch(refreshSubcategoryProvider)) {
    await ref.read(catalogueRepositoryProvider).clearCache();
  }

  final result = await ref.watch(getSubcategoriesUseCaseProvider)(
    GetSubcategoriesParams(categoryCode: categoryId),
  );
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw Exception(failure.userMessage),
  };
});

// Product filter parameters
class ProductFilterParams {
  final String deptId;
  final String categoryId;
  final String subCategoryId;
  final String storeCode;

  ProductFilterParams({
    required this.deptId,
    required this.categoryId,
    required this.subCategoryId,
    required this.storeCode,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductFilterParams &&
        other.deptId == deptId &&
        other.categoryId == categoryId &&
        other.subCategoryId == subCategoryId &&
        other.storeCode == storeCode;
  }

  @override
  int get hashCode => 
      deptId.hashCode ^ 
      categoryId.hashCode ^ 
      subCategoryId.hashCode ^ 
      storeCode.hashCode;
}


/// Runs the GetProducts use case and adapts the result for callers that still
/// expect `List<ProductModel>`.
///
/// TODO(phase-4): the catalogue screens still consume ProductModel because
/// `product_item_widget` hands the model straight to
/// `cartProvider.addItemWithQuantity`, and CartItem holds a ProductModel until
/// Phase 5. Once cart is migrated, these providers expose `List<Product>` and
/// this adapter is deleted.
Future<List<ProductModel>> _runGetProducts(
  Ref ref,
  ProductFilterParams params, {
  required String subCategoryId,
}) async {
  final forceRefresh = ref.watch(refreshSubcategoryProvider);
  if (forceRefresh) {
    await ref.read(productRepositoryProvider).clearCache();
    ref.read(refreshSubcategoryProvider.notifier).state = false;
  }

  final result = await ref.watch(getProductsUseCaseProvider)(
    GetProductsParams(
      storeCode: params.storeCode,
      departmentId: params.deptId,
      categoryId: params.categoryId,
      subCategoryId: subCategoryId,
    ),
  );

  // FutureProvider models failure as a thrown error, so the Err branch rethrows
  // to preserve the existing AsyncValue.error handling in the screens. The
  // failure keeps its type all the way here, unlike the previous `null`.
  return switch (result) {
    Ok(:final value) => value.map(ProductModel.fromEntity).toList(),
    Err(:final failure) => throw Exception(failure.userMessage),
  };
}

// Products provider with refresh capability
final productsProvider =
    FutureProvider.family<List<ProductModel>, ProductFilterParams>(
  (ref, params) => _runGetProducts(ref, params,
      subCategoryId: params.subCategoryId),
);

// All products provider ("0" means every product in the category)
final allProductsProvider =
    FutureProvider.family<List<ProductModel>, ProductFilterParams>(
  (ref, params) => _runGetProducts(ref, params, subCategoryId: '0'),
);

// Provider for controlling pull-to-refresh functionality
final subcategoryRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true
    ref.read(refreshSubcategoryProvider.notifier).state = true;
  };
});

// Sort options for products
enum SortOption {
  none,
  priceLowToHigh,
  priceHighToLow,
  // Add more options as needed (e.g., newest, popularity)
}

// Provider to store the current sort option
final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.none);

// Provider that returns sorted products based on the current sort option
final sortedProductsProvider = Provider.family<List<ProductModel>, List<ProductModel>>((ref, products) {
  final sortOption = ref.watch(sortOptionProvider);
  
  // Create a copy of the list to avoid modifying the original
  final sortedProducts = List<ProductModel>.from(products);
  
  switch (sortOption) {
    case SortOption.priceLowToHigh:
      sortedProducts.sort((a, b) => a.ourPrice.compareTo(b.ourPrice));
      break;
    case SortOption.priceHighToLow:
      sortedProducts.sort((a, b) => b.ourPrice.compareTo(a.ourPrice));
      break;
    case SortOption.none:
      // Keep original order
      break;
  }
  
  return sortedProducts;
});