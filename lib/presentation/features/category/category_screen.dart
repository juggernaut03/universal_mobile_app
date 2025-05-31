// lib/presentation/features/category/category_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/widgets/bottom_navigation_widget.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../core/widgets/cached_network_image_widget.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_providers.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/outlet_provider.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  // Current selected department
  String? _currentDepartmentId;
  int _navIndex = 1; // Category tab selected by default
  bool _isRefreshing = false;
  
  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentsProvider);
    final allCategoriesAsync = ref.watch(allCategoriesProvider);
    final logger = ref.read(loggerProvider);
    
    return BackButtonWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: departmentsAsync.when(
                  data: (departments) {
                    return allCategoriesAsync.when(
                      data: (categoriesByDepartment) {
                        // Set initial selected department if none is selected
                        if (_currentDepartmentId == null && departments.isNotEmpty) {
                          _currentDepartmentId = departments[0].departmentId;
                        }
                        
                        // Validate that current selection exists in new data
                        if (_currentDepartmentId != null && 
                            !departments.any((dept) => dept.departmentId == _currentDepartmentId)) {
                          _currentDepartmentId = departments.isNotEmpty ? departments[0].departmentId : null;
                        }
                        
                        return Row(
                          children: [
                            // Left side: Departments (30% width)
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.3,
                              child: _buildDepartmentList(departments),
                            ),
                            
                            // Right side: Categories (70% width)
                            Expanded(
                              child: _buildCategoriesForDepartment(categoriesByDepartment),
                            ),
                          ],
                        );
                      },
                      loading: () => _buildShimmerLoading(context),
                      error: (error, stackTrace) {
                        logger.error('Error loading categories: $error');
                        return AppErrorWidget(
                          errorType: ErrorType.server,
                          message: 'Error loading categories. Please try again.',
                          onRetry: () => ref.refresh(allCategoriesProvider),
                        );
                      },
                    );
                  },
                  loading: () => _buildShimmerLoading(context),
                  error: (error, stackTrace) {
                    logger.error('Error loading departments: $error');
                    return AppErrorWidget(
                      errorType: ErrorType.server,
                      message: 'Error loading departments. Please try again.',
                      onRetry: () => ref.refresh(departmentsProvider),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    final cartCount = ref.watch(cartCountProvider);
    
    return AppBar(
      title: const Text('SHOP BY CATEGORY'),
      centerTitle: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 1,
      actions: [
        // Wishlist icon
        IconButton(
          icon: const Icon(Icons.favorite_border_outlined),
          onPressed: () => context.push('/favorites'),
        ),
        
        // Cart icon with badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => context.push('/cart'),
              padding: const EdgeInsets.only(right: 16),
            ),
            if (cartCount > 0)
              Positioned(
                right: 10,
                top: 5,
                child: Container(
                  padding: const EdgeInsets.all(0),
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
        ),
      ],
    );
  }
  
  Widget _buildDepartmentList(List<DepartmentModel> departments) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: departments.length,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final department = departments[index];
          final isSelected = department.departmentId == _currentDepartmentId;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.grey[50],
              border: Border(
                left: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentDepartmentId = department.departmentId;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Department image
                    AnimatedScale(
                      scale: isSelected ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: CachedNetworkImageWidget(
                            imageUrl: department.imageLink,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: Container(
                              color: Colors.grey[100],
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey[400],
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Department name
                    Text(
                      department.departmentName,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCategoriesForDepartment(Map<String, List<CategoryModel>> categoriesByDepartment) {
    if (_currentDepartmentId == null) {
      return const Center(
        child: Text('Select a department'),
      );
    }
    
    final categories = categoriesByDepartment[_currentDepartmentId] ?? [];
    // Fix nullable issue by safely getting department name
    final departments = ref.read(departmentsProvider).valueOrNull;
    String departmentName = 'Selected Department';
    
    if (departments != null) {
      final selectedDepartment = departments.firstWhere(
        (dept) => dept.departmentId == _currentDepartmentId,
        orElse: () => DepartmentModel(
          id: '',
          departmentId: '',
          departmentName: 'Unknown Department',
          imageLink: '',
          sequenceId: 0,
        ),
      );
      departmentName = selectedDepartment.departmentName;
    }
    
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No categories found in\n$departmentName',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Department header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLighter.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            departmentName,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Categories grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.95,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(categories[index]);
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategoryCard(CategoryModel category) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          final departmentId = _currentDepartmentId ?? '';
          context.push(
            '/subcategory/${category.categoryId}/$departmentId/${Uri.encodeComponent(category.categoryName)}',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CachedNetworkImageWidget(
                  imageUrl: category.imageLink,
                  fit: BoxFit.contain,
                  placeholder: Container(
                    color: Colors.grey[50],
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: Colors.grey[50],
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey[400],
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                child: Text(
                  category.categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomNavigation() {
    return BottomNavigationWidget(
      currentIndex: _navIndex,
      onTap: (index) {
        if (_navIndex == index) return;
        
        setState(() {
          _navIndex = index;
        });
        
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            // Already on category
            break;
          case 2:
            context.go('/cart');
            break;
          case 3:
            context.go('/reorder');
            break;
          case 4:
            context.go('/account');
            break;
        }
      },
    );
  }
  
  Widget _buildShimmerLoading(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.3,
          child: _buildDepartmentsShimmer(),
        ),
        Expanded(
          child: _buildCategoriesShimmer(),
        ),
      ],
    );
  }
  
  Widget _buildDepartmentsShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildCategoriesShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: 150,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.95,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 6,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            width: double.infinity,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final refreshAction = ref.read(categoryRefreshProvider);
      await refreshAction();
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('Error refreshing categories: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
  
  Widget _buildDrawer() {
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final logger = ref.read(loggerProvider);
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        logger.log('Drawer back button pressed');
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      'Hi, Guest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    selectedOutletAsync.when(
                      data: (outlet) => Expanded(
                        child: Text(
                          ref.watch(selectedPincodeProvider) ?? 'No pincode selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      loading: () => const Text(
                        'Loading...',
                        style: TextStyle(color: Colors.white),
                      ),
                      error: (_, __) => const Text(
                        'Error loading location',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      onPressed: () {
                        logger.log('Edit location pressed from drawer');
                        Navigator.pop(context);
                        if (mounted) {
                          context.go('/location-change');
                        }
                      },
                    ),
                  ],
                ),
                
                Image.asset(
                  'assets/images/patelLogo.png',
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    logger.error('Error loading drawer logo: $error');
                    return const Icon(Icons.store, color: Colors.white, size: 40);
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.grid_view, color: AppColors.primary),
                  title: const Text('SHOP BY CATEGORY'),
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    logger.log('Shop by category pressed');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.shopping_cart, color: AppColors.primary),
                  title: const Text('View Cart'),
                  trailing: cartCount > 0
                      ? Text(
                          '₹${cartTotal.toStringAsFixed(2)} (${cartCount.toString()})',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  onTap: () {
                    logger.log('View Cart pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.push('/cart');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.help_outline, color: AppColors.primary),
                  title: const Text('Help & Support'),
                  onTap: () {
                    logger.log('Help & Support pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/help-support');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.description_outlined, color: AppColors.primary),
                  title: const Text('Refund, Terms and Policies'),
                  onTap: () {
                    logger.log('Refund policies pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/refund-policies');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  title: const Text('Frequently Asked Questions'),
                  onTap: () {
                    logger.log('FAQ pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/faq');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('About Us'),
                  onTap: () {
                    logger.log('About Us pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/about-us');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.store, color: AppColors.primary),
                  title: const Text('Store Information'),
                  onTap: () {
                    logger.log('Store Information pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/store-info');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.location_on, color: AppColors.primary),
                  title: const Text('Change Location'),
                  onTap: () {
                    logger.log('Change Location pressed');
                    Navigator.pop(context);
                    if (mounted) {
                      context.go('/location-change');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.refresh, color: AppColors.primary),
                  title: const Text('Refresh All Categories'),
                  onTap: () async {
                    logger.log('Refresh Categories pressed');
                    Navigator.pop(context);
                    await _handleRefresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Categories refreshed'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Version 5.2.1',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}