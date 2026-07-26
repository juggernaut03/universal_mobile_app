import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/core/widgets/cached_network_image_widget.dart';
import 'package:patelmart/core/widgets/error_widgets.dart';
import 'package:patelmart/presentation/providers/popular_category_section_providers.dart';

class PopularCategorySection4Widget extends ConsumerStatefulWidget {
  final int sectionId = 4;
  
  final bool showTitle;
  final bool showViewAll;
  final double itemWidth;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final String? titleOverride;
  final double spacing;

  const PopularCategorySection4Widget({
    super.key,
    this.titleOverride,
    this.showTitle = true,
    this.showViewAll = true,
    this.itemWidth = 80,
    this.itemHeight = 95,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.spacing = 6,
  });

  @override
  ConsumerState<PopularCategorySection4Widget> createState() => _PopularCategorySection4WidgetState();
}

class _PopularCategorySection4WidgetState extends ConsumerState<PopularCategorySection4Widget> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    // Use dedicated Section 4 provider for complete isolation
    final categoriesAsync = ref.watch(popularCategorySection4Provider);

    return categoriesAsync.when(
      data: (categoryResponse) {
        if (categoryResponse.displayableItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final categories = categoryResponse.displayableItems;
        const int firstRowCount = 4;
        final displayCategories = _expanded
            ? categories
            : categories.sublist(0, categories.length < firstRowCount ? categories.length : firstRowCount);

        final displayTitle = widget.titleOverride ?? categoryResponse.title;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showTitle && displayTitle.isNotEmpty)
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
                        displayTitle,
                        style: AppTextStyles.h6.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.showViewAll && categories.length > firstRowCount)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _expanded = !_expanded;
                            });
                          },
                          child: Text(
                            _expanded ? 'Show Less' : 'View All',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),
              _buildExpandedGrid(context, displayCategories),
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
          onRetry: () => ref.refresh(popularCategorySection4Provider),
        ),
      ),
    );
  }

  Widget _buildExpandedGrid(BuildContext context, List<dynamic> categories) {
    const int fixedColumns = 4;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: widget.padding.horizontal / 2,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: fixedColumns,
        mainAxisExtent: 130,
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
    return GestureDetector(
      onTap: () {
        context.push(
          '/subcategory/${category.categoryId}/${category.deptId}/${Uri.encodeComponent(category.categoryName)}',
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CachedNetworkImageWidget(
              imageUrl: category.imageLink,
              cacheKey: 'popular_category_${category.categoryId}',
              fit: BoxFit.contain,
              errorWidget: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.categoryName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
