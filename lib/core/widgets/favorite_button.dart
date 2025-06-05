// lib/core/widgets/favorite_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/favorites_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/product_model.dart';

class FavoriteButton extends ConsumerWidget {
  final ProductModel product;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  final bool showSnackbarMessages;

  const FavoriteButton({
    Key? key,
    required this.product,
    this.activeColor,
    this.inactiveColor,
    this.size = 24,
    this.showSnackbarMessages = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the favorites state
    final favoritesState = ref.watch(favoritesProvider);
    final isFavorite = favoritesState.isProductFavorite(product.pCode);
    
    // If there's an error, show a snackbar
    if (favoritesState.error != null && showSnackbarMessages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(favoritesState.error!),
            backgroundColor: favoritesState.error!.contains('log in') 
                ? Colors.orange 
                : Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        
        // Clear the error after showing it
        ref.read(favoritesProvider.notifier).clearError();
      });
    }

    return InkWell(
      onTap: () async {
        // Check if user is logged in first
        final isLoggedIn = await ref.read(isLoggedInProvider.future);
        
        if (!isLoggedIn) {
          // Show login modal prompt
          _showLoginPromptModal(context);
          return;
        }
        
        // Toggle favorite status without waiting for loading state
        ref.read(favoritesProvider.notifier).toggleFavorite(product);
        
        // Show success message if enabled
        if (showSnackbarMessages) {
          // Use the current state to determine the message
          // Since we're toggling, the message should be opposite of current state
          final willBeFavorite = !isFavorite;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                willBeFavorite 
                    ? 'Added to favorites'
                    : 'Removed from favorites'
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            key: ValueKey(isFavorite),
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite
                ? activeColor ?? Colors.red
                : inactiveColor ?? Colors.grey,
            size: size,
          ),
        ),
      ),
    );
  }

  // Show login prompt modal
  void _showLoginPromptModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildLoginPromptContent(context),
        );
      },
    );
  }

  Widget _buildLoginPromptContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heart icon with animation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Login Required',
            style: AppTextStyles.h5.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Message
          Text(
            'Please log in to add products to your favorites and sync them across all your devices.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Buttons
          Row(
            children: [
              // Cancel button
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.neutral400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Login button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to login screen with favorites redirect
                    context.go('/auth/login?redirectRoute=/favorites');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Login',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}