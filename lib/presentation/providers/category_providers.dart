// lib/presentation/providers/category_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/network/api_client.dart';
import '../../data/models/department_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/outlet_model.dart';
import '../../data/repositories/category_repository.dart';
import 'launch_flow_provider.dart';
import 'outlet_provider.dart';

// Cache manager provider
final cacheManagerProvider = Provider<DefaultCacheManager>((ref) {
  return DefaultCacheManager();
});

// Enhanced repository provider with cache manager
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final cacheManager = ref.watch(cacheManagerProvider);
  
  return CategoryRepository(
    apiClient: apiClient,
    logger: ref.watch(loggerProvider),
    cacheManager: cacheManager,
  );
});

// Provider to force refresh categories (ignoring cache)
final refreshCategoriesProvider = StateProvider<bool>((ref) => false);

// All departments provider with refresh capability
final departmentsProvider = FutureProvider<List<DepartmentModel>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.watch(refreshCategoriesProvider);
  
  // If force refresh is true, clear cache before fetching
  if (forceRefresh) {
    await repository.clearCache();
    // Reset the refresh flag
    ref.read(refreshCategoriesProvider.notifier).state = false;
  }
  
  // Handle the AsyncValue properly
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      final departments = await repository.getDepartments(outlet.storeCode);
      
      // Ensure the first department is selected by default
      if (departments.isNotEmpty) {
        departments[0] = departments[0].copyWith(isSelected: true);
      }
      
      return departments;
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// Selected department provider
final selectedDepartmentProvider = StateProvider<DepartmentModel?>((ref) => null);

// Categories for selected department provider
final categoriesForDepartmentProvider = FutureProvider.family<List<CategoryModel>, String>((ref, departmentId) async {
  final repository = ref.watch(categoryRepositoryProvider);
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.watch(refreshCategoriesProvider);
  
  if (forceRefresh) {
    await repository.clearCache();
  }
  
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      return repository.getCategoriesForDepartment(departmentId, outlet.storeCode);
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// All categories grouped by department
final allCategoriesProvider = FutureProvider<Map<String, List<CategoryModel>>>((ref) async {
  final outletAsync = ref.watch(selectedOutletProvider);
  final forceRefresh = ref.watch(refreshCategoriesProvider);
  
  return outletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        throw Exception('No store selected');
      }
      
      final departments = await ref.watch(departmentsProvider.future);
      final repository = ref.watch(categoryRepositoryProvider);
      
      // Clear cache if force refresh
      if (forceRefresh) {
        await repository.clearCache();
        ref.read(refreshCategoriesProvider.notifier).state = false;
      }
      
      final Map<String, List<CategoryModel>> result = {};
      
      for (final department in departments) {
        final categories = await repository.getCategoriesForDepartment(
          department.departmentId, 
          outlet.storeCode
        );
        result[department.departmentId] = categories;
      }
      
      return result;
    },
    loading: () => throw Exception('Loading outlet information...'),
    error: (error, stackTrace) => throw Exception('Error loading outlet: $error'),
  );
});

// Provider for controlling pull-to-refresh functionality
final categoryRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true
    ref.read(refreshCategoriesProvider.notifier).state = true;
    // Refresh the departments provider which will trigger a cache clear
    await ref.refresh(departmentsProvider.future);
    // Refresh the all categories provider
    await ref.refresh(allCategoriesProvider.future);
  };
});