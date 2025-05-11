import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/data/models/category_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/cached_network_image_widget.dart';

class CategorySection extends StatelessWidget {
  final String title;
  final List<CategoryItem> items;
  final VoidCallback? onViewAllTap;
  final EdgeInsets padding;
  final double spacing;
  final int crossAxisCount;
  final bool showDivider;

  const CategorySection({
    Key? key,
    required this.title,
    required this.items,
    this.onViewAllTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.spacing = 8.0,
    this.crossAxisCount = 4,
    this.showDivider = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate the number of rows needed
    final int rows = (items.length / crossAxisCount).ceil();
    // Calculate grid height based on rows (gridItem height + text height + spacing)
    final double gridHeight = rows * 135.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and view all button
        Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: onViewAllTap,
                child: Text(
                  'View All',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Fixed height grid of category items
        SizedBox(
          height: gridHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.75,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildCategoryItem(context, items[index]);
            },
          ),
        ),
        
        // Bottom divider if enabled
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          ),
      ],
    );
  }

  Widget _buildCategoryItem(BuildContext context, CategoryItem item) {
    return GestureDetector(
      onTap: () {
        if (item.categoryId != null && item.departmentId != null) {
          context.push(
            '/subcategory/${item.categoryId}/${item.departmentId}/${Uri.encodeComponent(item.name)}',
          );
        }
      },
      child: Column(
        children: [
          // Image container with fixed size and wooden base
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Wooden base at the bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8D3B9), // Wooden color
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  
                  // Product image using optimized cached image widget
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImageWidget(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.contain,
                        // Custom error widget when image fails to load
                        errorWidget: Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Category name with fixed height to prevent overflow
          Container(
            height: 36, // Fixed height for text
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Model for category items 
class CategoryItem {
  final String name;
  final String imageUrl;
  final String? categoryId;
  final String? departmentId;

  const CategoryItem({
    required this.name,
    required this.imageUrl,
    this.categoryId,
    this.departmentId,
  });
  
  // Factory constructor to create CategoryItem from CategoryModel
  factory CategoryItem.fromCategoryModel(
    CategoryModel category, 
    String departmentId,
  ) {
    return CategoryItem(
      name: category.categoryName,
      imageUrl: category.imageLink,
      categoryId: category.categoryId,
      departmentId: departmentId,
    );
  }
}