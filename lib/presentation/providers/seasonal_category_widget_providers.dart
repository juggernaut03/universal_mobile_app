// lib/presentation/providers/seasonal_category_widget_providers.dart
//
// Seasonal category strip. Types and providers moved out of the widget file.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/popular_category_models.dart';
import '../../di/repository_providers.dart';
import 'outlet_provider.dart';

/// Model for seasonal category data
class SeasonalCategory {
  final String id;
  final String categoryId;
  final String categoryName;
  final String deptId;
  final int sequenceId;
  final String storeCode;
  final String noOfCol;
  final String imageLink;

  SeasonalCategory({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.deptId,
    required this.sequenceId,
    required this.storeCode,
    required this.noOfCol,
    required this.imageLink,
  });

  factory SeasonalCategory.fromJson(Map<String, dynamic> json) {
    return SeasonalCategory(
      id: json['_id'] ?? '',
      categoryId: json['idcategory_master'] ?? '',
      categoryName: json['category_name'] ?? '',
      deptId: json['dept_id'] ?? '',
      sequenceId: int.tryParse(json['sequence_id']?.toString() ?? '0') ?? 0,
      storeCode: json['store_code'] ?? '',
      noOfCol: json['no_of_col'] ?? '4',
      imageLink: json['image_link'] ?? '',
    );
  }
}

/// Updated response model for the API including background color
class SeasonalCategoryResponse {
  final String title;
  final String categoryBgColor;
  final List<SeasonalCategory> categories;

  SeasonalCategoryResponse({
    required this.title,
    required this.categoryBgColor,
    required this.categories,
  });

  factory SeasonalCategoryResponse.fromJson(Map<String, dynamic> json) {
    return SeasonalCategoryResponse(
      title: json['title'] ?? '',  // Use empty string fallback - title should only come from API
      categoryBgColor: json['category_bg_color'] ?? '#FFFFFF',
      categories: (json['categories_details'] as List<dynamic>? ?? [])
          .map((item) => SeasonalCategory.fromJson(item))
          .toList(),
    );
  }

  /// This strip is section 1 of the popular-categories response, so it reuses
  /// that model rather than re-parsing the same payload.
  factory SeasonalCategoryResponse.fromPopular(PopularCategoryResponse popular) {
    return SeasonalCategoryResponse(
      title: popular.title,
      categoryBgColor: popular.categoryBgColor,
      categories: popular.categoriesDetails
          .map((item) => SeasonalCategory(
                id: item.id,
                categoryId: item.categoryId,
                categoryName: item.categoryName,
                deptId: item.deptId,
                sequenceId: item.sequenceId,
                storeCode: item.storeCode,
                noOfCol: item.numberOfColumns,
                imageLink: item.imageLink,
              ))
          .toList(),
    );
  }
}

/// Parameters for the provider
class SeasonalCategoryParams {
  final String storeCode;
  final int departmentId;

  SeasonalCategoryParams({
    required this.storeCode,
    required this.departmentId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeasonalCategoryParams &&
        other.storeCode == storeCode &&
        other.departmentId == departmentId;
  }

  @override
  int get hashCode => storeCode.hashCode ^ departmentId.hashCode;
}

final refreshSeasonalCategoryProvider = StateProvider<bool>((ref) => false);

/// Loading state provider for seasonal categories - prevents shuffling during refresh
final seasonalCategoryLoadingProvider = StateProvider<bool>((ref) => false);

/// Riverpod provider for seasonal categories with refresh capability.
///
/// Goes through PopularCategoryRepository rather than issuing its own request:
/// this strip is section 1 of `/popular-categories/list`, the same call the
/// home screen's other four strips make.
final seasonalCategoryProvider = FutureProvider.family<SeasonalCategoryResponse, SeasonalCategoryParams>((ref, params) async {
  // Use ref.read (NOT ref.watch) to avoid an infinite rebuild loop:
  // if we watch this flag and then reset it inside the async body,
  // the provider would detect the state change and restart itself endlessly.
  final forceRefresh = ref.read(refreshSeasonalCategoryProvider);

  final popular = await ref.watch(popularCategoryRepositoryProvider).getPopularCategories(
        sectionId: 1,
        departmentId: params.departmentId.toString(),
        storeCode: params.storeCode,
        forceRefresh: forceRefresh,
      );

  return SeasonalCategoryResponse.fromPopular(popular);
  // Flag reset is handled externally by seasonalCategoryRefreshProvider.finally
});

/// Provider for controlling pull-to-refresh functionality
/// Implements the "clear state before fetch" pattern to prevent shuffling
final seasonalCategoryRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // 1. Set loading state FIRST to show loader immediately (prevents shuffling)
    ref.read(seasonalCategoryLoadingProvider.notifier).state = true;

    // 2. Set the refresh flag to trigger fresh API call
    ref.read(refreshSeasonalCategoryProvider.notifier).state = true;

    try {
      // 3. Get the current outlet to determine params
      final outletAsync = ref.read(selectedOutletProvider);

      final outlet = outletAsync.valueOrNull;
      if (outlet != null) {
        final params = SeasonalCategoryParams(
          storeCode: outlet.storeCode,
          departmentId: 2, // default department ID
        );
        // 4. Actually await the network fetch so RefreshIndicator completes correctly
        final refreshFuture = ref.refresh(seasonalCategoryProvider(params).future);
        await refreshFuture;
      } else {
        // No outlet yet — just wait a short moment then reset
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {
      // Swallow errors so the refresh chain doesn't break
    } finally {
      // 5. Reset both flags after refresh completes or fails
      ref.read(refreshSeasonalCategoryProvider.notifier).state = false;
      ref.read(seasonalCategoryLoadingProvider.notifier).state = false;
    }
  };
});
