// lib/presentation/providers/seasonal_category_widget_providers.dart
//
// Seasonal category strip. Types and providers moved out of the widget file.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../di/infrastructure_providers.dart';

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
}

/// API service for fetching seasonal categories
class SeasonalCategoryApi {
  static String get baseUrl => ApiConstants.baseUrl;
  static String get projectCode => ApiConstants.projectCode;
  
  static Future<SeasonalCategoryResponse> fetchSeasonalCategories({
    required String storeCode,
    required int departmentId,
    bool forceRefresh = false,
  }) async {
    try {
      // Universal backend: section 1 of POST /api/popular-categories/list
      // replaces the legacy get_popular_category_list_1 endpoint.
      final response = await http.post(
        Uri.parse(ApiConstants.popularCategoriesList),
        headers: {
          'Content-Type': 'application/json',
          'X-Project-Code': projectCode,
        },
        body: jsonEncode({
          'store_code': storeCode,
          'project_code': projectCode,
          'include_inactive': false,
          'enrich_subcategories': true,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final sections = decoded is Map ? (decoded['data'] as List? ?? []) : [];

        Map<String, dynamic>? section;
        for (final s in sections) {
          if (s is Map<String, dynamic> && s['sequence'] == 1) {
            section = s;
            break;
          }
        }
        section ??= sections.isNotEmpty && sections.first is Map<String, dynamic>
            ? sections.first as Map<String, dynamic>
            : null;

        final items = <Map<String, dynamic>>[];
        if (section != null && section['subcategories'] is List) {
          for (final item in section['subcategories'] as List) {
            if (item is! Map) continue;
            final sub = item['subcategory_details'] is Map
                ? item['subcategory_details'] as Map
                : {};
            final cat = item['category_details'] is Map
                ? item['category_details'] as Map
                : {};
            items.add({
              'idcategory_master':
                  (cat['idcategory_master'] ?? sub['category_id'] ?? '').toString(),
              'dept_id': (cat['dept_id'] ?? '').toString(),
              'category_name':
                  (sub['sub_category_name'] ?? cat['category_name'] ?? '').toString(),
              'image_link': (item['image_link'] ?? '').toString(),
            });
          }
        }

        return SeasonalCategoryResponse.fromJson({
          'title': section?['title'] ?? '',
          'category_bg_color': section?['background_color'] ?? '#FFFFFF',
          'categories_details': items,
        });
      } else {
        throw Exception('Failed to load seasonal categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
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

/// Riverpod provider for seasonal categories with refresh capability
final seasonalCategoryProvider = FutureProvider.family<SeasonalCategoryResponse, SeasonalCategoryParams>((ref, params) async {
  // Use ref.read (NOT ref.watch) to avoid an infinite rebuild loop:
  // if we watch this flag and then reset it inside the async body,
  // the provider would detect the state change and restart itself endlessly.
  final forceRefresh = ref.read(refreshSeasonalCategoryProvider);

  return SeasonalCategoryApi.fetchSeasonalCategories(
    storeCode: params.storeCode,
    departmentId: params.departmentId,
    forceRefresh: forceRefresh,
  );
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
