// lib/presentation/features/home/widgets/seasonal_picks_widget.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import '../../../../core/constants/app_constants.dart';
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
  
  /// Build the horizontal category list - FIXED VERSION
  Widget _buildCategories(BuildContext context, WidgetRef ref, String storeCode) {
    final categoriesAsync = ref.watch(categoriesProvider(storeCode));
    
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          height: 200, // Reduced height since no text needed
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryItem(context, category, index == 0, index == categories.length - 1);
            },
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5, // Show placeholder items
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            return Container(
              width: 140,
              margin: EdgeInsets.only(
                right: 12,
                left: index == 0 ? 0 : 0,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
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
  Widget _buildCategoryItem(BuildContext context, SeasonalCategory category, bool isFirst, bool isLast) {
    return Container(
      width: 180, // Wider since we're only showing image
      margin: EdgeInsets.only(
        right: isLast ? 0 : 12,
        left: isFirst ? 0 : 0,
      ),
      child: InkWell(
        onTap: () {
          // Navigate to category
          if (category.categoryId.isNotEmpty && category.departmentId.isNotEmpty) {
            context.push('/subcategory/${category.categoryId}/${category.departmentId}/${Uri.encodeComponent(category.categoryName)}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: category.imageUrl,
            width: 180,
            height: 180, // Square aspect ratio for better display
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 180,
              height: 180,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 180,
              height: 180,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image_not_supported, color: Colors.grey, size: 32),
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



