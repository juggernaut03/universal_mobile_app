// lib/presentation/features/category/category_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/widgets/app_drawer_widget.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/widgets/bottom_navigation_widget.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../core/widgets/cached_network_image_widget.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_providers.dart';
import '../../providers/launch_flow_provider.dart';

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
  
  // Custom back navigation handler
  Future<bool> _handleBackPress() async {
    final logger = ref.read(loggerProvider);
    logger.log('Hardware back button pressed on CategoryScreen - navigating to home');
    
    try {
      // Navigate to home using go
      context.go('/home');
      
      // Return false to prevent default back navigation
      return false;
    } catch (e) {
      logger.error('Error handling back navigation: $e');
      // If go fails, try push as fallback
      if (context.mounted) {
        context.pushReplacement('/home');
      }
      return false;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Check loading state first - prevents shuffling during refresh
    final isRefreshingProvider = ref.watch(categoryRefreshLoadingProvider);
    final departmentsAsync = ref.watch(departmentsProvider);
    final allCategoriesAsync = ref.watch(allCategoriesProvider);
    final logger = ref.read(loggerProvider);
    
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          final logger = ref.read(loggerProvider);
          logger.log('PopScope: Back navigation intercepted - going to home');
          
          // Navigate to home
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: WillPopScope(
        onWillPop: _handleBackPress,
        child: BackButtonWrapper(
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildAppBar(),
            drawer: const AppDrawerWidget(), // ✅ Using reusable drawer instead of custom one
            body: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    // Show shimmer loading immediately when refreshing (prevents shuffling)
                    child: isRefreshingProvider
                        ? _buildShimmerLoading(context)
                        : departmentsAsync.when(
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
        ),
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
                          width: 100,
                          height: 100,
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
                    // const SizedBox(height: 6),
                    // Department name
                    // Text(
                    //   department.departmentName,
                    //   style: TextStyle(
                    //     color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    //     fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    //     fontSize: 11,
                    //   ),
                    //   textAlign: TextAlign.center,
                    //   maxLines: 2,
                    //   overflow: TextOverflow.ellipsis,
                    // ),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 150,
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
  return GestureDetector(
    key: ValueKey('category_${category.categoryId}'),
    onTap: () {
      final departmentId = _currentDepartmentId ?? '';
      context.push(
        '/subcategory/${category.categoryId}/$departmentId/${Uri.encodeComponent(category.categoryName)}',
      );
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 85,
          width: double.infinity,
          child: CachedNetworkImageWidget(
            imageUrl: category.imageLink,
            fit: BoxFit.contain,
            placeholder: const SizedBox.shrink(),
            errorWidget: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey[400],
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          category.categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
                crossAxisCount: 3,
                mainAxisExtent: 150,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 6,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 85,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 70,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
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
}