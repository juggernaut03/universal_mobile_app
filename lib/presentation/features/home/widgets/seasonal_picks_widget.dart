// lib/presentation/features/home/widgets/seasonal_picks_widget.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import '../../../../core/constants/app_constants.dart';

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




/// The main seasonal picks widget
class SeasonalPicksWidget extends ConsumerWidget {
  const SeasonalPicksWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current outlet to determine store code
    final outletAsync = ref.watch(selectedOutletProvider);
    
    return outletAsync.when(
      data: (outlet) {
        if (outlet == null) return const SizedBox();
        
        final storeCode = outlet.storeCode;
        
        return Column(
          children: [
            // Banner section
            _buildBanner(context, ref, storeCode),
            
            // Categories section
            _buildCategories(context, ref, storeCode),
          ],
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stackTrace) => _buildErrorState(context, error),
    );
  }
  
  /// Build the banner image
  Widget _buildBanner(BuildContext context, WidgetRef ref, String storeCode) {
    final bannerAsync = ref.watch(bannerProvider(storeCode));
    
    return bannerAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: banners.first.imageUrl,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, __) => Container(
                height: 120,
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 120,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.error_outline, color: Colors.grey),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.grey),
        ),
      ),
    );
  }
  
  /// Build the horizontal category list - FIXED VERSION
  Widget _buildCategories(BuildContext context, WidgetRef ref, String storeCode) {
    final categoriesAsync = ref.watch(categoriesProvider(storeCode));
    
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          height: 200, // Reduced height since no text needed
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryItem(context, category, index == 0, index == categories.length - 1);
            },
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5, // Show placeholder items
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            return Container(
              width: 140,
              margin: EdgeInsets.only(
                right: 12,
                left: index == 0 ? 0 : 0,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
      ),
      error: (error, _) => Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.grey[400], size: 24),
              const SizedBox(height: 8),
              Text(
                'Failed to load categories',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build individual category item - IMAGE ONLY VERSION
  Widget _buildCategoryItem(BuildContext context, SeasonalCategory category, bool isFirst, bool isLast) {
    return Container(
      width: 180, // Wider since we're only showing image
      margin: EdgeInsets.only(
        right: isLast ? 0 : 12,
        left: isFirst ? 0 : 0,
      ),
      child: InkWell(
        onTap: () {
          // Navigate to category
          if (category.categoryId.isNotEmpty && category.departmentId.isNotEmpty) {
            context.push('/subcategory/${category.categoryId}/${category.departmentId}/${Uri.encodeComponent(category.categoryName)}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: category.imageUrl,
            width: 180,
            height: 180, // Square aspect ratio for better display
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 180,
              height: 180,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 180,
              height: 180,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image_not_supported, color: Colors.grey, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build loading state
  Widget _buildLoadingState() {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading seasonal picks...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build error state
  Widget _buildErrorState(BuildContext context, Object error) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 24),
            const SizedBox(height: 8),
            Text(
              'Failed to load seasonal picks',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ],
        ),
      ),
    );
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
