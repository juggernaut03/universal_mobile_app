// lib/presentation/providers/subcategory_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../data/models/subcategory_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/subcategory_repository.dart';
import '../../data/repositories/product_repository.dart';
import 'launch_flow_provider.dart';

// Cache manager provider (reuse from category providers if available)
final subcategoryCacheManagerProvider = Provider<DefaultCacheManager>((ref) {
  return DefaultCacheManager();
});

// Repository providers with cache manager
final subcategoryRepositoryProvider = Provider<SubcategoryRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  final cacheManager = ref.watch(subcategoryCacheManagerProvider);
  
  return SubcategoryRepository(
    logger: logger,
    cacheManager: cacheManager,
  );
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  final cacheManager = ref.watch(subcategoryCacheManagerProvider);
  
  return ProductRepository(
    logger: logger,
    cacheManager: cacheManager,
  );
});

// Provider to force refresh subcategories and products (ignoring cache)
final refreshSubcategoryProvider = StateProvider<bool>((ref) => false);

// Subcategories provider with refresh capability
final subcategoriesProvider = FutureProvider.family<List<SubcategoryModel>, String>((ref, categoryId) async {
  final repository = ref.watch(subcategoryRepositoryProvider);
  final forceRefresh = ref.watch(refreshSubcategoryProvider);
  
  // If force refresh is true, clear cache before fetching
  if (forceRefresh) {
    await repository.clearCache();
    // Don't reset the flag yet, as products might still need to refresh
  }
  
  return repository.getSubcategories(categoryId);
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

// Products provider with refresh capability
final productsProvider = FutureProvider.family<List<ProductModel>, ProductFilterParams>((ref, params) async {
  final repository = ref.watch(productRepositoryProvider);
  final forceRefresh = ref.watch(refreshSubcategoryProvider);
  
  // If force refresh is true, clear cache before fetching
  if (forceRefresh) {
    await repository.clearCache();
    // Now reset the refresh flag since all data has been refreshed
    ref.read(refreshSubcategoryProvider.notifier).state = false;
  }
  
  return repository.getProducts(
    deptId: params.deptId,
    categoryId: params.categoryId,
    subCategoryId: params.subCategoryId,
    storeCode: params.storeCode,
  );
});

// All products provider (subCategoryId = "0" for all products in a category)
final allProductsProvider = FutureProvider.family<List<ProductModel>, ProductFilterParams>((ref, params) async {
  final repository = ref.watch(productRepositoryProvider);
  final forceRefresh = ref.watch(refreshSubcategoryProvider);
  
  // If force refresh is true, clear cache before fetching
  if (forceRefresh) {
    await repository.clearCache();
    ref.read(refreshSubcategoryProvider.notifier).state = false;
  }
  
  return repository.getProducts(
    deptId: params.deptId,
    categoryId: params.categoryId,
    subCategoryId: "0", // "0" means all products in the category
    storeCode: params.storeCode,
  );
});

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
    default:
      // Keep original order
      break;
  }
  
  return sortedProducts;
});