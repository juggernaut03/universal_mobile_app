// lib/presentation/features/search/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/input_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cached_network_image_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../providers/cart_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/search_providers.dart';

// Search state model
class SearchState {
  final List<dynamic> results;
  final String query;
  final bool isLoading;
  final String? error;
  final bool hasSearched;

  const SearchState({
    this.results = const [],
    this.query = '',
    this.isLoading = false,
    this.error,
    this.hasSearched = false,
  });

  SearchState copyWith({
    List<dynamic>? results,
    String? query,
    bool? isLoading,
    String? error,
    bool? hasSearched,
  }) {
    return SearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

// Search provider
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  Timer? _debounceTimer;
  
  // Debounce duration for auto-complete
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  
  // Minimum characters to trigger search
  static const int _minSearchLength = 3;

  SearchNotifier(this._ref) : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.length >= _minSearchLength) {
      // Set loading state immediately for visual feedback
      state = state.copyWith(isLoading: true, error: null);
      
      // Start debounce timer
      _debounceTimer = Timer(_debounceDuration, () {
        _performSearch(query);
      });
    } else {
      // Clear results if query is too short
      state = state.copyWith(
        results: [],
        isLoading: false,
        error: null,
        hasSearched: false,
      );
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.length < _minSearchLength) return;
    
    final logger = _ref.read(loggerProvider);
    logger.log('Auto-searching for: $query');
    
    try {
      // Get selected outlet store code
      final selectedOutlet = _ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? 'TTL';
      
      // Use the API client
      final apiClient = _ref.read(apiClientProvider);
      
      // Make the API call
      final response = await apiClient.post(
        'https://newtech.shalviadvision.com/api/get_search_autocomplete_results',
        body: {
          'product_name': query,
          'store_code': storeCode,
          'project_code': 'RET5890',
        },
      );
      
      // Process the response based on its format
      List<dynamic> results = [];
      if (response is List) {
        results = response;
      } else if (response is Map && response.containsKey('products')) {
        results = response['products'] as List;
      }

      // Filter out out-of-stock or zero-price products
      results = results.where((item) {
        final qty = int.tryParse(item['store_quantity']?.toString() ?? '0') ?? 0;
        final price = ProductModel.parseDecimal128OrNumber(item['our_price']);
        return qty > 0 && price > 0;
      }).toList();
      
      // Only update state if this search is still current
      if (state.query == query) {
        state = state.copyWith(
          results: results,
          isLoading: false,
          error: null,
          hasSearched: true,
        );
      }
    } catch (e) {
      logger.error('Search error: $e');
      
      // Only update state if this search is still current
      if (state.query == query) {
        state = state.copyWith(
          error: 'Failed to load search results',
          isLoading: false,
          hasSearched: true,
        );
      }
    }
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  
  const SearchScreen({
    Key? key,
    this.initialQuery,
  }) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    
    // Set initial query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchProvider.notifier).setQuery(widget.initialQuery!);
      });
    }
    
    // Focus on search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    // Clear search state when leaving screen
    ref.read(searchProvider.notifier).clearSearch();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildSearchAppBar(searchState),
      body: _buildBody(searchState),
    );
  }
  
  PreferredSizeWidget _buildSearchAppBar(SearchState searchState) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: const EdgeInsets.all(8),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Search field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                inputFormatters: [NoEmojiInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'Search for products...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.search,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchProvider.notifier).setQuery('');
                          },
                        )
                      : searchState.isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                            )
                          : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                style: AppTextStyles.bodyMedium,
                cursorColor: AppColors.primary,
                onChanged: (value) {
                  setState(() {}); // Update UI for clear button
                  ref.read(searchProvider.notifier).setQuery(value);
                },
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Cart icon with badge
          Consumer(
            builder: (context, ref, _) {
              final cartCount = ref.watch(cartCountProvider);
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                      onPressed: () => context.push('/cart'),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: const EdgeInsets.all(8),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            cartCount > 99 ? '99+' : cartCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildBody(SearchState searchState) {
    // Show initial state when no search has been performed
    if (!searchState.hasSearched && searchState.query.length < 3) {
      return _buildInitialState();
    }
    
    // Show loading state
    if (searchState.isLoading && searchState.results.isEmpty) {
      return _buildLoadingState();
    }
    
    // Show error state
    if (searchState.error != null) {
      return _buildErrorState(searchState.error!);
    }
    
    // Show empty state
    if (searchState.hasSearched && searchState.results.isEmpty) {
      return _buildEmptyState(searchState.query);
    }
    
    // Show search results
    return _buildSearchResults(searchState);
  }
  
  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches Section
          Consumer(
            builder: (context, ref, _) {
              final recentSearches = ref.watch(recentSearchesProvider);
              
              if (recentSearches.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.history,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Recent Searches',
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref.read(searchHistoryProvider.notifier).clearHistory();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: Text(
                            'Clear All',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    ...recentSearches.take(5).map((search) => InkWell(
                      onTap: () {
                        _searchController.text = search.query;
                        ref.read(searchProvider.notifier).setQuery(search.query);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    search.query,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (search.productName != null)
                                    Text(
                                      search.productName!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
                              onPressed: () {
                                ref.read(searchHistoryProvider.notifier).removeHistoryItem(search);
                              },
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: const EdgeInsets.all(6),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ],
                ),
              );
            },
          ),
          
          // Popular Searches Section
          Consumer(
            builder: (context, ref, _) {
              final popularSearches = ref.watch(popularSearchesProvider);
              
              if (popularSearches.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.trending_up,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Popular Searches',
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: popularSearches.map((query) {
                        return InkWell(
                          onTap: () {
                            _searchController.text = query;
                            ref.read(searchProvider.notifier).setQuery(query);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.neutral300),
                            ),
                            child: Text(
                              query,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Search Tips
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.search,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Search for Products',
                    style: AppTextStyles.h5.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start typing to see suggestions and find your favorite products',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Searching products...',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState(String error) {
    return AppErrorWidget(
      errorType: ErrorType.network,
      message: error,
      onRetry: () {
        ref.read(searchProvider.notifier).setQuery(_searchController.text);
      },
    );
  }
  
  Widget _buildEmptyState(String query) {
    return EmptyStateWidget(
      title: 'No Results Found',
      subtitle: 'We couldn\'t find any products matching "$query".\nTry different keywords or browse our categories.',
      icon: Icons.search_off,
    );
  }
  
  Widget _buildSearchResults(SearchState searchState) {
    return Column(
      children: [
        // Search results header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                '${searchState.results.length} result${searchState.results.length == 1 ? '' : 's'} found',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (searchState.isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
        
        // Search results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: searchState.results.length,
            itemBuilder: (context, index) {
              final result = searchState.results[index];
              return _buildProductCard(result, index);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildProductCard(dynamic result, int index) {
    // FIXED: Use ProductModel's parsing methods for proper decimal handling
    final productName = result['product_name'] ?? 'Unknown Product';
    final productImage = result['pcode_img'] ?? '';
    final pCode = result['p_code'] ?? '';
    
    // Use ProductModel's sophisticated parsing instead of basic double.tryParse
    final productMrp = ProductModel.parseDecimal128OrNumber(result['product_mrp']);
    final ourPrice = ProductModel.parseDecimal128OrNumber(result['our_price']);
    final packageSize = ProductModel.parseDecimal128OrNumber(result['package_size']);
    
    final packageUnit = result['package_unit'] ?? '';
    final brandName = result['brand_name'] ?? '';
    
    // Calculate savings with proper decimal values
    final savings = productMrp > ourPrice ? productMrp - ourPrice : 0.0;
    final savingsPercent = productMrp > 0 ? ((savings / productMrp) * 100).round() : 0;
    
    // Get cart information
    final cartItems = ref.watch(cartProvider);
    final cartItem = cartItems.where((item) => 
      item.product.pCode == pCode).toList();
    
    final bool isInCart = cartItem.isNotEmpty;
    final int quantity = isInCart ? cartItem.first.quantity : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (pCode.isNotEmpty) {
            context.push('/product/$pCode');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with favorite button
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.neutral100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: productImage.isNotEmpty
                          ? CachedNetworkImageWidget(
                              imageUrl: productImage,
                              fit: BoxFit.contain,
                              width: 100,
                              height: 100,
                            )
                          : Container(
                              color: AppColors.neutral100,
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),
                  
                  // Discount badge
                  if (savingsPercent > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$savingsPercent% OFF',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  
                  // Favorite button
                  if (pCode.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: FavoriteButton(
                          product: _createProductModel(result),
                          size: 16,
                          activeColor: Colors.red,
                          inactiveColor: Colors.grey.shade600,
                          showSnackbarMessages: false,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      productName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Brand and Package Info
                    if (brandName.isNotEmpty || packageUnit.isNotEmpty) ...[
                      Row(
                        children: [
                          if (brandName.isNotEmpty) ...[
                            Text(
                              brandName,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (packageUnit.isNotEmpty) ...[
                              Text(
                                ' • ',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                          if (packageUnit.isNotEmpty)
                            Text(
                              packageSize > 0 
                                  ? '${packageSize.toStringAsFixed(packageSize.truncateToDouble() == packageSize ? 0 : 1)} $packageUnit'
                                  : packageUnit,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Price Row - FIXED: Now shows proper decimal values
                    Row(
                      children: [
                        // Current Price with proper decimal formatting
                        Text(
                          '₹${ourPrice.toStringAsFixed(ourPrice.truncateToDouble() == ourPrice ? 0 : 2)}',
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // MRP (if different from our price) with proper decimal formatting
                        if (productMrp > ourPrice) ...[
                          Text(
                            '₹${productMrp.toStringAsFixed(productMrp.truncateToDouble() == productMrp ? 0 : 2)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // Savings Badge
                          if (savingsPercent > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$savingsPercent% OFF',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // IPO badge + Add to cart
                    Row(
                      children: [
                        if (result['is_ipo_product']?.toString().toLowerCase() == 'yes' &&
                            (result['ipo_img'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Image.network(
                              result['ipo_img'],
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        Expanded(
                          child: isInCart
                              ? _buildQuantitySelector(context, ref, _createProductModel(result), quantity)
                              : _buildAddToCartButton(ref, _createProductModel(result)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Quantity selector matching best seller widget style
  Widget _buildQuantitySelector(BuildContext context, WidgetRef ref, ProductModel product, int quantity) {
    return Container(
      height: 32,
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Decrement button
          Material(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
            child: InkWell(
              onTap: () {
                if (quantity > 1) {
                  ref.read(cartProvider.notifier).decrementQuantity(product);
                } else {
                  ref.read(cartProvider.notifier).removeItem(product);
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.remove,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          
          // Manual quantity input — expands to fill remaining space
          Expanded(
            child: Container(
              height: 32,
              color: Colors.white,
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: product.maxQuantityAllowed,
                onQuantityChanged: (newQuantity) {
                  _handleManualQuantityInput(context, ref, product, newQuantity);
                },
              ),
            ),
          ),
          
          // Increment button
          Material(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            child: InkWell(
              onTap: () {
                if (quantity < product.maxQuantityAllowed) {
                  ref.read(cartProvider.notifier).incrementQuantity(product);
                } else {
                  _showMaxQuantityMessage(context, product);
                }
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Add to cart button matching best seller widget style
  Widget _buildAddToCartButton(WidgetRef ref, ProductModel product) {
    return SizedBox(
      height: 32,
      width: 120,
      child: ElevatedButton.icon(
        onPressed: () => ref.read(cartProvider.notifier).addItem(product),
        icon: const Icon(
          Icons.shopping_cart_outlined,
          color: Colors.white,
          size: 12,
        ),
        label: const Text(
          "ADD",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(120, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
        ),
      ),
    );
  }
  
  ProductModel _createProductModel(dynamic productData) {
    return ProductModel(
      id: productData['_id'] ?? '',
      pCode: productData['p_code'] ?? '',
      pcodeImg: productData['pcode_img'] ?? '',
      barcode: productData['barcode'] ?? '',
      productName: productData['product_name'] ?? '',
      productDescription: productData['product_description'] ?? '',
      packageSize: ProductModel.parseDecimal128OrNumber(productData['package_size']),
      packageUnit: productData['package_unit'] ?? '',
      productMrp: ProductModel.parseDecimal128OrNumber(productData['product_mrp']),
      ourPrice: ProductModel.parseDecimal128OrNumber(productData['our_price']),
      brandName: productData['brand_name'] ?? '',
      storeCode: productData['store_code'] ?? '',
      pcodestatus: productData['pcode_status'] ?? '',
      deptId: productData['dept_id'] ?? '',
      categoryId: productData['category_id'] ?? '',
      subCategoryId: productData['sub_category_id'] ?? '',
      storeQuantity: int.tryParse(productData['store_quantity']?.toString() ?? '10') ?? 10,
      maxQuantityAllowed: int.tryParse(productData['max_quantity_allowed']?.toString() ?? '10') ?? 10,
      ipoImg: productData['ipo_img'] ?? '',
      isIpoProduct: productData['is_ipo_product']?.toString().toLowerCase() == 'yes',
    );
  }
  
  // Handle manual quantity input
  void _handleManualQuantityInput(BuildContext context, WidgetRef ref, ProductModel product, int newQuantity) {
    final logger = ref.read(loggerProvider);
    
    if (newQuantity <= 0) {
      logger.log('Quantity is 0 or less, removing item from cart');
      ref.read(cartProvider.notifier).removeItem(product);
      return;
    }
    
    // Check against maximum allowed quantity
    if (newQuantity > product.maxQuantityAllowed) {
      logger.log('Quantity $newQuantity exceeds max allowed ${product.maxQuantityAllowed}');
      // Set to maximum allowed quantity
      ref.read(cartProvider.notifier).addItemWithQuantity(product, product.maxQuantityAllowed);
      _showMaxQuantityMessage(context, product);
      return;
    }
    
    // Update cart with new quantity
    logger.log('Updating quantity for ${product.productName} to $newQuantity');
    ref.read(cartProvider.notifier).addItemWithQuantity(product, newQuantity);
  }

  // Show max quantity reached message
  void _showMaxQuantityMessage(BuildContext context, ProductModel product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${product.maxQuantityAllowed} items allowed'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Manual quantity input widget matching best seller widget implementation
class _ManualQuantityInput extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final ValueChanged<int> onQuantityChanged;

  const _ManualQuantityInput({
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
  });

  @override
  State<_ManualQuantityInput> createState() => _ManualQuantityInputState();
}

class _ManualQuantityInputState extends State<_ManualQuantityInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuantity.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_ManualQuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller only if not currently editing and quantity changed
    if (oldWidget.initialQuantity != widget.initialQuantity && !_isEditing) {
      _controller.text = widget.initialQuantity.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isEditing = _focusNode.hasFocus;
    });
    
    if (!_focusNode.hasFocus) {
      _validateAndSubmit();
    }
  }

  void _validateAndSubmit() {
    final text = _controller.text.trim();
    final quantity = int.tryParse(text);
    
    if (quantity == null || quantity < 1) {
      // Invalid input, reset to current quantity or remove
      if (widget.initialQuantity > 0) {
        _controller.text = widget.initialQuantity.toString();
      } else {
        widget.onQuantityChanged(0); // This will remove the item
      }
      return;
    }
    
    // Valid quantity, notify parent
    widget.onQuantityChanged(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: widget.maxQuantity.toString().length,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            isCollapsed: true,
            counterText: '',
            filled: false,
            fillColor: Colors.transparent,
            helperText: null,
            hoverColor: Colors.transparent,
          ),
          showCursor: false,
          enableInteractiveSelection: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.maxQuantity.toString().length),
            _MaxQuantityInputFormatter(widget.maxQuantity),
          ],
          onSubmitted: (_) => _validateAndSubmit(),
          onTap: () {
            // Select all text when tapped for easy editing
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          },
        ),
      ),
    );
  }
}

// Custom input formatter to prevent entering values greater than max quantity
class _MaxQuantityInputFormatter extends TextInputFormatter {
  final int maxQuantity;

  _MaxQuantityInputFormatter(this.maxQuantity);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final quantity = int.tryParse(newValue.text);
    if (quantity == null || quantity > maxQuantity) {
      // Don't allow the input if it exceeds max quantity
      return oldValue;
    }

    return newValue;
  }
}