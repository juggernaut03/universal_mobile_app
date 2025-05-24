// lib/presentation/features/home/widgets/popular_category_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/core/widgets/cached_network_image_widget.dart';
import 'package:patelmart/core/widgets/error_widgets.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/popular_category_providers.dart';

class PopularCategoryWidget extends ConsumerStatefulWidget {
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
    this.itemWidth = 110,
    this.itemHeight = 120,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.spacing = 12,
  }) : super(key: key);

  @override
  ConsumerState<PopularCategoryWidget> createState() => _PopularCategoryWidgetState();
}

class _PopularCategoryWidgetState extends ConsumerState<PopularCategoryWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Get the popular categories data for this section
    final categoriesAsync = ref.watch(popularCategoryProvider(widget.sectionId));
    final logger = ref.read(loggerProvider);

    return categoriesAsync.when(
      data: (categoryResponse) {
        // If there are no categories, don't show the widget
        if (categoryResponse.categoriesDetails.isEmpty) {
          return const SizedBox.shrink();
        }

        // Determine how many items to show
        final categories = categoryResponse.categoriesDetails;
        final displayCategories = _expanded 
            ? categories 
            : categories.length > 6 ? categories.sublist(0, 6) : categories;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title and View All button
              if (widget.showTitle)
                Padding(
                  padding: EdgeInsets.only(
                    left: widget.padding.horizontal / 2,
                    right: widget.padding.horizontal / 2,
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
                      // Always show View All button if showViewAll is true
                      if (widget.showViewAll)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _expanded = !_expanded;
                            });
                          },
                          child: Text(
                            _expanded ? 'Show Less' : 'View All',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),

              // Grid or horizontal view based on expanded state
              _expanded
                  ? _buildExpandedGrid(context, displayCategories)
                  : _buildHorizontalList(context, displayCategories),
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
          onRetry: () => ref.refresh(popularCategoryProvider(widget.sectionId)),
        ),
      ),
    );
  }

  Widget _buildHorizontalList(BuildContext context, List<dynamic> categories) {
    return SizedBox(
      height: widget.itemHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: widget.padding.horizontal / 2,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildExpandedGrid(BuildContext context, List<dynamic> categories) {
    // Calculate number of columns based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = (screenWidth / (widget.itemWidth + widget.spacing)).floor();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: widget.padding.horizontal / 2,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: widget.itemWidth / widget.itemHeight,
        crossAxisSpacing: widget.spacing,
        mainAxisSpacing: widget.spacing,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(context, category);
      },
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic category) {
  // Fixed image height for consistency (75% of total height)
  final imageHeight = widget.itemHeight * 0.75;
  final textHeight = widget.itemHeight * 0.25;
  
  return Container(
    width: widget.itemWidth,
    height: widget.itemHeight,
    margin: EdgeInsets.only(right: _expanded ? 0 : widget.spacing),
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
          // Category image - fixed size without border
          Container(
            height: imageHeight,
            width: widget.itemWidth,
            alignment: Alignment.center,
            child: CachedNetworkImageWidget(
              imageUrl: category.imageLink,
              cacheKey: 'popular_category_${category.categoryId}',
              fit: BoxFit.contain,
              errorWidget: Container(
                color: Colors.grey.shade100,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Category name - fixed height
          Container(
            height: textHeight,
            width: widget.itemWidth,
            alignment: Alignment.center,
            child: Text(
              category.categoryName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
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