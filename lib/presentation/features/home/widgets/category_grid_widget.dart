import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';

class CategorySection extends StatelessWidget {
  final String title;
  final List<CategoryItem> items;
  final VoidCallback? onViewAllTap;
  final EdgeInsets padding;
  final double spacing;

  const CategorySection({
    Key? key,
    required this.title,
    required this.items,
    this.onViewAllTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.spacing = 8.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate the number of rows needed (4 items per row)
    final int rows = (items.length / 4).ceil();
    // Calculate grid height based on rows
    final double gridHeight = rows * 160.0;

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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: onViewAllTap,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
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
              crossAxisCount: 4,
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
        
        // Bottom padding
        const SizedBox(height: 12),
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
                  
                  // Product image
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                              size: 24,
                            ),
                          );
                        },
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
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Category item model
class CategoryItem {
  final String name;
  final String imageUrl;
  final String? categoryId;
  final String? departmentId;

  CategoryItem({
    required this.name,
    required this.imageUrl,
    this.categoryId,
    this.departmentId,
  });
}