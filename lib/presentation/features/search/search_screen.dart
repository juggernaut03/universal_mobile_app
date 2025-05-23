// lib/presentation/features/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/data/models/product_model.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cached_network_image_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../providers/cart_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/subcategory_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  
  const SearchScreen({
    Key? key,
    required this.initialQuery,
  }) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;
  bool _isLoading = false;
  List<dynamic> _searchResults = [];
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    
    // Perform initial search with the query parameter
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    final logger = ref.read(loggerProvider);
    logger.log('Performing search for: $query');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Get selected outlet store code
      final selectedOutlet = ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? 'TTL';
      
      // Use the API client
      final apiClient = ref.read(apiClientProvider);
      
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
      if (response is List) {
        setState(() {
          _searchResults = response;
          _isLoading = false;
        });
      } else if (response is Map && response.containsKey('products')) {
        setState(() {
          _searchResults = response['products'] as List;
          _isLoading = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.error('Search error: $e');
      setState(() {
        _error = 'Failed to load search results: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for products',
            hintStyle: const TextStyle(color: Colors.black),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _searchController.clear();
              },
            ),
          ),
          style: const TextStyle(color: Colors.black),
          cursorColor: Colors.black,
          onSubmitted: (_) => _performSearch(),
          textInputAction: TextInputAction.search,
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _performSearch,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return AppErrorWidget(
        errorType: ErrorType.generic,
        message: _error!,
        onRetry: _performSearch,
      );
    }
    
    if (_searchResults.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Results Found',
        subtitle: 'Try a different search term or browse categories',
        icon: Icons.search_off,
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        
        // Adjust these fields based on your actual API response structure
        final productName = result['product_name'] ?? 'Unknown Product';
        final productImage = result['pcode_img'] ?? '';
        final pCode = result['p_code'] ?? '';
        final productMrp = double.tryParse(result['product_mrp']?.toString() ?? '0') ?? 0.0;
        final ourPrice = double.tryParse(result['our_price']?.toString() ?? '0') ?? 0.0;
        
        return ListTile(
          leading: SizedBox(
            width: 60,
            height: 60,
            child: productImage.isNotEmpty
                ? CachedNetworkImageWidget(
                    imageUrl: productImage,
                    fit: BoxFit.contain,
                  )
                : const Icon(Icons.image_not_supported_outlined, size: 40),
          ),
          title: Text(
            productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                '₹${ourPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              if (productMrp > ourPrice)
                Text(
                  '₹${productMrp.toStringAsFixed(2)}',
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            color: AppColors.primary,
            onPressed: () {
              // Add to cart logic
              if (pCode.isNotEmpty) {
                _addToCart(result);
              }
            },
          ),
          onTap: () {
            // Navigate to product detail
            if (pCode.isNotEmpty) {
              context.push('/product/$pCode');
            }
          },
        );
      },
    );
  }
  
  // Add to cart logic
  void _addToCart(dynamic productData) {
    try {
      // Convert API response to ProductModel
      // Adjust field names based on your actual API response
      final product = ProductModel(
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
      
      // Add to cart
      ref.read(cartProvider.notifier).addItem(product);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.productName} added to cart'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ref.read(loggerProvider).error('Error adding product to cart: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product to cart: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}