// lib/presentation/widgets/popular_categories_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_constants.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';



// Model to represent a category
class PopularCategory {
  final String id;
  final String categoryId;
  final String categoryName;
  final String departmentId;
  final int sequenceId;
  final String storeCode;
  final String columnCount;
  final String imageUrl;

  PopularCategory({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.departmentId,
    required this.sequenceId,
    required this.storeCode,
    required this.columnCount,
    required this.imageUrl,
  });

  factory PopularCategory.fromJson(Map<String, dynamic> json) {
    return PopularCategory(
      id: json['_id'] ?? '',
      categoryId: json['idcategory_master'] ?? '',
      categoryName: json['category_name'] ?? '',
      departmentId: json['dept_id'] ?? '',
      sequenceId: json['sequence_id'] ?? 0,
      storeCode: json['store_code'] ?? '',
      columnCount: json['no_of_col'] ?? '2',
      imageUrl: json['image_link'] ?? '',
    );
  }
}

// Provider for the Category Service
final categoryServiceProvider = Provider<CategoryService>((ref) {
  final apiClient = ApiClient(logger: ref.watch(loggerProvider));
  final logger = ref.watch(loggerProvider);
  
  return CategoryService(
    apiClient: apiClient,
    logger: logger,
  );
});

// Provider for popular categories
final popularCategoriesProvider = FutureProvider<List<PopularCategory>>((ref) async {
  final selectedOutletAsync = ref.watch(selectedOutletProvider);
  
  return selectedOutletAsync.when(
    data: (outlet) async {
      if (outlet == null) {
        return [];
      }
      
      final categoryService = ref.read(categoryServiceProvider);
      return await categoryService.getPopularCategories(outlet.storeCode);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Service to fetch and manage popular categories
class CategoryService {
  final ApiClient _apiClient;
  final Logger _logger;
  
  // Constants for caching
  static const String _categoriesCacheKey = 'popular_categories';
  static const String _categoriesCacheTimestampKey = 'popular_categories_timestamp';
  static const Duration _cacheDuration = Duration(hours: 20);
  
  CategoryService({
    required ApiClient apiClient,
    required Logger logger,
  }) : 
    _apiClient = apiClient,
    _logger = logger;
  
  Future<List<PopularCategory>> getPopularCategories(String storeCode) async {
    try {
      // Check cache validity
      await _checkAndClearCacheIfNeeded();
      
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_categoriesCacheKey);
      final cachedTimestamp = prefs.getInt(_categoriesCacheTimestampKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDuration.inMilliseconds)) {
        _logger.log('Using cached popular categories data');
        
        // Parse cached categories
        final List<dynamic> decodedList = jsonDecode(cachedData);
        final List<PopularCategory> categories = decodedList
            .map((item) => PopularCategory.fromJson(item))
            .where((category) => category.storeCode == storeCode)
            .toList();
        
        // If we have categories for this store, return them
        if (categories.isNotEmpty) {
          return categories;
        }
      }
      
      // Fetch fresh categories from API
      _logger.log('Fetching popular categories from API for store: $storeCode');
      
      final body = {
        "department_id": 2,
        "store_code": storeCode,
        "project_code": ApiConstants.projectCode,
      };
      
      final response = await _apiClient.post(
        'https://newtech.shalviadvision.com/api/get_popular_category_list_1',
        body: body,
      );
      
      if (response is List) {
        final List<PopularCategory> categories = response
            .map((item) => PopularCategory.fromJson(item))
            .toList();
        
        // Cache the categories
        await prefs.setString(_categoriesCacheKey, jsonEncode(response));
        await prefs.setInt(_categoriesCacheTimestampKey, currentTime);
        
        return categories;
      } else {
        _logger.error('Unexpected response format: $response');
        return [];
      }
    } catch (e) {
      _logger.error('Error fetching popular categories: $e');
      return [];
    }
  }
  
  // Check if it's time to clear cache (2 AM daily)
  Future<void> _checkAndClearCacheIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastClearTime = prefs.getInt('last_categories_cache_clear_time') ?? 0;
      
      final now = DateTime.now();
      final lastClear = DateTime.fromMillisecondsSinceEpoch(lastClearTime);
      
      // Get today's 2 AM timestamp
      final todayTwoAm = DateTime(now.year, now.month, now.day, 2, 0, 0);
      
      // If current time is after 2 AM today and last clear was before 2 AM today
      if (now.isAfter(todayTwoAm) && lastClear.isBefore(todayTwoAm)) {
        _logger.log('Clearing categories cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt('last_categories_cache_clear_time', now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking cache clear schedule: $e');
    }
  }
  
  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_categoriesCacheKey);
      await prefs.remove(_categoriesCacheTimestampKey);
      
      _logger.log('Popular categories cache cleared');
    } catch (e) {
      _logger.error('Error clearing categories cache: $e');
    }
  }
}

// Popular Categories Widget
class PopularCategoriesWidget extends ConsumerWidget {
  final double? height;
  final double? imageSize;
  final EdgeInsets? padding;
  final int crossAxisCount;
  final bool showTitle;
  final String? title;
  final bool showViewAll;
  final VoidCallback? onViewAllTap;
  final double borderRadius;

  const PopularCategoriesWidget({
    Key? key,
    this.height,
    this.imageSize = 80,
    this.padding,
    this.crossAxisCount = 4,
    this.showTitle = true,
    this.title = 'Popular Categories',
    this.showViewAll = true,
    this.onViewAllTap,
    this.borderRadius = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(popularCategoriesProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (showViewAll)
                  TextButton(
                    onPressed: onViewAllTap ?? () => context.go('/category'),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return _buildEmptyPlaceholder();
            }
            
            return _buildCategoriesGrid(context, categories);
          },
          loading: () => _buildLoadingIndicator(),
          error: (_, __) => _buildErrorPlaceholder(),
        ),
      ],
    );
  }
  
Widget _buildCategoriesGrid(BuildContext context, List<PopularCategory> categories) {
    // Determine how many categories to display
    final displayCategories = categories.take(8).toList();
    
    // Calculate the item height based on available space
    // This ensures we don't overflow
    return SizedBox(
      height: height,
      child: GridView.builder(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,  // Reduced from 16 to save space
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,  // Adjusted to make cells taller relative to width
        ),
        itemCount: displayCategories.length,
        itemBuilder: (context, index) {
          final category = displayCategories[index];
          return _buildCategoryItem(context, category);
        },
      ),
    );
  }
  
 Widget _buildCategoryItem(BuildContext context, PopularCategory category) {
    // Calculate sizes based on constraints to avoid overflow
    final availableImageSize = imageSize != null ? imageSize! : 70.0;
    
    return GestureDetector(
      onTap: () {
        context.push('/subcategory/${category.categoryId}/${category.departmentId}/${category.categoryName}');
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,  // Use minimum space needed
        children: [
          // Category image in rounded container
          Container(
            width: availableImageSize,
            height: availableImageSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: CachedNetworkImage(
                imageUrl: category.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.image,
                    color: Colors.grey[400],
                    size: 32,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey[400],
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          
          // Category name - constrained height to prevent overflow
          Flexible(
            child: Container(
              padding: const EdgeInsets.only(top: 4.0),  // Reduced from 8
              constraints: const BoxConstraints(minHeight: 0, maxHeight: 40),
              child: Text(
                _formatCategoryName(category.categoryName),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11, // Smaller font size to fit better
                ),
              ),
            ),
          ),
        ],
      ),
    );
 }
  // Format category name to title case and handle special characters
  String _formatCategoryName(String name) {
    if (name.isEmpty) return "";
    
    // Convert from uppercase to title case if needed
    if (name == name.toUpperCase()) {
      return name.split(' ').map((word) {
        if (word.length > 1) {
          return word[0] + word.substring(1).toLowerCase();
        }
        return word;
      }).join(' ');
    }
    
    // Replace special characters like "_" and "&amp;" with friendly versions
    return name.replaceAll('_', ' ').replaceAll('&amp;', '&');
  }
  
  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
  
  Widget _buildEmptyPlaceholder() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Text(
          'No categories available',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
  
  Widget _buildErrorPlaceholder() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[300],
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load categories',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}