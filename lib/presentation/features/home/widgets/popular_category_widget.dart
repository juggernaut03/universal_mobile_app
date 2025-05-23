// lib/presentation/features/home/widgets/popular_category_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/core/widgets/cached_network_image_widget.dart';
import 'package:patelmart/core/widgets/error_widgets.dart';
import 'package:patelmart/core/widgets/empty_state_widget.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/popular_category_providers.dart';

class PopularCategoryWidget extends ConsumerWidget {
  final int sectionId;
  final bool showTitle;
  final bool showViewAll;
  final double itemWidth;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const PopularCategoryWidget({
    Key? key,
    required this.sectionId,
    this.showTitle = true,
    this.showViewAll = true,
    this.itemWidth = 110, // Smaller item width
    this.itemHeight = 120, // Smaller item height
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.spacing = 12, // Tighter spacing
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the popular categories data for this section
    final categoriesAsync = ref.watch(popularCategoryProvider(sectionId));
    final logger = ref.read(loggerProvider);

    return categoriesAsync.when(
      data: (categoryResponse) {
        // If there are no categories, don't show the widget
        if (categoryResponse.categoriesDetails.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title and View All button
              if (showTitle)
                Padding(
                  padding: EdgeInsets.only(
                    left: padding.horizontal / 2,
                    right: padding.horizontal / 2,
                    bottom: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        categoryResponse.title,
                        style: AppTextStyles.h6.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (showViewAll)
                        TextButton(
                          onPressed: () {
                            // Navigate to a category listing screen
                            context.push('/category');
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),

              // Horizontal scrolling categories
              SizedBox(
                height: itemHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: padding.horizontal / 2,
                  ),
                  itemCount: categoryResponse.categoriesDetails.length,
                  itemBuilder: (context, index) {
                    final category = categoryResponse.categoriesDetails[index];
                    
                    // Log image URLs for debugging
                    logger.log('Category ${category.categoryName} image URL: ${category.imageLink}');
                    
                    return _buildCategoryCard(context, category);
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: AppErrorWidget(
          errorType: ErrorType.generic,
          message: 'Error loading categories: $error',
          onRetry: () => ref.refresh(popularCategoryProvider(sectionId)),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic category) {
    return Container(
      width: itemWidth,
      margin: EdgeInsets.only(right: spacing),
      child: InkWell(
        onTap: () {
          // Navigate to subcategory screen with this category
          context.push(
            '/subcategory/${category.categoryId}/${category.deptId}/${Uri.encodeComponent(category.categoryName)}',
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category image
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(4),
                child: CachedNetworkImageWidget(
                  imageUrl: category.imageLink,
                  cacheKey: 'popular_category_${category.categoryId}',
                  fit: BoxFit.contain,
                  errorWidget: Container(
                    color: Colors.grey.shade100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey.shade400,
                          size: 24, // Smaller icon
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Image not available',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10, // Smaller font
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Category name
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                category.categoryName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12, // Smaller font size
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