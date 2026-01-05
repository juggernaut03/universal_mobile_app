import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/core/widgets/cached_network_image_widget.dart';
import 'package:patelmart/core/widgets/error_widgets.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/popular_category_section_providers.dart';

class PopularCategorySection5Widget extends ConsumerStatefulWidget {
  final int sectionId = 5;
  
  final bool showTitle;
  final bool showViewAll;
  final double itemWidth;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final String? titleOverride;
  final double spacing;

  const PopularCategorySection5Widget({
    Key? key,
    this.titleOverride,
    this.showTitle = true,
    this.showViewAll = true,
    this.itemWidth = 110,
    this.itemHeight = 140,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.spacing = 12,
  }) : super(key: key);

  @override
  ConsumerState<PopularCategorySection5Widget> createState() => _PopularCategorySection5WidgetState();
}

class _PopularCategorySection5WidgetState extends ConsumerState<PopularCategorySection5Widget> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    // Use dedicated Section 5 provider for complete isolation
    final categoriesAsync = ref.watch(popularCategorySection5Provider);
    final logger = ref.read(loggerProvider);

    return categoriesAsync.when(
      data: (categoryResponse) {
        if (categoryResponse.categoriesDetails.isEmpty) {
          return const SizedBox.shrink();
        }

        final categories = categoryResponse.categoriesDetails;
        final displayCategories = _expanded
            ? categories
            : categories.length > 6 ? categories.sublist(0, 6) : categories;
        
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
                      if (widget.showViewAll && categories.length > 3)
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
          onRetry: () => ref.refresh(popularCategorySection5Provider),
        ),
      ),
    );
  }

  Widget _buildHorizontalList(BuildContext context, List<dynamic> categories) {
    return Container(
      height: widget.itemHeight + widget.spacing,
      padding: EdgeInsets.symmetric(
        horizontal: widget.padding.horizontal / 2,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => SizedBox(width: widget.spacing),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildExpandedGrid(BuildContext context, List<dynamic> categories) {
    const int fixedColumns = 3;
    final int rowCount = (categories.length / fixedColumns).ceil();
    final double gridHeight = (widget.itemHeight + widget.spacing) * rowCount - widget.spacing;
    
    return Container(
      height: gridHeight,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: widget.padding.horizontal / 2,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: fixedColumns,
          childAspectRatio: widget.itemWidth / widget.itemHeight,
          crossAxisSpacing: widget.spacing,
          mainAxisSpacing: widget.spacing,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic category) {
    final imageHeight = widget.itemHeight * 0.65;
    final textHeight = widget.itemHeight * 0.25;

    return SizedBox(
      width: widget.itemWidth,
      height: widget.itemHeight,
      child: InkWell(
        onTap: () {
          context.push(
            '/subcategory/${category.categoryId}/${category.deptId}/${Uri.encodeComponent(category.categoryName)}',
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: imageHeight,
              width: widget.itemWidth,
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
            SizedBox(
              height: textHeight,
              width: widget.itemWidth,
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
