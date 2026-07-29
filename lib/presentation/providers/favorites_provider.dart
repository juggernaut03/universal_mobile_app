// lib/presentation/providers/favorites_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/outlet_provider.dart';
import '../../data/models/product_model.dart';
import '../../data/models/auth_models.dart';
import '../../di/infrastructure_providers.dart';
import '../../di/auth_providers.dart';
import '../../di/order_providers.dart';
import '../../domain/repositories/i_favorites_repository.dart';

// Import the repository provider from the repository file
// (The favoritesRepositoryProvider is now defined in favorites_repository.dart)

// Favorites state class
class FavoritesState {
  final Set<String> favoriteProductCodes;
  final List<ProductModel> favoriteProducts;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  FavoritesState({
    this.favoriteProductCodes = const {},
    this.favoriteProducts = const [],
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  FavoritesState copyWith({
    Set<String>? favoriteProductCodes,
    List<ProductModel>? favoriteProducts,
    bool? isLoading,
    bool? isInitialized,
    String? error,
  }) {
    return FavoritesState(
      favoriteProductCodes: favoriteProductCodes ?? this.favoriteProductCodes,
      favoriteProducts: favoriteProducts ?? this.favoriteProducts,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }

  bool isProductFavorite(String pCode) {
    return favoriteProductCodes.contains(pCode);
  }
}

// Favorites notifier
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final IFavoritesRepository _repository;
  final Ref _ref;
  bool _hasInitialized = false;

  FavoritesNotifier(this._repository, this._ref) : super(FavoritesState()) {
    // Don't auto-initialize - we'll wait for login state changes
  }

  /// Initialize favorites by loading from server
  Future<void> initializeFavorites() async {
    if (_hasInitialized && state.isInitialized) {
      // If already initialized, just refresh
      return refreshFavorites();
    }
    
    try {
      // Enhanced authentication check similar to other features
      final isLoggedIn = await _ref.read(authRepositoryProvider).isSignedIn();
      
      if (!isLoggedIn) {
        state = state.copyWith(isInitialized: true);
        _hasInitialized = true;
        return;
      }
      
      // Get user profile with fallback
      UserProfile? userProfile = await _ref.read(userProfileProvider.future);
      if (userProfile == null) {
        // Fallback: check auth manager directly
        final authManager = _ref.read(centralizedAuthManagerProvider);
        userProfile = await authManager.getCurrentUserProfile();
        if (userProfile == null) {
          state = state.copyWith(isInitialized: true);
          _hasInitialized = true;
          return;
        }
      }

      // Get the store code. Favourites are priced and stocked per store, so
      // without an outlet there is nothing meaningful to load — and a literal
      // stand-in would read another tenant's store.
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode;
      if (storeCode == null || storeCode.isEmpty) {
        state = state.copyWith(isLoading: false, isInitialized: true, error: null);
        _hasInitialized = true;
        return;
      }

      state = state.copyWith(isLoading: true, error: null);

      // Load favorites from server
      final favoriteProducts = ((await _repository.items(storeCode: storeCode)).valueOrNull ?? const [])
          .map(ProductModel.fromEntity)
          .toList();

      // Extract product codes
      final favoriteProductCodes = favoriteProducts.map((product) => product.pCode).toSet();

      state = state.copyWith(
        favoriteProductCodes: favoriteProductCodes,
        favoriteProducts: favoriteProducts,
        isLoading: false,
        isInitialized: true,
      );

      _hasInitialized = true;

      final logger = _ref.read(loggerProvider);
      logger.log('Favorites initialized with ${favoriteProducts.length} items');
      
    } catch (e) {
      final logger = _ref.read(loggerProvider);
      logger.error('Error initializing favorites: $e');
      
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        error: 'Failed to load favorites: $e',
      );
      _hasInitialized = true;
    }
  }

  /// Refresh favorites from server
  Future<void> refreshFavorites() async {
    try {
      // Enhanced authentication check similar to other features
      final isLoggedIn = await _ref.read(authRepositoryProvider).isSignedIn();
      
      if (!isLoggedIn) {
        state = state.copyWith(
          favoriteProductCodes: {},
          favoriteProducts: [],
          error: null,
        );
        return;
      }
      
      // Get user profile with fallback
      UserProfile? userProfile = await _ref.read(userProfileProvider.future);
      if (userProfile == null) {
        // Fallback: check auth manager directly
        final authManager = _ref.read(centralizedAuthManagerProvider);
        userProfile = await authManager.getCurrentUserProfile();
        if (userProfile == null) {
          state = state.copyWith(
            favoriteProductCodes: {},
            favoriteProducts: [],
            error: null,
          );
          return;
        }
      }

      // Get the store code — see the note in the initialiser: no outlet means
      // no store to read favourites from, and no code that can stand in.
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode;
      if (storeCode == null || storeCode.isEmpty) {
        state = state.copyWith(isLoading: false, error: null);
        return;
      }

      state = state.copyWith(isLoading: true, error: null);

      // Load favorites from server
      final favoriteProducts = ((await _repository.items(storeCode: storeCode)).valueOrNull ?? const [])
          .map(ProductModel.fromEntity)
          .toList();

      // Extract product codes
      final favoriteProductCodes = favoriteProducts.map((product) => product.pCode).toSet();

      state = state.copyWith(
        favoriteProductCodes: favoriteProductCodes,
        favoriteProducts: favoriteProducts,
        isLoading: false,
      );

      final logger = _ref.read(loggerProvider);
      logger.log('Favorites refreshed with ${favoriteProducts.length} items');
      
    } catch (e) {
      final logger = _ref.read(loggerProvider);
      logger.error('Error refreshing favorites: $e');
      
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to refresh favorites: $e',
      );
    }
  }

  /// Toggle favorite status of a product
  Future<void> toggleFavorite(ProductModel product) async {
    try {
      final logger = _ref.read(loggerProvider);
      logger.log('🔥 toggleFavorite called for product: ${product.pCode}');
      
      // Initialize favorites if not already done
      if (!state.isInitialized) {
        logger.log('🔥 Initializing favorites first...');
        await initializeFavorites();
      }
      
      // Enhanced authentication check similar to other features
      final isLoggedIn = await _ref.read(authRepositoryProvider).isSignedIn();
        
        if (!isLoggedIn) {
        logger.log('❌ User not logged in per auth repository');
          state = state.copyWith(
            error: 'Please log in to add products to favorites',
          );
          return;
        }
        
      // Try to get user profile, but with fallback to auth manager
      UserProfile? userProfile = await _ref.read(userProfileProvider.future);
      
      if (userProfile == null) {
        logger.log('🔥 No user profile from provider, checking auth manager directly...');
        // Fallback: check auth manager directly
        final authManager = _ref.read(centralizedAuthManagerProvider);
        userProfile = await authManager.getCurrentUserProfile();
        
        if (userProfile == null) {
          logger.log('❌ No user profile from auth manager either');
          state = state.copyWith(
            error: 'Authentication data unavailable, please try logging in again',
          );
          return;
        }
        
        logger.log('✅ Got user profile from auth manager: ${userProfile.mobile}');
      } else {
        logger.log('✅ Got user profile from provider: ${userProfile.mobile}');
      }

      // Get the store code
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? product.storeCode;
      
      logger.log('🔥 Using store code: $storeCode');
      
      final pCode = product.pCode;
      final isFavorite = state.isProductFavorite(pCode);
      
      logger.log('🔥 Product $pCode is currently favorite: $isFavorite');
      
      // Set loading state
      state = state.copyWith(isLoading: true, error: null);
      
      bool success;
      if (isFavorite) {
        logger.log('🔥 Removing from favorites...');
        // Remove from favorites
        success = (await _repository.setFavorite(
          productCode: pCode,
          storeCode: storeCode,
          isFavorite: false,
        )).isOk;
        
        if (success) {
          logger.log('✅ Successfully removed from favorites');
          // Remove from local state
          final newFavoriteProductCodes = Set<String>.from(state.favoriteProductCodes);
          newFavoriteProductCodes.remove(pCode);
          
          final newFavoriteProducts = state.favoriteProducts
              .where((p) => p.pCode != pCode)
              .toList();
          
          state = state.copyWith(
            favoriteProductCodes: newFavoriteProductCodes,
            favoriteProducts: newFavoriteProducts,
            isLoading: false,
          );
        } else {
          logger.log('❌ Failed to remove from favorites');
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to remove from favorites',
          );
        }
      } else {
        logger.log('🔥 Adding to favorites...');
        // Add to favorites
        success = (await _repository.setFavorite(
          productCode: pCode,
          storeCode: storeCode,
          isFavorite: true,
        )).isOk;
        
        if (success) {
          logger.log('✅ Successfully added to favorites');
          // Add to local state
          final newFavoriteProductCodes = Set<String>.from(state.favoriteProductCodes);
          newFavoriteProductCodes.add(pCode);
          
          final newFavoriteProducts = List<ProductModel>.from(state.favoriteProducts);
          newFavoriteProducts.add(product);
          
          state = state.copyWith(
            favoriteProductCodes: newFavoriteProductCodes,
            favoriteProducts: newFavoriteProducts,
            isLoading: false,
          );
        } else {
          logger.log('❌ Failed to add to favorites');
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to add to favorites',
          );
        }
      }
    } catch (e) {
      final logger = _ref.read(loggerProvider);
      logger.error('❌ Error toggling favorite: $e');
      
      state = state.copyWith(
        isLoading: false,
        error: 'An error occurred: $e',
      );
    }
  }

  /// Check if a product is in favorites
  bool isProductFavorite(String pCode) {
    return state.isProductFavorite(pCode);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear all favorites (for logout)
  void clearFavorites() {
    state = FavoritesState(isInitialized: true);
    _hasInitialized = false;
  }
}

// Provider for favorites state
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref.watch(favoritesRepositoryDomainProvider), ref);
});

// Provider for checking if a specific product is a favorite
final isProductFavoriteProvider = Provider.family<bool, String>((ref, pCode) {
  final favoritesState = ref.watch(favoritesProvider);
  return favoritesState.isProductFavorite(pCode);
});

// Provider for getting favorite products list
final favoriteProductsProvider = Provider<List<ProductModel>>((ref) {
  final favoritesState = ref.watch(favoritesProvider);
  return favoritesState.favoriteProducts;
});

// Provider for favorites count
final favoritesCountProvider = Provider<int>((ref) {
  final favoritesState = ref.watch(favoritesProvider);
  return favoritesState.favoriteProductCodes.length;
});

// Provider to refresh favorites manually
final refreshFavoritesProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final notifier = ref.read(favoritesProvider.notifier);
    await notifier.refreshFavorites();
  };
});

// Favorites initialization watcher - initializes favorites when user logs in
final favoritesInitializationWatcherProvider = Provider<void>((ref) {
  // Watch the login status stream for immediate updates
  final loginStatusAsync = ref.watch(loginStatusStreamProvider);
  final logger = ref.read(loggerProvider);
  
  loginStatusAsync.whenData((isLoggedIn) {
    if (isLoggedIn) {
      logger.log('🔥 User logged in, checking if favorites need initialization...');
      
      // Delay to ensure auth state is fully updated
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          final favoritesState = ref.read(favoritesProvider);
          if (!favoritesState.isInitialized) {
            logger.log('🔥 Initializing favorites after login...');
            ref.read(favoritesProvider.notifier).initializeFavorites();
          } else {
            logger.log('🔥 Favorites already initialized, refreshing...');
            ref.read(favoritesProvider.notifier).refreshFavorites();
          }
        } catch (e) {
          logger.error('Error initializing favorites after login: $e');
        }
      });
    } else {
      logger.log('🔥 User logged out, clearing favorites...');
      // Clear favorites when user logs out
      try {
        ref.read(favoritesProvider.notifier).clearFavorites();
      } catch (e) {
        logger.error('Error clearing favorites after logout: $e');
      }
    }
  });
  
  return;
});