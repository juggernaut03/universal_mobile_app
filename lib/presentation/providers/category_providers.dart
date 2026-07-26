// lib/presentation/providers/category_providers.dart
//
// Browse-taxonomy state. All data now arrives as domain entities through the
// catalogue use cases; nothing here touches data/ or a repository directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result/result.dart';
import '../../di/catalogue_providers.dart';
import '../../domain/entities/catalogue.dart';
import '../../domain/usecases/catalogue/get_categories.dart';
import '../../domain/usecases/catalogue/get_departments.dart';
import 'outlet_provider.dart';

// Provider to force refresh categories (ignoring cache)
final refreshCategoriesProvider = StateProvider<bool>((ref) => false);

/// Store code of the selected outlet, or null while none is chosen.
///
/// Extracted so the providers below stop repeating the same
/// `outletAsync.when(...)` block, which threw a differently-worded `Exception`
/// from each copy.
String? _selectedStoreCode(Ref ref) =>
    ref.watch(selectedOutletProvider).valueOrNull?.storeCode;

Future<void> _clearCacheIfRequested(Ref ref) async {
  if (!ref.watch(refreshCategoriesProvider)) return;
  await ref.read(catalogueRepositoryProvider).clearCache();
  ref.read(refreshCategoriesProvider.notifier).state = false;
}

/// Departments carried by the selected store, filtered and ordered.
///
/// The previous version reassigned `departments[0]` to mark it selected —
/// writing UI selection state into shared data. Selection now lives in
/// [selectedDepartmentCodeProvider].
final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  final storeCode = _selectedStoreCode(ref);
  if (storeCode == null) throw Exception('No store selected');

  await _clearCacheIfRequested(ref);

  final result = await ref.watch(getDepartmentsUseCaseProvider)(
    GetDepartmentsParams(storeCode: storeCode),
  );
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw Exception(failure.userMessage),
  };
});

/// The department the user is browsing, by code. Presentation state.
final selectedDepartmentCodeProvider = StateProvider<String?>((ref) => null);

/// Categories grouped by department code.
final allCategoriesProvider =
    FutureProvider<Map<String, List<Category>>>((ref) async {
  final storeCode = _selectedStoreCode(ref);
  if (storeCode == null) throw Exception('No store selected');

  final departments = await ref.watch(departmentsProvider.future);
  final getCategories = ref.watch(getCategoriesUseCaseProvider);

  // TODO(phase-4-followup): one request per department. The backend exposes no
  // bulk endpoint, so this stays sequential for now, but it is the slowest
  // thing on the category screen.
  final result = <String, List<Category>>{};
  for (final department in departments) {
    final categories = await getCategories(
      GetCategoriesParams(
        departmentCode: department.code,
        storeCode: storeCode,
      ),
    );
    // A department whose categories fail to load renders empty rather than
    // failing the whole screen.
    result[department.code] = categories.valueOrNull ?? const [];
  }
  return result;
});

/// Loading state for category refresh — prevents shuffling during refresh.
final categoryRefreshLoadingProvider = StateProvider<bool>((ref) => false);

/// Pull-to-refresh entry point. Clears state before fetching so the list does
/// not shuffle while new data arrives.
final categoryRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.read(categoryRefreshLoadingProvider.notifier).state = true;
    try {
      ref.read(refreshCategoriesProvider.notifier).state = true;
      // ignore: unused_result — awaited for completion; the value is not needed.
      await ref.refresh(departmentsProvider.future);
      // ignore: unused_result — awaited for completion; the value is not needed.
      await ref.refresh(allCategoriesProvider.future);
    } finally {
      ref.read(categoryRefreshLoadingProvider.notifier).state = false;
    }
  };
});
