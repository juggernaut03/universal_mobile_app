// lib/core/widgets/favorite_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/favorites_provider.dart';
import '../../core/constants/app_colors.dart';
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
    final isLoading = favoritesState.isLoading;
    
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
            action: favoritesState.error!.contains('log in')
                ? SnackBarAction(
                    label: 'LOGIN',
                    textColor: Colors.white,
                    onPressed: () {
                      // Navigate to login screen
                      Navigator.pushNamed(context, '/auth/login');
                    },
                  )
                : null,
          ),
        );
        
        // Clear the error after showing it
        ref.read(favoritesProvider.notifier).clearError();
      });
    }

    return InkWell(
      onTap: isLoading ? null : () async {
        // Check if user is logged in first
        final isLoggedIn = await ref.read(isLoggedInProvider.future);
        
        if (!isLoggedIn) {
          // Show login prompt
          if (showSnackbarMessages) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please log in to manage favorites'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                action: SnackBarAction(
                  label: 'LOGIN',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to login screen
                    Navigator.pushNamed(context, '/auth/login');
                  },
                ),
              ),
            );
          }
          return;
        }
        
        // Toggle favorite status
        await ref.read(favoritesProvider.notifier).toggleFavorite(product);
        
        // Show success message if enabled
        if (showSnackbarMessages) {
          final newIsFavorite = ref.read(favoritesProvider).isProductFavorite(product.pCode);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newIsFavorite 
                    ? 'Added to favorites'
                    : 'Removed from favorites'
              ),
              backgroundColor: AppColors.primary,
             // lib/core/widgets/favorite_button.dart (continued)
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
        child: isLoading
            ? SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    activeColor ?? AppColors.primary,
                  ),
                ),
              )
            : AnimatedSwitcher(
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
}