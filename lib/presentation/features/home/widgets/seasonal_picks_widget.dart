// lib/presentation/features/home/widgets/seasonal_picks_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import '../../../providers/seasonal_picks_widget_providers.dart';







/// The main seasonal picks widget
class SeasonalPicksWidget extends ConsumerWidget {
  const SeasonalPicksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current outlet to determine store code
    final outletAsync = ref.watch(selectedOutletProvider);
    
    return outletAsync.when(
      data: (outlet) {
        if (outlet == null) return const SizedBox();
        
        final storeCode = outlet.storeCode;
        
        return Column(
          children: [
            // Banner section
            _buildBanner(context, ref, storeCode),
            
            // Categories section
            _buildCategories(context, ref, storeCode),
          ],
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stackTrace) => _buildErrorState(context, error),
    );
  }
  
  /// Build the banner image
  Widget _buildBanner(BuildContext context, WidgetRef ref, String storeCode) {
    final bannerAsync = ref.watch(bannerProvider(storeCode));
    
    return bannerAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: banners.first.imageUrl,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, __) => Container(
                height: 120,
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 120,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.error_outline, color: Colors.grey),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.grey),
        ),
      ),
    );
  }
  
  /// Categories per row. The tile size is derived from this and the screen
  /// width, not the other way round — so 2 categories and 8 categories render
  /// at the identical size, and the row simply has empty trailing space or
  /// scrolls, instead of the tiles growing to fill whatever count arrives.
  static const int _tilesPerRow = 4;
  static const double _tileSpacing = 10;
  static const double _horizontalPadding = 16;

  double _tileSize(BuildContext context) {
    final usableWidth = MediaQuery.of(context).size.width - (_horizontalPadding * 2);
    final size = (usableWidth - (_tileSpacing * (_tilesPerRow - 1))) / _tilesPerRow;
    return size.clamp(64, 110);
  }

  /// Build the horizontal category list - fixed tile size, 4 per row
  Widget _buildCategories(BuildContext context, WidgetRef ref, String storeCode) {
    final categoriesAsync = ref.watch(categoriesProvider(storeCode));
    final tileSize = _tileSize(context);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          height: tileSize + 24,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryItem(
                context,
                category,
                index == 0,
                index == categories.length - 1,
                tileSize,
              );
            },
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        height: tileSize + 24,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _tilesPerRow, // Show placeholder items
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          itemBuilder: (context, index) {
            return Container(
              width: tileSize,
              height: tileSize,
              margin: EdgeInsets.only(
                right: index == _tilesPerRow - 1 ? 0 : _tileSpacing,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
      error: (error, _) => Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.grey[400], size: 24),
              const SizedBox(height: 8),
              Text(
                'Failed to load categories',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build individual category item - IMAGE ONLY VERSION
  Widget _buildCategoryItem(
    BuildContext context,
    SeasonalCategory category,
    bool isFirst,
    bool isLast,
    double size,
  ) {
    return Container(
      width: size,
      margin: EdgeInsets.only(
        right: isLast ? 0 : _tileSpacing,
        left: isFirst ? 0 : 0,
      ),
      child: InkWell(
        onTap: () {
          // Navigate to category
          if (category.categoryId.isNotEmpty && category.departmentId.isNotEmpty) {
            context.push('/subcategory/${category.categoryId}/${category.departmentId}/${Uri.encodeComponent(category.categoryName)}');
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: category.imageUrl,
            width: size,
            height: size, // Square aspect ratio for better display
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: size,
              height: size,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: size,
              height: size,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build loading state
  Widget _buildLoadingState() {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading seasonal picks...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build error state
  Widget _buildErrorState(BuildContext context, Object error) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 24),
            const SizedBox(height: 8),
            Text(
              'Failed to load seasonal picks',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}



