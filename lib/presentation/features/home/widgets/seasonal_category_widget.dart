// lib/presentation/features/home/widgets/seasonal_category_widget.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

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

/// Response model for the API
class SeasonalCategoryResponse {
  final String title;
  final List<SeasonalCategory> categories;

  SeasonalCategoryResponse({
    required this.title,
    required this.categories,
  });

  factory SeasonalCategoryResponse.fromJson(Map<String, dynamic> json) {
    return SeasonalCategoryResponse(
      title: json['title'] ?? 'Popular Categories',
      categories: (json['categories_details'] as List<dynamic>? ?? [])
          .map((item) => SeasonalCategory.fromJson(item))
          .toList(),
    );
  }
}

/// API service for fetching seasonal categories
class SeasonalCategoryApi {
  static const String baseUrl = 'https://newtech.shalviadvision.com/api';
  static const String projectCode = 'RET5890';
  
  static Future<SeasonalCategoryResponse> fetchSeasonalCategories({
    required String storeCode,
    required int departmentId,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_popular_category_list_1'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'department_id': departmentId,
          'store_code': storeCode,
          'project_code': projectCode,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return SeasonalCategoryResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load seasonal categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

/// State provider to control force refresh
final refreshSeasonalCategoryProvider = StateProvider<bool>((ref) => false);

/// Riverpod provider for seasonal categories with refresh capability
final seasonalCategoryProvider = FutureProvider.family<SeasonalCategoryResponse, SeasonalCategoryParams>((ref, params) async {
  final forceRefresh = ref.watch(refreshSeasonalCategoryProvider);
  
  // If force refresh is true, we'll fetch fresh data
  final response = await SeasonalCategoryApi.fetchSeasonalCategories(
    storeCode: params.storeCode,
    departmentId: params.departmentId,
    forceRefresh: forceRefresh,
  );
  
  // Reset the refresh flag after successful fetch
  if (forceRefresh) {
    ref.read(refreshSeasonalCategoryProvider.notifier).state = false;
  }
  
  return response;
});

/// Provider for controlling pull-to-refresh functionality
final seasonalCategoryRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Set the refresh flag to true which will trigger a fresh API call
    ref.read(refreshSeasonalCategoryProvider.notifier).state = true;
  };
});

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

/// Main seasonal category widget with horizontal scrolling and pull-to-refresh
class SeasonalCategoryWidget extends ConsumerWidget {
  final int departmentId;
  final double itemWidth;
  final double itemHeight;
  final bool showTitle;
  final bool showViewAll;
  final EdgeInsets padding;
  final double spacing;
  final bool enablePullToRefresh;

  const SeasonalCategoryWidget({
    Key? key,
    this.departmentId = 2, // Default department ID from your example
    this.itemWidth = 140,
    this.itemHeight = 160,
    this.showTitle = true,
    this.showViewAll = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 12,
    this.enablePullToRefresh = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current outlet to determine store code
    final outletAsync = ref.watch(selectedOutletProvider);
    
    return outletAsync.when(
      data: (outlet) {
        if (outlet == null) return const SizedBox.shrink();
        
        final params = SeasonalCategoryParams(
          storeCode: outlet.storeCode,
          departmentId: departmentId,
        );
        
        final categoriesAsync = ref.watch(seasonalCategoryProvider(params));
        
        return categoriesAsync.when(
          data: (response) => enablePullToRefresh 
              ? _buildWithRefresh(context, ref, response, params)
              : _buildCategorySection(context, response),
          loading: () => _buildLoadingState(),
          error: (error, stackTrace) => _buildErrorState(context, error, ref),
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stackTrace) => _buildErrorState(context, error, ref),
    );
  }

  /// Build wrapper with pull-to-refresh functionality
  Widget _buildWithRefresh(BuildContext context, WidgetRef ref, SeasonalCategoryResponse response, SeasonalCategoryParams params) {
    return RefreshIndicator(
      onRefresh: () async {
        final refreshFunction = ref.read(seasonalCategoryRefreshProvider);
        await refreshFunction();
        
        // Optional: Show a brief success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Categories refreshed successfully'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      color: AppColors.primary,
      backgroundColor: Colors.white,
      displacement: 40,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: _buildCategorySection(context, response),
      ),
    );
  }

  /// Build the main category section
  Widget _buildCategorySection(BuildContext context, SeasonalCategoryResponse response) {
    if (response.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with refresh button
          if (showTitle) _buildSectionHeader(context, response.title, ),
          
          // Horizontal scrolling categories
          _buildHorizontalCategories(context, response.categories),
        ],
      ),
    );
  }

  /// Build section header with title and optional view all button
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showViewAll)
            TextButton(
              onPressed: () {
                // Navigate to full category list
                // You can implement this based on your navigation structure
                debugPrint('Navigate to all categories');
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build horizontal scrolling category list
  Widget _buildHorizontalCategories(BuildContext context, List<SeasonalCategory> categories) {
    return Container(
      height: itemHeight + 20, // Extra space for text
      margin: const EdgeInsets.only(top: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: categories.length,
        separatorBuilder: (context, index) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  /// Build individual category card
  Widget _buildCategoryCard(BuildContext context, SeasonalCategory category) {
    return GestureDetector(
      onTap: () => _handleCategoryTap(context, category),
      child: Container(
        width: itemWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category image
            Expanded(
              child: _buildCategoryImage(category),
            ),
            
            // Category name
            _buildCategoryName(category),
          ],
        ),
      ),
    );
  }

  /// Build category image with caching and error handling
  Widget _buildCategoryImage(SeasonalCategory category) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: CachedNetworkImage(
          imageUrl: category.imageLink,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[100],
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[100],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  'Image not available',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build category name text
  Widget _buildCategoryName(SeasonalCategory category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Text(
        category.categoryName,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Handle category tap navigation
  void _handleCategoryTap(BuildContext context, SeasonalCategory category) {
    if (category.categoryId.isNotEmpty && category.deptId.isNotEmpty) {
      // Navigate to subcategory screen
      context.push(
        '/subcategory/${category.categoryId}/${category.deptId}/${Uri.encodeComponent(category.categoryName)}',
      );
    } else {
      // Show error or fallback behavior
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "${category.categoryName}" is not available'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Build loading state with shimmer effect
  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          if (showTitle)
            Padding(
              padding: padding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 150,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  if (showViewAll)
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          
          // Categories shimmer
          Container(
            height: itemHeight + 20,
            margin: const EdgeInsets.only(top: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: padding,
              itemCount: 5,
              separatorBuilder: (context, index) => SizedBox(width: spacing),
              itemBuilder: (context, index) => _buildLoadingCard(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual loading card
  Widget _buildLoadingCard() {
    return Container(
      width: itemWidth,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 40,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state with retry functionality
  Widget _buildErrorState(BuildContext context, Object error, WidgetRef ref) {
    return Container(
      height: showTitle ? 120 : 80,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: padding,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error.withOpacity(0.7),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load categories',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () async {
                final refreshFunction = ref.read(seasonalCategoryRefreshProvider);
                await refreshFunction();
              },
              child: Text(
                'Tap to retry',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}