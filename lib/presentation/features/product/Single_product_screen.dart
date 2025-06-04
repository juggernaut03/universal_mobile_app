// lib/presentation/features/product/single_product_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/cached_network_image_widget.dart';
import '../../../data/models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/outlet_status_provider.dart'; // Add this import for outlet status
import 'widgets/suggested_product_card.dart';

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
      final logger = ref.read(loggerProvider);
      logger.log('Fetching product details - p_code: ${widget.pCode}, store_code: ${widget.storeCode}');
      
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
      
      logger.log('API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (data.isNotEmpty) {
          setState(() {
            _product = ProductModel.fromJson(data[0]);
            _isLoading = false;
          });
          logger.log('Successfully loaded product: ${_product?.productName}');
          
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
      final logger = ref.read(loggerProvider);
      logger.error('Error fetching product: $e');
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
        
        // Limit to 6 suggested products for better display
        final limitedSuggestions = suggestions.length > 6 
            ? suggestions.sublist(0, 6) 
            : suggestions;
        
        setState(() {
          _suggestedProducts = limitedSuggestions;
          _isLoadingSuggestions = false;
        });
        
        final logger = ref.read(loggerProvider);
        logger.log('Loaded ${_suggestedProducts.length} suggested products');
      } else {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('Error fetching suggested products: $e');
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }
  
  // Handle manual quantity input
  void _handleManualQuantityInput(int newQuantity) {
    if (_product == null) return;
    
    final logger = ref.read(loggerProvider);
    
    if (newQuantity <= 0) {
      logger.log('Quantity is 0 or less, removing item from cart');
      ref.read(cartProvider.notifier).removeItem(_product!);
      return;
    }
    
    // Check against maximum allowed quantity
    if (newQuantity > _product!.maxQuantityAllowed) {
      logger.log('Quantity $newQuantity exceeds max allowed ${_product!.maxQuantityAllowed}');
      // Set to maximum allowed quantity
      ref.read(cartProvider.notifier).addItemWithQuantity(_product!, _product!.maxQuantityAllowed);
      _showMaxQuantityMessage();
      return;
    }
    
    // Update cart with new quantity
    logger.log('Updating quantity for ${_product!.productName} to $newQuantity');
    ref.read(cartProvider.notifier).addItemWithQuantity(_product!, newQuantity);
  }

  // Show max quantity reached message
  void _showMaxQuantityMessage() {
    if (_product == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${_product!.maxQuantityAllowed} items allowed'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  // Build unavailability message widget
  Widget _buildUnavailabilityMessage(dynamic status) {
    String message;
    Color textColor;
    
    // Determine message and styling based on outlet status
    if (!status.isEnabled) {
      message = "UNAVAILABLE";
      textColor = AppColors.error;
    } else if (!status.hasAnyServiceAvailable) {
      message = "UNAVAILABLE";
      textColor = AppColors.warning;
    } else if (status.hasDeliveryOnly) {
      message = "DELIVERY ONLY";
      textColor = AppColors.info;
    } else if (status.hasPickupOnly) {
      message = "PICKUP ONLY";
      textColor = AppColors.info;
    } else {
      // This shouldn't happen if cart is disabled, but just in case
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4), // Changed from 8 to 4 to match
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Get cart information
    final cartItems = ref.watch(cartProvider);
    final cartItem = cartItems.where((item) => 
      _product != null && item.product.pCode == _product!.pCode).toList();
    
    final bool isInCart = cartItem.isNotEmpty;
    final int currentQuantity = isInCart ? cartItem.first.quantity : 0;
    final cartCount = ref.watch(cartCountProvider);
    
    // Check if cart is enabled from outlet status
    final isCartEnabled = ref.watch(isCartEnabledProvider);
    final outletStatusAsync = ref.watch(currentOutletStatusProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Product Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        elevation: 1,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/cart'),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
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
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Quantity selector on the left
                  Expanded(
                    flex: 2,
                    child: outletStatusAsync.when(
                      data: (status) {
                        // If outlet status is unknown, show normal buttons (fail-safe)
                        if (status == null) {
                          return isInCart
                              ? _buildManualQuantitySelector(currentQuantity, true)
                              : _buildAddToCartButton(true);
                        }
                        
                        // If cart is disabled due to outlet status, show disabled state
                        if (!isCartEnabled) {
                          return _buildUnavailabilityMessage(status);
                        }
                        
                        // Normal add to cart button or quantity selector
                        return isInCart
                            ? _buildManualQuantitySelector(currentQuantity, true)
                            : _buildAddToCartButton(true);
                      },
                      loading: () => isInCart
                          ? _buildManualQuantitySelector(currentQuantity, true)
                          : _buildAddToCartButton(true),
                      error: (error, stackTrace) => isInCart
                          ? _buildManualQuantitySelector(currentQuantity, true)
                          : _buildAddToCartButton(true),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Go to Cart button on the right
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/cart'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4), // Changed from 8 to 4
                          ),
                        ),
                        icon: Stack(
                          children: [
                            const Icon(Icons.shopping_cart_outlined),
                            if (cartCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  child: Text(
                                    cartCount.toString(),
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        label: const Text(
                          'GO TO CART',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Manual quantity selector - FIXED to match best_seller_screen style
  Widget _buildManualQuantitySelector(int quantity, bool enabled) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4), // Changed from 8 to 4
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Decrement button
          Material(
            color: enabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
            ),
            child: InkWell(
              onTap: enabled ? () {
                if (quantity > 1) {
                  ref.read(cartProvider.notifier).decrementQuantity(_product!);
                } else {
                  // Remove item if quantity becomes 0
                  ref.read(cartProvider.notifier).removeItem(_product!);
                }
              } : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
              child: Container(
                width: 48, // Fixed width to match height
                height: 48,
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
          
          // Manual quantity input field with improved centering
          Expanded(
            child: Container(
              height: 48,
              color: enabled ? Colors.white : Colors.grey.shade100,
              alignment: Alignment.center, // Add alignment to center
              child: _ManualQuantityInput(
                initialQuantity: quantity,
                maxQuantity: _product!.maxQuantityAllowed,
                enabled: enabled,
                onQuantityChanged: _handleManualQuantityInput,
              ),
            ),
          ),
          
          // Increment button
          Material(
            color: enabled ? AppColors.primary : Colors.grey.shade300,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            child: InkWell(
              onTap: enabled ? () {
                if (quantity < _product!.maxQuantityAllowed) {
                  ref.read(cartProvider.notifier).incrementQuantity(_product!);
                } else {
                  _showMaxQuantityMessage();
                }
              } : null,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Container(
                width: 48, // Fixed width to match height
                height: 48,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple add to cart button - matching best_seller_screen style
  Widget _buildAddToCartButton(bool enabled) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: enabled ? _addToCart : null,
        icon: Icon(
          Icons.shopping_cart_outlined,
          color: enabled ? Colors.white : Colors.grey.shade600,
          size: 18,
        ),
        label: Text(
          "ADD",
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.primary : Colors.grey.shade300,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Changed from 8 to 4
          ),
          elevation: enabled ? 2 : 0,
        ),
      ),
    );
  }
  
  // Add to cart helper method
  void _addToCart() {
    if (_product != null) {
      ref.read(cartProvider.notifier).addItem(_product!);
    }
  }
  
  Widget _buildProductDetails() {
    final product = _product!;
    
    // Calculate discount
    final discount = product.productMrp - product.ourPrice;
    final discountPercent = product.productMrp > 0 
        ? ((discount / product.productMrp) * 100).round() 
        : 0;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Section with enhanced styling
          Container(
            color: Colors.white,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 350,
                  padding: const EdgeInsets.all(20),
                  child: CachedNetworkImageWidget(
                    imageUrl: product.pcodeImg,
                    fit: BoxFit.contain,
                    loadingWidget: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    errorWidget: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Discount badge
                if (discountPercent > 0)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        "${discountPercent}% OFF",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Product Info Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Name
                if (product.brandName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.brandName,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Product Name
                Text(
                  product.productName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Package Size with icon
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${product.packageSize} ${product.packageUnit}",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Price Section with enhanced styling
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '₹${product.ourPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (product.productMrp > product.ourPrice) ...[
                        Text(
                          '₹${product.productMrp.toStringAsFixed(0)}',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Save ₹${discount.toStringAsFixed(0)}',
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
                
                const SizedBox(height: 12),
                
                // Stock info
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'In Stock (Max: ${product.maxQuantityAllowed} items)',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Product Description
          if (product.productDescription.isNotEmpty) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product.productDescription,
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Suggested Products Section
          if (_suggestedProducts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'You might also like',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to subcategory screen with this category
                            context.push(
                              '/subcategory/${product.categoryId}/${product.deptId}/${Uri.encodeComponent(product.brandName)}',
                            );
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300, // Increased height for enhanced cards
                    child: _isLoadingSuggestions
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _suggestedProducts.length,
                            itemBuilder: (context, index) {
                              final suggestedProduct = _suggestedProducts[index];
                              return SuggestedProductCard(
                                product: suggestedProduct,
                                onTap: () {
                                  // Navigate to product detail
                                  context.push('/product/${suggestedProduct.pCode}?storeCode=${suggestedProduct.storeCode}');
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
          
          // Bottom padding to ensure all content is scrollable above bottom bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// Custom manual quantity input widget - FIXED to match best_seller_screen
class _ManualQuantityInput extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final ValueChanged<int> onQuantityChanged;
  final bool enabled;

  const _ManualQuantityInput({
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
    this.enabled = true,
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
      // Add alignment to center the TextField both horizontally and vertically
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: widget.maxQuantity.toString().length,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: widget.enabled ? Colors.black87 : Colors.grey.shade600,
          ),
          decoration: const InputDecoration(
            // Remove all borders and effects
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            
            // Remove padding and set isCollapsed to true to ensure proper vertical centering
            contentPadding: EdgeInsets.zero,
            isDense: true,
            isCollapsed: true,
            
            // Hide counter
            counterText: '',
            
            // Remove fill color
            filled: false,
            fillColor: Colors.transparent,
            
            // Remove helper text space
            helperText: null,
            
            // Disable hover effects
            hoverColor: Colors.transparent,
          ),
          
          // Disable cursor and selection handles on mobile for better UX
          showCursor: false,
          enableInteractiveSelection: false,
          
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.maxQuantity.toString().length),
            _MaxQuantityInputFormatter(widget.maxQuantity),
          ],
          onSubmitted: (_) => _validateAndSubmit(),
          onTap: widget.enabled ? () {
            // Select all text when tapped for easy editing
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          } : null,
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