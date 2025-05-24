// lib/presentation/features/search/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import '../../../core/constants/app_colors.dart';
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
      backgroundColor: Colors.white,
      appBar: _buildSearchAppBar(searchState),
      body: _buildBody(searchState),
    );
  }
  
  PreferredSizeWidget _buildSearchAppBar(SearchState searchState) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search for products...',
            hintStyle: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Colors.grey,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchProvider.notifier).setQuery('');
                    },
                  )
                : searchState.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          cursorColor: AppColors.primary,
          onChanged: (value) {
            ref.read(searchProvider.notifier).setQuery(value);
          },
          textInputAction: TextInputAction.search,
        ),
      ),
      actions: [
        // Cart icon with badge
        Consumer(
          builder: (context, ref, _) {
            final cartCount = ref.watch(cartCountProvider);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  onPressed: () => context.push('/cart'),
                ),
                if (cartCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        cartCount.toString(),
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
            );
          },
        ),
        const SizedBox(width: 8),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // Recent Searches Section
          Consumer(
            builder: (context, ref, _) {
              final recentSearches = ref.watch(recentSearchesProvider);
              
              if (recentSearches.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref.read(searchHistoryProvider.notifier).clearHistory();
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentSearches.length,
                    itemBuilder: (context, index) {
                      final search = recentSearches[index];
                      return ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: Text(search.query),
                        subtitle: search.productName != null
                            ? Text(
                                search.productName!,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                          onPressed: () {
                            ref.read(searchHistoryProvider.notifier).removeHistoryItem(search);
                          },
                        ),
                        onTap: () {
                          _searchController.text = search.query;
                          ref.read(searchProvider.notifier).setQuery(search.query);
                        },
                      );
                    },
                  ),
                  
                  const Divider(),
                ],
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
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Popular Searches',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: popularSearches.map((query) {
                        return ActionChip(
                          label: Text(
                            query,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            _searchController.text = query;
                            ref.read(searchProvider.notifier).setQuery(query);
                          },
                          backgroundColor: Colors.grey[100],
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          
          // Search Tips
          const Center(
            child: Column(
              children: [
                Icon(
                  Icons.search,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Search for Products',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Start typing to see suggestions...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Searching...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
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
      subtitle: 'No products found for "$query".\nTry different keywords or browse categories.',
      icon: Icons.search_off,
    );
  }
  
  Widget _buildSearchResults(SearchState searchState) {
    return Column(
      children: [
        // Search results header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[50],
          child: Row(
            children: [
              Text(
                '${searchState.results.length} results found',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              if (searchState.isLoading)
                const SizedBox(
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
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: searchState.results.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 80,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final result = searchState.results[index];
              return _buildProductTile(result);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildProductTile(dynamic result) {
    // Extract product data from API response
    final productName = result['product_name'] ?? 'Unknown Product';
    final productImage = result['pcode_img'] ?? '';
    final pCode = result['p_code'] ?? '';
    final productMrp = double.tryParse(result['product_mrp']?.toString() ?? '0') ?? 0.0;
    final ourPrice = double.tryParse(result['our_price']?.toString() ?? '0') ?? 0.0;
    final packageSize = double.tryParse(result['package_size']?.toString() ?? '0') ?? 0.0;
    final packageUnit = result['package_unit'] ?? '';
    final brandName = result['brand_name'] ?? '';
    
    // Calculate savings
    final savings = productMrp > ourPrice ? productMrp - ourPrice : 0.0;
    final savingsPercent = productMrp > 0 ? ((savings / productMrp) * 100).round() : 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (pCode.isNotEmpty) {
              context.push('/product/$pCode');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: productImage.isNotEmpty
                        ? CachedNetworkImageWidget(
                            imageUrl: productImage,
                            fit: BoxFit.contain,
                          )
                        : const Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Brand and Package Info
                      if (brandName.isNotEmpty || packageUnit.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (brandName.isNotEmpty) ...[
                              Text(
                                brandName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (packageUnit.isNotEmpty) ...[
                                const Text(' • ', style: TextStyle(color: Colors.grey)),
                              ],
                            ],
                            if (packageUnit.isNotEmpty)
                              Text(
                                packageSize > 0 
                                    ? '${packageSize.toStringAsFixed(packageSize.truncateToDouble() == packageSize ? 0 : 1)} $packageUnit'
                                    : packageUnit,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      
                      // Price Row
                      Row(
                        children: [
                          // Current Price
                          Text(
                            '₹${ourPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // MRP (if different from our price)
                          if (productMrp > ourPrice) ...[
                            Text(
                              '₹${productMrp.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Savings Badge
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
                    ],
                  ),
                ),
                
                // Action Buttons
                Column(
                  children: [
                    // Favorite Button
                    if (pCode.isNotEmpty)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: FavoriteButton(
                          product: _createProductModel(result),
                          size: 20,
                          showSnackbarMessages: false,
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Add to Cart Button
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => _addToCart(result),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      packageSize: double.tryParse(productData['package_size']?.toString() ?? '0') ?? 0.0,
      packageUnit: productData['package_unit'] ?? '',
      productMrp: double.tryParse(productData['product_mrp']?.toString() ?? '0') ?? 0.0,
      ourPrice: double.tryParse(productData['our_price']?.toString() ?? '0') ?? 0.0,
      brandName: productData['brand_name'] ?? '',
      storeCode: productData['store_code'] ?? '',
      pcodestatus: productData['pcode_status'] ?? '',
      deptId: productData['dept_id'] ?? '',
      categoryId: productData['category_id'] ?? '',
      subCategoryId: productData['sub_category_id'] ?? '',
      storeQuantity: int.tryParse(productData['store_quantity']?.toString() ?? '10') ?? 10,
      maxQuantityAllowed: int.tryParse(productData['max_quantity_allowed']?.toString() ?? '10') ?? 10,
    );
  }
  
  void _addToCart(dynamic productData) {
    try {
      final product = _createProductModel(productData);
      
      // Add to cart
      ref.read(cartProvider.notifier).addItem(product);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${product.productName} added to cart',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => context.push('/cart'),
          ),
        ),
      );
    } catch (e) {
      ref.read(loggerProvider).error('Error adding product to cart: $e');
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Failed to add product to cart'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}