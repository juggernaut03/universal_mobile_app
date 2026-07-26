// lib/presentation/providers/seasonal_picks_widget_providers.dart
//
// Seasonal picks strip. Types and providers moved out of the widget file.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../di/infrastructure_providers.dart';
import 'outlet_provider.dart';

/// A simple model for the seasonal banner data
class SeasonalBanner {
  final String imageUrl;

  SeasonalBanner({required this.imageUrl});

  factory SeasonalBanner.fromJson(Map<String, dynamic> json) {
    return SeasonalBanner(
      imageUrl: json['banner_img'] ?? '',
    );
  }
}

/// A simple model for seasonal category data
class SeasonalCategory {
  final String categoryId;
  final String departmentId;
  final String categoryName;
  final String imageUrl;

  SeasonalCategory({
    required this.categoryId,
    required this.departmentId,
    required this.categoryName,
    required this.imageUrl,
  });

  factory SeasonalCategory.fromJson(Map<String, dynamic> json) {
    return SeasonalCategory(
      categoryId: json['idcategory_master'] ?? '',
      departmentId: json['dept_id'] ?? '',
      categoryName: json['category_name'] ?? '',
      imageUrl: json['image_link'] ?? '',
    );
  }
}

/// Enhanced API service for fetching seasonal data with refresh capability.
/// Both the banner and the category tiles come from the universal backend's
/// POST /api/seasonal-categories/list sections.
class SeasonalApi {
  final String baseUrl = ApiConstants.baseUrl;
  final String projectCode = ApiConstants.projectCode;
  final http.Client client;

  SeasonalApi({http.Client? client}) : client = client ?? http.Client();

  Future<List<dynamic>> _fetchSections(String storeCode) async {
    final response = await client.post(
      Uri.parse(ApiConstants.seasonalCategoriesList),
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
      return decoded is Map ? (decoded['data'] as List? ?? []) : [];
    } else {
      throw Exception('Failed to load seasonal sections: ${response.statusCode}');
    }
  }

  /// Fetch the seasonal banner (from the first section's banner assets)
  Future<List<SeasonalBanner>> getBanner(String storeCode, {bool forceRefresh = false}) async {
    final sections = await _fetchSections(storeCode);
    final banners = <SeasonalBanner>[];
    for (final section in sections) {
      if (section is! Map) continue;
      final bannerUrls = section['banner_urls'] is Map
          ? section['banner_urls'] as Map
          : {};
      final imageUrl =
          (bannerUrls['mobile'] ?? bannerUrls['desktop'] ?? '').toString();
      if (imageUrl.isNotEmpty) {
        banners.add(SeasonalBanner(imageUrl: imageUrl));
        break; // one banner, as with the legacy widget
      }
    }
    return banners;
  }

  /// Fetch the seasonal categories (tiles) from the enriched sections
  Future<List<SeasonalCategory>> getCategories(String storeCode, {bool forceRefresh = false}) async {
    final sections = await _fetchSections(storeCode);
    final categories = <SeasonalCategory>[];
    for (final section in sections) {
      if (section is! Map) continue;
      final subcategories = section['subcategories'];
      if (subcategories is! List) continue;
      for (final item in subcategories) {
        if (item is! Map) continue;
        final sub = item['subcategory_details'] is Map
            ? item['subcategory_details'] as Map
            : {};
        final cat = item['category_details'] is Map
            ? item['category_details'] as Map
            : {};
        categories.add(SeasonalCategory(
          categoryId:
              (cat['idcategory_master'] ?? sub['category_id'] ?? '').toString(),
          departmentId: (cat['dept_id'] ?? '').toString(),
          categoryName:
              (sub['sub_category_name'] ?? cat['category_name'] ?? '').toString(),
          imageUrl: (item['image_link'] ?? '').toString(),
        ));
      }
    }
    return categories;
  }

  /// Clear any internal caches
  void clearCache() {
    // Placeholder for future cache implementation
    // This could be used to clear HTTP client cache if implemented
  }
}

final seasonalApiProvider = Provider<SeasonalApi>((ref) => SeasonalApi());

/// Provider to force refresh seasonal picks data
final refreshSeasonalPicksProvider = StateProvider<bool>((ref) => false);

/// Provider for the banner data with refresh capability
final bannerProvider = FutureProvider.family<List<SeasonalBanner>, String>((ref, storeCode) async {
  final api = ref.watch(seasonalApiProvider);
  final forceRefresh = ref.watch(refreshSeasonalPicksProvider);
  
  return api.getBanner(storeCode, forceRefresh: forceRefresh);
});

/// Provider for the category data with refresh capability
final categoriesProvider = FutureProvider.family<List<SeasonalCategory>, String>((ref, storeCode) async {
  final api = ref.watch(seasonalApiProvider);
  final forceRefresh = ref.watch(refreshSeasonalPicksProvider);
  
  return api.getCategories(storeCode, forceRefresh: forceRefresh);
});

/// Provider for refreshing seasonal picks data
final seasonalPicksRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      // Set the refresh flag to true
      ref.read(refreshSeasonalPicksProvider.notifier).state = true;
      
      // Get the current outlet
      final outletAsync = ref.read(selectedOutletProvider);
      
      await outletAsync.when(
        data: (outlet) async {
          if (outlet != null) {
            // Refresh both providers
            await Future.wait([
              ref.refresh(bannerProvider(outlet.storeCode).future),
              ref.refresh(categoriesProvider(outlet.storeCode).future),
            ]);
          }
        },
        loading: () => Future.value(),
        error: (_, __) => Future.value(),
      );
      
      // Reset the refresh flag
      ref.read(refreshSeasonalPicksProvider.notifier).state = false;
    } catch (e) {
      // Reset the refresh flag even on error
      ref.read(refreshSeasonalPicksProvider.notifier).state = false;
      rethrow;
    }
  };
});
