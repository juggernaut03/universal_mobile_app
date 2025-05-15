// lib/presentation/features/category/category_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
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
  // Controllers for department and category lists
  final ScrollController _departmentsController = ScrollController();
  final ScrollController _categoriesController = ScrollController();
  
  // Keep track of departments and categories
  List<DepartmentModel> _departments = [];
  Map<String, List<CategoryModel>> _categoriesByDepartment = {};
  Map<String, double> _departmentHeights = {}; // Cache for department positions
  
  // Current department and navigation index
  String? _currentDepartmentId;
  int _navIndex = 1; // Category tab selected by default
  
  // Flags for tracking scroll synchronization
  bool _isUserScrollingDepartments = false;
  bool _isUserScrollingCategories = false;
  bool _isProgrammaticScroll = false; // Prevent recursive sync
  bool _isRefreshing = false;
  
  @override
  void initState() {
    super.initState();
    
    // Listen to department scrolling
    _departmentsController.addListener(() {
      if (_isUserScrollingDepartments && !_isProgrammaticScroll) {
        // Don't update if this is a programmatic scroll
        // Department selection is handled by tapping, not scrolling
      }
    });
    
    // Listen to category scrolling to synchronize with departments
    _categoriesController.addListener(() {
      if (_isUserScrollingCategories && !_isProgrammaticScroll && _departments.isNotEmpty) {
        // Debouncing scroll events to improve performance
        _debounceSyncDepartments();
      }
    });
  }
  
  // Debounce timer for smoother sync
  DateTime? _lastScrollTime;
  
  void _debounceSyncDepartments() {
    final now = DateTime.now();
    _lastScrollTime = now;
    
    // Debounce scroll events (wait for scrolling to settle)
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_lastScrollTime == now && mounted) {
        _syncDepartmentWithCategoryScroll();
      }
    });
  }
  
  @override
  void dispose() {
    _departmentsController.dispose();
    _categoriesController.dispose();
    super.dispose();
  }
  
  // Initialize and pre-calculate data
  void _initializeData(List<DepartmentModel> departments, Map<String, List<CategoryModel>> categoriesByDepartment) {
    _departments = departments;
    _categoriesByDepartment = categoriesByDepartment;
    
    // Set initial selected department if not set yet
    if (_currentDepartmentId == null && departments.isNotEmpty) {
      _currentDepartmentId = departments[0].departmentId;
      departments[0] = departments[0].copyWith(isSelected: true);
    }
    
    // Pre-calculate heights for efficiency
    _calculateDepartmentHeights();
  }
  
  // Pre-calculate all department section heights for faster lookup
  void _calculateDepartmentHeights() {
    double accumulatedHeight = 0;
    _departmentHeights.clear();
    
    for (final department in _departments) {
      final departmentId = department.departmentId;
      final categories = _categoriesByDepartment[departmentId] ?? [];
      
      _departmentHeights[departmentId] = accumulatedHeight;
      
      final categoryHeight = 180.0;
      final rows = (categories.length / 2).ceil();
      final departmentHeaderHeight = 50.0;
      final sectionHeight = rows * categoryHeight + departmentHeaderHeight;
      
      accumulatedHeight += sectionHeight;
    }
  }
  
  // Synchronize department selection with category scroll position
  void _syncDepartmentWithCategoryScroll() {
    if (_departments.isEmpty || _categoriesByDepartment.isEmpty) {
      return;
    }
    
    // Get the scroll position
    final scrollPosition = _categoriesController.position.pixels;
    final viewportHeight = _categoriesController.position.viewportDimension;
    final maxScrollExtent = _categoriesController.position.maxScrollExtent;
    
    // Early exit if at the beginning of the list - always select first department
    if (scrollPosition < 10) {
      _updateSelectedDepartment(_departments[0].departmentId);
      return;
    }
    
    // Early exit if at the end of the list - always select last department
    if (scrollPosition > maxScrollExtent - 10) {
      _updateSelectedDepartment(_departments.last.departmentId);
      return;
    }
    
    // Better logic to determine the visible department based on viewport center
    final viewportCenter = scrollPosition + (viewportHeight / 3); // Focus on upper third
    
    // Find which department contains the viewport center
    String? visibleDepartmentId;
    
    // Use binary search if we have many departments, otherwise linear scan
    if (_departments.length > 15) {
      // Binary search implementation would go here
      // Omitted for brevity - linear scan is sufficient for typical category counts
    } else {
      // Linear scan through departments to find which one contains the viewport center
      double accumulatedHeight = 0;
      
      for (int i = 0; i < _departments.length; i++) {
        final departmentId = _departments[i].departmentId;
        final categories = _categoriesByDepartment[departmentId] ?? [];
        
        final categoryHeight = 180.0;
        final rows = (categories.length / 2).ceil();
        final departmentHeaderHeight = 50.0;
        final sectionHeight = rows * categoryHeight + departmentHeaderHeight;
        
        final sectionStart = accumulatedHeight;
        final sectionEnd = sectionStart + sectionHeight;
        
        // Check if viewport center is within this department's section
        if (viewportCenter >= sectionStart && viewportCenter < sectionEnd) {
          visibleDepartmentId = departmentId;
          break;
        }
        
        accumulatedHeight = sectionEnd;
      }
    }
    
    // If we found a visible department, update selection
    if (visibleDepartmentId != null) {
      _updateSelectedDepartment(visibleDepartmentId);
    }
  }
  
  // Update the selected department and UI
  void _updateSelectedDepartment(String departmentId) {
    if (departmentId == _currentDepartmentId) return;
    
    setState(() {
      _currentDepartmentId = departmentId;
      
      // Update selected state in departments list
      for (int i = 0; i < _departments.length; i++) {
        final isSelected = _departments[i].departmentId == departmentId;
        _departments[i] = _departments[i].copyWith(isSelected: isSelected);
      }
    });
    
    // Scroll the departments list to show the selected department
    final selectedIndex = _departments.indexWhere(
      (dept) => dept.departmentId == departmentId
    );
    
    if (selectedIndex >= 0) {
      _scrollDepartmentIntoView(selectedIndex);
    }
  }
  
  // Scroll department into view
  void _scrollDepartmentIntoView(int index) {
    if (_departmentsController.hasClients) {
      final departmentHeight = 90.0; // Updated estimated height
      final targetPosition = index * departmentHeight;
      
      // Only scroll if needed
      if (targetPosition < _departmentsController.position.pixels ||
          targetPosition > _departmentsController.position.pixels + _departmentsController.position.viewportDimension) {
        // Set flag to prevent recursive scrolling
        _isProgrammaticScroll = true;
        
        _departmentsController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ).then((_) {
          // Reset flag after animation with a small delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _isProgrammaticScroll = false;
            }
          });
        });
      }
    }
  }
  
  // Select a department and scroll to its categories
  void _selectDepartment(DepartmentModel department) {
    // Update state and UI
    setState(() {
      _currentDepartmentId = department.departmentId;
      
      // Update selected state in departments list
      for (int i = 0; i < _departments.length; i++) {
        final isSelected = _departments[i].departmentId == department.departmentId;
        _departments[i] = _departments[i].copyWith(isSelected: isSelected);
      }
    });
    
    // Scroll to the department's categories
    _scrollToCategories(department.departmentId);
  }
  
  // Scroll to categories for a specific department
  void _scrollToCategories(String departmentId) {
    // Use cached position if available
    double targetPosition = _departmentHeights[departmentId] ?? 0;
    
    // If not cached, calculate position
    if (targetPosition == 0 && departmentId != _departments.first.departmentId) {
      // Calculate position to scroll to with more precision
      for (int i = 0; i < _departments.length; i++) {
        final id = _departments[i].departmentId;
        
        if (id == departmentId) {
          break;
        }
        
        final categories = _categoriesByDepartment[id] ?? [];
        final categoryHeight = 180.0;
        final rows = (categories.length / 2).ceil();
        final departmentHeaderHeight = 50.0;
        targetPosition += rows * categoryHeight + departmentHeaderHeight;
      }
    }
    
    // Set flag to prevent recursive scrolling
    _isProgrammaticScroll = true;
    
    // Use better animation curve and duration for smoother scrolling
    _categoriesController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    ).then((_) {
      // Add a small delay before allowing synchronization again
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isProgrammaticScroll = false;
        }
      });
    });
  }
  
  // Build shimmer loading effect for the entire screen
  Widget _buildShimmerLoading(BuildContext context) {
    return Row(
      children: [
        // Left side: Departments shimmer (30% width)
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.3,
          child: _buildDepartmentsShimmer(),
        ),
        
        // Right side: Categories shimmer (70% width)
        Expanded(
          child: _buildCategoriesShimmer(),
        ),
      ],
    );
  }

  // Shimmer for departments list
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
          itemCount: 8, // Show 8 skeleton items
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                children: [
                  // Department image placeholder
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Department name placeholder
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Second line of department name placeholder
                  Container(
                    width: 60,
                    height: 10,
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

  // Shimmer for categories grid
  Widget _buildCategoriesShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // First department label
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
            
            // First department categories
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 4, // Show 4 skeleton items
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
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
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: double.infinity,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Second department label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: 170,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            
            // Second department categories
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8, 
              ),
              itemCount: 6, // Show 6 skeleton items
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
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
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: double.infinity,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
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
      // Handle refresh error
      final logger = ref.read(loggerProvider);
      logger.error('Error refreshing categories: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.red,
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
  
  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentsProvider);
    final allCategoriesAsync = ref.watch(allCategoriesProvider);
    final logger = ref.read(loggerProvider);
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    
    // Return the screen structure
    return BackButtonWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('SHOP BY CATEGORY'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Handle search
              },
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () {
                // Handle cart
                context.push('/cart');
              },
              padding: const EdgeInsets.only(right: 16),
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            // Main content: Departments and Categories
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: departmentsAsync.when(
                  data: (departments) {
                    return allCategoriesAsync.when(
                      data: (categoriesByDepartment) {
                        // Initialize data with pre-calculation
                        _initializeData(departments, categoriesByDepartment);
                        
                        // Force a check of the current scroll position to update selection if needed
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_categoriesController.hasClients && mounted) {
                            _syncDepartmentWithCategoryScroll();
                          }
                        });
                        
                        return Row(
                          children: [
                            // Left side: Departments (30% width)
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.3,
                              child: _buildDepartmentList(departments),
                            ),
                            
                            // Right side: Categories (70% width)
                            Expanded(
                              child: _buildCategoriesList(categoriesByDepartment),
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
        bottomNavigationBar: BottomNavigationWidget(
          currentIndex: _navIndex,
          onTap: (index) {
            if (_navIndex == index) return; // Don't navigate if already on this tab
            
            setState(() {
              _navIndex = index;
            });
            switch (index) {
              case 0: // Home
                if (context.mounted) context.go('/home');
                break;
              case 1: // Category
                // Already on category, do nothing
                break;
              case 2: // Cart/Order
                // Placeholder for cart navigation
                context.go('/cart');
                break;
              case 3: // Reorder
                // Placeholder for reorder navigation
                context.go('/reorder');
                break;
              case 4: // Account
                // Placeholder for account navigation
                context.go('/account');
                break;
            }
          },
        ),
      ),
    );
  }
  
  // Build drawer similar to home screen
  Widget _buildDrawer() {
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    
    return Drawer(
      child: Column(
        children: [
          // Drawer header with user info and location
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button and user greeting
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
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
                
                // Location with icon and edit button
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
                          '421301, Kalyan', // You can use actual pincode here
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
                        Navigator.pop(context);
                        context.go('/location-change');
                      },
                    ),
                  ],
                ),
                
                // Store logo
                Image.asset(
                  'assets/images/patelLogo.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          
          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Shop by category
                ListTile(
                  leading: Icon(Icons.grid_view, color: AppColors.primary),
                  title: const Text('SHOP BY CATEGORY'),
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/category');
                  },
                ),
                const Divider(height: 1),
                
                // Help @ Patel Rmart
                ListTile(
                  leading: Icon(Icons.help_outline, color: AppColors.primary),
                  title: const Text('Help @ Patel Rmart'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to help page
                  },
                ),
                const Divider(height: 1),
                
                // Refund, Terms and Policies
                ListTile(
                  leading: Icon(Icons.description_outlined, color: AppColors.primary),
                  title: const Text('Refund, Terms and Policies'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to terms page
                  },
                ),
                const Divider(height: 1),
                
                // Frequently Asked Questions
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  title: const Text('Frequently Asked Questions'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to FAQ page
                  },
                ),
                const Divider(height: 1),
                
                // About Us
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('About Us'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to about page
                  },
                ),
                const Divider(height: 1),
                
                // Adding the original options
                ListTile(
                  leading: Icon(Icons.store, color: AppColors.primary),
                  title: const Text('Store Information'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/store-info');
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.location_on, color: AppColors.primary),
                  title: const Text('Change Location'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/location-change');
                  },
                ),
                const Divider(height: 1),
                
                // App version at the bottom
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
  
  // Build the departments list (left side)
  Widget _buildDepartmentList(List<DepartmentModel> departments) {
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
      child: Listener(
        onPointerDown: (_) {
          // Track when user is scrolling departments
          _isUserScrollingDepartments = true;
        },
        onPointerUp: (_) {
          // End tracking when user stops scrolling
          _isUserScrollingDepartments = false;
        },
        child: ListView.builder(
          controller: _departmentsController,
          itemCount: departments.length,
          padding: EdgeInsets.zero,
          // Improved performance with better caching
          cacheExtent: departments.length * 90.0,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final department = departments[index];
            final isSelected = department.isSelected;
            
            return InkWell(
              onTap: () => _selectDepartment(department),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.grey[50],
                  border: Border(
                    left: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 4,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Column(
                  children: [
                  // In _buildDepartmentList method, replace the CachedNetworkImageWidget with:
ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: SizedBox(
    width: 50,
    height: 50,
    child: Image.network(
      department.imageLink,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[100],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[100],
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey[400],
            size: 24,
          ),
        );
      },
    ),
  ),
),
                    const SizedBox(height: 6),
                    Text(
                      department.departmentName,
                      style: isSelected
                          ? TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10, // Reduced font size
                            )
                          : TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10, // Reduced font size
                            ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  // Build the categories list (right side)
  Widget _buildCategoriesList(Map<String, List<CategoryModel>> categoriesByDepartment) {
    // Flatten the categories by department for continuous scrolling
    final allCategories = <Widget>[];
    
    // Add a department label at the top of each department's categories
    for (final entry in categoriesByDepartment.entries) {
      final departmentId = entry.key;
      final categories = entry.value;
      
      // Find the department name
      final department = _departments.firstWhere(
        (d) => d.departmentId == departmentId,
        orElse: () => DepartmentModel(
          id: '',
          departmentId: departmentId,
          departmentName: 'Unknown',
          imageLink: '',
          sequenceId: 0,
        ),
      );
      
      // Add department label
      allCategories.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              department.departmentName,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
      
      // Add categories in a grid
      allCategories.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.9,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _buildCategoryCard(category);
          },
        ),
      );
      
      // Add some space between departments
      allCategories.add(const SizedBox(height: 16));
    }
    
    // Listener to track when user is scrolling categories
    return Listener(
      onPointerDown: (_) {
        _isUserScrollingCategories = true;
      },
      onPointerUp: (_) {
        _isUserScrollingCategories = false;
      },
      child: ListView(
        controller: _categoriesController,
        children: allCategories,
        // Using cacheExtent to improve scrolling performance
        cacheExtent: 1000, // Cache more items for smoother scrolling
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(), // Better scroll physics for Android-style scrolling
        ),
      ),
    );
  }
  
  // Build a category card
  // Build a category card
Widget _buildCategoryCard(CategoryModel category) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    child: InkWell(
      onTap: () {
        // Navigate to subcategory screen with required parameters
        final departmentId = _departments.firstWhere(
          (d) => d.departmentId == _currentDepartmentId,
          orElse: () => DepartmentModel(
            id: '', 
            departmentId: '', 
            departmentName: '', 
            imageLink: '', 
            sequenceId: 0
          ),
        ).departmentId;
        
        context.push(
          '/subcategory/${category.categoryId}/$departmentId/${Uri.encodeComponent(category.categoryName)}',
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.network(
                category.imageLink,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              category.categoryName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12, // Reduced font size
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
}