import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Add this import for GoRouter
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';

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

/// API service for fetching seasonal data
class SeasonalApi {
  final String baseUrl = 'https://newtech.shalviadvision.com/api';
  final String projectCode = 'RET5890';
  final http.Client client;

  SeasonalApi({http.Client? client}) : client = client ?? http.Client();

  /// Fetch the seasonal banner
  Future<List<SeasonalBanner>> getBanner(String storeCode) async {
    final response = await client.post(
      Uri.parse('$baseUrl/get_banner'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'banner_type_id': 10,
        'store_code': storeCode,
        'platform': 'Android',
        'project_code': projectCode,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SeasonalBanner.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load banner');
    }
  }

  /// Fetch the seasonal categories
  Future<List<SeasonalCategory>> getCategories(String storeCode) async {
    final response = await client.post(
      Uri.parse('$baseUrl/get_seasonal_picks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'store_code': storeCode,
        'project_code': projectCode,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SeasonalCategory.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }
}

/// Provider for the API service
final seasonalApiProvider = Provider<SeasonalApi>((ref) => SeasonalApi());

/// Provider for the banner data
final bannerProvider = FutureProvider.family<List<SeasonalBanner>, String>((ref, storeCode) async {
  final api = ref.watch(seasonalApiProvider);
  return api.getBanner(storeCode);
});

/// Provider for the category data
final categoriesProvider = FutureProvider.family<List<SeasonalCategory>, String>((ref, storeCode) async {
  final api = ref.watch(seasonalApiProvider);
  return api.getCategories(storeCode);
});

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
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
  
  /// Build the banner image
  Widget _buildBanner(BuildContext context, WidgetRef ref, String storeCode) {
    final bannerAsync = ref.watch(bannerProvider(storeCode));
    
    return bannerAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox();
        
        return CachedNetworkImage(
          imageUrl: banners.first.imageUrl,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          placeholder: (_, __) => const SizedBox(height: 100),
          errorWidget: (_, __, ___) => const SizedBox(),
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox(),
    );
  }
  
  /// Build the horizontal category list
  Widget _buildCategories(BuildContext context, WidgetRef ref, String storeCode) {
    final categoriesAsync = ref.watch(categoriesProvider(storeCode));
    
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemBuilder: (context, index) {
              final category = categories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: GestureDetector(
                  onTap: () => _navigateToCategory(context, category),
                  child: CachedNetworkImage(
                    imageUrl: category.imageUrl,
                    width: 180, 
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox(),
    );
  }
  
  /// Navigate to the category details screen using GoRouter
  void _navigateToCategory(BuildContext context, SeasonalCategory category) {
    // Use context.push() instead of Navigator.pushNamed() to match GoRouter navigation
    context.push(
      '/subcategory/${category.categoryId}/${category.departmentId}/${Uri.encodeComponent(category.categoryName)}',
    );
  }
}