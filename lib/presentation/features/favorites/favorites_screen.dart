// lib/presentation/features/favorites/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../data/models/product_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/outlet_status_provider.dart'; // Add this import for outlet status
import '../subcategory/widgets/product_item_widget.dart';

/// A screen to display the user's favorite products
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if the user is logged in
    final isLoggedInAsync = ref.watch(isLoggedInProvider);
    
    return isLoggedInAsync.when(
      data: (isLoggedIn) {
        if (!isLoggedIn) {
          // If not logged in, show login prompt
          return _buildLoginPrompt(context);
        }
        
        // If logged in, ensure favorites are initialized
        // This helps if the user navigates directly to this screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final favoritesState = ref.read(favoritesProvider);
          if (!favoritesState.isInitialized) {
            ref.read(favoritesProvider.notifier).initializeFavorites();
          }
        });
        
        // If logged in, show favorites
        return _buildFavoritesContent(context, ref);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('My Favorites'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          title: const Text('My Favorites'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
  
  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Sign in to view your favorites',
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Login to access your saved products and manage your favorites',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to login screen
                    context.push('/auth/login?redirectRoute=/favorites');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Login to Continue',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.go('/home');
                },
                child: Text(
                  'Continue Shopping',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFavoritesContent(BuildContext context, WidgetRef ref) {
    // Get the favorites state
    final favoritesState = ref.watch(favoritesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Add a refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Refresh favorites
              final refreshFavorites = ref.read(refreshFavoritesProvider);
              await refreshFavorites();
            },
          ),
        ],
      ),
      body: _buildFavoritesBody(context, ref, favoritesState),
    );
  }
  
  Widget _buildFavoritesBody(BuildContext context, WidgetRef ref, FavoritesState favoritesState) {
    // Show error if there's one
    if (favoritesState.error != null) {
      return AppErrorWidget(
        errorType: ErrorType.generic,
        message: favoritesState.error!,
        onRetry: () async {
          // Clear error and refresh favorites
          ref.read(favoritesProvider.notifier).clearError();
          final refreshFavorites = ref.read(refreshFavoritesProvider);
          await refreshFavorites();
        },
      );
    }
    
    // Show loading if not initialized yet or is loading
    if (!favoritesState.isInitialized || favoritesState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your favorites...'),
          ],
        ),
      );
    }
    
    // Show empty state if no favorites
    if (favoritesState.favoriteProducts.isEmpty) {
      return _buildEmptyState(context);
    }
    
    // Get outlet status to check if cart is enabled
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);

    // Show favorites list
    return RefreshIndicator(
      onRefresh: () async {
        final refreshFavorites = ref.read(refreshFavoritesProvider);
        await refreshFavorites();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: favoritesState.favoriteProducts.length,
        itemBuilder: (context, index) {
          final product = favoritesState.favoriteProducts[index];
          
          // Note: We're still using the ProductItemWidget but with specific behavior handling
          // The ProductItemWidget should already have the conditional cart button logic
          // If it doesn't, you'll need to update that component separately
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ProductItemWidget(
              product: product,
              onAddToCart: () {
                // Only show cart snackbar if cart is enabled
                if (isCartEnabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.productName} added to cart'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              onToggleFavorite: () {
                // This will be handled by the ProductItemWidget itself
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 120,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No favorites yet',
              style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Products you mark as favorites will appear here.\nStart exploring and save your favorite items!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to home or category screen
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Explore Products',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () {
                context.go('/category');
              },
              
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              
              child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 10.0), // or EdgeInsets.all(8.0)
  child: Text(
    'Browse Products',
    style: AppTextStyles.buttonMedium.copyWith(
      color: AppColors.primary,
    ),
  ),
),
            ),
          ],
        ),
      ),
    );
  }
}