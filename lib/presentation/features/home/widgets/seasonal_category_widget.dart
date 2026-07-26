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
import '../../../../core/constants/app_constants.dart';
import '../../../providers/seasonal_category_widget_providers.dart';




/// Utility function to convert hex color string to Color
Color hexToColor(String hexString) {
  try {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return Colors.white; // Fallback color
  }
}




/// Main seasonal category widget with horizontal scrolling and pull-to-refresh
class SeasonalCategoryWidget extends ConsumerWidget {
  final int departmentId;
  final double itemWidth;
  final double itemHeight;
  final bool showTitle;
  final bool showViewAll;
  final EdgeInsets padding;
  final String? titleOverride;
  final double spacing;
  final bool enablePullToRefresh;
  final double imageHeight;

  const SeasonalCategoryWidget({
    super.key,
    this.departmentId = 2, // Default department ID from your example
    this.itemWidth = 120,
    this.itemHeight = 120,
    this.showTitle = true,
    this.titleOverride,
    this.showViewAll = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 12,
    this.enablePullToRefresh = true,
    this.imageHeight = 80,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check loading state first - prevents shuffling during refresh
    final isLoading = ref.watch(seasonalCategoryLoadingProvider);
    
    // Show loading immediately if refreshing (prevents showing stale data)
    if (isLoading) {
      return _buildLoadingState();
    }
    
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

  /// Build the main category section with background color from API
  Widget _buildCategorySection(BuildContext context, SeasonalCategoryResponse response) {
    if (response.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final backgroundColor = hexToColor(response.categoryBgColor);
    final displayTitle = titleOverride ?? response.title;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show title if showTitle is enabled AND title is not empty
          if (showTitle && displayTitle.isNotEmpty) _buildSectionHeader(context, displayTitle),
          
          // Horizontal scrolling categories
          _buildHorizontalCategories(context, response.categories),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Build section header with title and optional view all button
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: padding.add(const EdgeInsets.only(top: 16)),
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
          return _buildCategoryItem(context, category);
        },
      ),
    );
  }

  /// Build individual category item with consistent card dimensions
  Widget _buildCategoryItem(BuildContext context, SeasonalCategory category) {
    return GestureDetector(
      onTap: () => _handleCategoryTap(context, category),
      child: SizedBox(
        width: itemWidth,
        height: itemHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Card-shaped image with fixed dimensions
            _buildCardImage(category),
            
            const SizedBox(height: 8),
            
            // Category name with fixed height container
            _buildCategoryName(category),
          ],
        ),
      ),
    );
  }

  /// Build card-shaped category image with consistent dimensions
  Widget _buildCardImage(SeasonalCategory category) {
    return Container(
      width: imageHeight,
      height: imageHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: category.imageLink,
          fit: BoxFit.cover,
          width: imageHeight,
          height: imageHeight,
          placeholder: (context, url) => Container(
            width: imageHeight,
            height: imageHeight,
            color: Colors.grey[50],
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
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
            width: imageHeight,
            height: imageHeight,
            color: Colors.grey[50],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  'No image',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 8,
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
    return Text(
      category.categoryName,
      key: ValueKey('seasonal_cat_name_${category.id}'), // Prevents widget recycling issues
      style: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          if (showTitle)
            Padding(
              padding: padding.add(const EdgeInsets.only(top: 16)),
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
              itemBuilder: (context, index) => _buildLoadingItem(),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Build individual loading item with consistent dimensions
  Widget _buildLoadingItem() {
    return SizedBox(
      width: itemWidth,
      height: itemHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Card-shaped image placeholder
          Container(
            width: imageHeight,
            height: imageHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Text placeholder with fixed height
          Container(
            width: itemWidth * 0.8,
            height: 32, // Match the category name height
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
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


