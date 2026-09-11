import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/core/widgets/cached_network_image_widget.dart';
import 'package:patelmart/core/widgets/error_widgets.dart';
import 'package:patelmart/domain/entities/promo_section.dart';
import 'package:patelmart/presentation/providers/popular_category_section_providers.dart';

/// One popular-category promo strip.
///
/// Replaces `popular_category_section_2_widget.dart` … `_5_widget.dart`, which
/// were four copies of this file differing only in the section number. The
/// section id now arrives from the home feed, so the number of strips is a
/// server decision rather than a compile-time one.
class PopularCategorySectionWidget extends ConsumerStatefulWidget {
  final int sectionId;

  final bool showTitle;
  final bool showViewAll;
  final double itemWidth;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final String? titleOverride;
  final double spacing;

  /// How many tiles show once collapsed, before "View All" is tapped.
  ///
  /// Admin-configurable per section (`HomeSection.config.collapsed_rows` ×
  /// the fixed 4-column grid) — was a hardcoded `firstRowCount = 4` (one
  /// row), so every section collapsed the same way regardless of how many
  /// tiles it actually had.
  final int collapsedItemCount;

  const PopularCategorySectionWidget({
    super.key,
    required this.sectionId,
    this.titleOverride,
    this.showTitle = true,
    this.showViewAll = true,
    this.itemWidth = 80,
    this.itemHeight = 95,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.spacing = 6,
    this.collapsedItemCount = 4,
  });

  @override
  ConsumerState<PopularCategorySectionWidget> createState() =>
      _PopularCategorySectionWidgetState();
}

class _PopularCategorySectionWidgetState
    extends ConsumerState<PopularCategorySectionWidget> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(promoSectionProvider(widget.sectionId));

    return categoriesAsync.when(
      data: (categoryResponse) {
        if (categoryResponse.displayableItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final categories = categoryResponse.displayableItems;
        final firstRowCount = widget.collapsedItemCount;
        final displayCategories =
            _expanded
                ? categories
                : categories.sublist(
                  0,
                  categories.length < firstRowCount
                      ? categories.length
                      : firstRowCount,
                );

        // Logic: Override > API Title
        final displayTitle = widget.titleOverride ?? categoryResponse.title;

        // No margin of its own — the home feed's section loop already adds a
        // uniform gap after every section (see home_screen.dart); this
        // used to add its own 16px bottom margin on top of that, making
        // this specific section type's gap 28px against everyone else's 12.
        return Column(
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
        );
      },
      loading:
          () => const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, stackTrace) => Center(
            child: AppErrorWidget(
              errorType: ErrorType.generic,
              message: 'Error loading categories: $error',
              onRetry:
                  () => ref.refresh(promoSectionProvider(widget.sectionId)),
            ),
          ),
    );
  }

  Widget _buildExpandedGrid(BuildContext context, List<PromoItem> categories) {
    const int fixedColumns = 4;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: widget.padding.horizontal / 2),
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

  Widget _buildCategoryCard(BuildContext context, PromoItem category) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/subcategory/${category.categoryCode}/${category.departmentCode}/${Uri.encodeComponent(category.label)}',
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
              imageUrl: category.imageUrl,
              cacheKey: 'popular_category_${category.categoryCode}',
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
            category.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
