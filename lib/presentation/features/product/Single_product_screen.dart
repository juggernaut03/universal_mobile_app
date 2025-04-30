// lib/presentation/features/product/Single_product_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cached_network_image_widget.dart';
import '../../../data/models/product_model.dart'; // Using existing model
import '../../providers/cart_provider.dart';
import 'widgets/suggested_product_card.dart';

// Simple stateful widget that directly fetches the product without complex state management
class SingleProductScreen extends ConsumerStatefulWidget {
  final String pCode;
  final String storeCode;
  
  const SingleProductScreen({
    Key? key,
    required this.pCode,
    required this.storeCode,
  }) : super(key: key);

  @override
  ConsumerState<SingleProductScreen> createState() => _SingleProductScreenState();
}

class _SingleProductScreenState extends ConsumerState<SingleProductScreen> {
  ProductModel? _product;
  bool _isLoading = true;
  String? _errorMessage;
  int _quantity = 1;
  List<ProductModel> _suggestedProducts = [];
  bool _isLoadingSuggestions = false;
  
  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }
  
  Future<void> _fetchProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('Fetching product details - p_code: ${widget.pCode}, store_code: ${widget.storeCode}');
      
      // Convert pCode to integer if possible
      final pCodeValue = int.tryParse(widget.pCode) ?? widget.pCode;
      
      final url = Uri.parse('https://newtech.shalviadvision.com/api/getpcodeproducts');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'p_code': pCodeValue,
          'store_code': widget.storeCode,
          'project_code': ApiConstants.projectCode,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      print('API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (data.isNotEmpty) {
          setState(() {
            _product = ProductModel.fromJson(data[0]);
            _isLoading = false;
          });
          print('Successfully loaded product: ${_product?.productName}');
          
          // After successfully loading the product, fetch suggested products
          if (_product != null) {
            _fetchSuggestedProducts();
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Product not found';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load product: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Error fetching product: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }
  
  Future<void> _fetchSuggestedProducts() async {
    if (_product == null) return;
    
    setState(() {
      _isLoadingSuggestions = true;
    });
    
    try {
      final url = Uri.parse('https://newtech.shalviadvision.com/api/get_active_products_list');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'dept_id': _product!.deptId,
          'category_id': _product!.categoryId,
          'sub_category_id': _product!.subCategoryId,
          'store_code': widget.storeCode,
          'project_code': ApiConstants.projectCode,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Convert to product models and filter out the current product
        final suggestions = data
            .map((json) => ProductModel.fromJson(json))
            .where((p) => p.pCode != _product!.pCode) // Filter out current product
            .toList();
        
        // Limit to 5 suggested products
        final limitedSuggestions = suggestions.length > 5 
            ? suggestions.sublist(0, 5) 
            : suggestions;
        
        setState(() {
          _suggestedProducts = limitedSuggestions;
          _isLoadingSuggestions = false;
        });
        
        print('Loaded ${_suggestedProducts.length} suggested products');
      } else {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      print('Error fetching suggested products: $e');
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }
  
  void _incrementQuantity() {
    if (_product != null && _quantity < _product!.maxQuantityAllowed) {
      setState(() {
        _quantity++;
      });
    }
  }
  
  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }
  
  void _addToCart() {
    if (_product != null) {
      ref.read(cartProvider.notifier).addItem(_product!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_product!.productName} added to cart (Qty: $_quantity)'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'VIEW CART',
            onPressed: () => context.push('/cart'),
          ),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              context.push('/cart');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading product details...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchProductDetails,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _product == null
                  ? const Center(child: Text('Product not found'))
                  : _buildProductDetails(),
      bottomNavigationBar: _product == null
          ? null
          : Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You Pay'),
                      Text(
                        '₹${(_product!.ourPrice * _quantity).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 200,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text(
                        'ADD TO CART',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildProductDetails() {
    final product = _product!;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand and Product Name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.brandName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.productName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Product Image
          Container(
            width: double.infinity,
            height: 300,
            padding: const EdgeInsets.all(16),
            child: Image.network(
              product.pcodeImg,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 100,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          
          // Price and Discount
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '₹${product.ourPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'MRP ₹${product.productMrp.toStringAsFixed(0)}',
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
                if (product.productMrp > product.ourPrice) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '₹${(product.productMrp - product.ourPrice).toStringAsFixed(0)} OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Quantity Selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Quantity: '),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _decrementQuantity,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: AppColors.primary,
                          child: const Icon(Icons.remove, color: Colors.white, size: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('$_quantity'),
                      ),
                      InkWell(
                        onTap: _incrementQuantity,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: AppColors.primary,
                          child: const Icon(Icons.add, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('(Max: ${product.maxQuantityAllowed})'),
              ],
            ),
          ),
          
          // Product Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(product.productDescription),
                const SizedBox(height: 16),
                Text('Weight: ${product.packageSize} ${product.packageUnit}'),
              ],
            ),
          ),
          
          // Suggested Products Section
          if (_suggestedProducts.isNotEmpty) ...[
            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Suggested Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to subcategory screen with this category
                      context.push(
                        '/subcategory/${product.categoryId}/${product.deptId}/${Uri.encodeComponent(product.brandName)}',
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 270, // Fixed height for the carousel
              child: _isLoadingSuggestions
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _suggestedProducts.length,
                      itemBuilder: (context, index) {
                        final suggestedProduct = _suggestedProducts[index];
                        return SuggestedProductCard(
                          imageUrl: suggestedProduct.pcodeImg,
                          name: suggestedProduct.productName,
                          price: suggestedProduct.ourPrice,
                          mrp: suggestedProduct.productMrp,
                          weight: suggestedProduct.packageSize.toString(),
                          unit: suggestedProduct.packageUnit,
                          onTap: () {
                            // Navigate to product detail
                            context.push('/product/${suggestedProduct.pCode}?storeCode=${suggestedProduct.storeCode}');
                          },
                          onAddToCart: () {
                            // Add to cart
                            ref.read(cartProvider.notifier).addItem(suggestedProduct);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${suggestedProduct.productName} added to cart'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
          
          // Bottom padding to ensure all content is scrollable
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}