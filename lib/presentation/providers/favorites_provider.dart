// lib/presentation/providers/favorites_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/favorites_repository.dart';
import '../providers/auth_providers.dart';
import '../providers/launch_flow_provider.dart';
import '../providers/outlet_provider.dart';
import '../../data/models/product_model.dart';

// Repository provider
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  return FavoritesRepository(logger: logger);
});

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
  final FavoritesRepository _repository;
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
      // Check if user is logged in
      final userProfile = await _ref.read(userProfileProvider.future);
      if (userProfile == null) {
        state = state.copyWith(isInitialized: true);
        _hasInitialized = true;
        return;
      }

      // Get the store code
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? 'KLK';
      
      state = state.copyWith(isLoading: true, error: null);
      
      // Load favorites from server
      final favoriteProducts = await _repository.getFavoriteItems(
        accessKey: userProfile.accessKey,
        mobileNo: userProfile.mobile,
        storeCode: storeCode,
      );
      
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
      // Check if user is logged in
      final userProfile = await _ref.read(userProfileProvider.future);
      if (userProfile == null) {
        state = state.copyWith(
          favoriteProductCodes: {},
          favoriteProducts: [],
          error: null,
        );
        return;
      }

      // Get the store code
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? 'KLK';
      
      state = state.copyWith(isLoading: true, error: null);
      
      // Load favorites from server
      final favoriteProducts = await _repository.getFavoriteItems(
        accessKey: userProfile.accessKey,
        mobileNo: userProfile.mobile,
        storeCode: storeCode,
      );
      
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
      // Check if user is logged in
      final userProfile = await _ref.read(userProfileProvider.future);
      if (userProfile == null) {
        state = state.copyWith(
          error: 'Please log in to add products to favorites',
        );
        return;
      }

      // Get the store code
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? product.storeCode;
      
      final pCode = product.pCode;
      final isFavorite = state.isProductFavorite(pCode);
      
      // Set loading state
      state = state.copyWith(isLoading: true, error: null);
      
      bool success;
      if (isFavorite) {
        // Remove from favorites
        success = await _repository.removeFromFavorites(
          accessKey: userProfile.accessKey,
          pCode: pCode,
          mobileNo: userProfile.mobile,
          storeCode: storeCode,
        );
        
        if (success) {
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
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to remove from favorites',
          );
        }
      } else {
        // Add to favorites
        success = await _repository.addToFavorites(
          accessKey: userProfile.accessKey,
          pCode: pCode,
          mobileNo: userProfile.mobile,
          storeCode: storeCode,
        );
        
        if (success) {
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
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to add to favorites',
          );
        }
      }
    } catch (e) {
      final logger = _ref.read(loggerProvider);
      logger.error('Error toggling favorite: $e');
      
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
  final repository = ref.watch(favoritesRepositoryProvider);
  return FavoritesNotifier(repository, ref);
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