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

class _CategoryScreenState extends ConsumerState<CategoryScreen> 
    with TickerProviderStateMixin {
  // Controllers for department and category lists
  final ScrollController _departmentsController = ScrollController();
  final ScrollController _categoriesController = ScrollController();
  
  // Animation controller for smooth transitions
  late AnimationController _animationController;
  
  // Keep track of departments and categories
  List<DepartmentModel> _departments = [];
  Map<String, List<CategoryModel>> _categoriesByDepartment = {};
  
  // Cached section heights for performance (updated for reduced padding)
  final Map<String, double> _sectionHeights = {};
  final Map<String, double> _sectionPositions = {};
  
  // Current selected department
  String? _currentDepartmentId;
  int _navIndex = 1; // Category tab selected by default
  
  // Scroll tracking flags
  bool _isDepartmentScrolling = false;
  bool _isCategoryScrolling = false;
  bool _isProgrammaticScroll = false;
  bool _isRefreshing = false;
  
  // Debouncing
  DateTime? _lastScrollTime;
  static const Duration _scrollDebounceDelay = Duration(milliseconds: 100);
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Set up scroll listeners with proper debouncing
    _setupScrollListeners();
  }
  
  void _setupScrollListeners() {
    // Category scroll listener for department synchronization
    _categoriesController.addListener(_onCategoryScroll);
    
    // Department scroll listener
    _departmentsController.addListener(_onDepartmentScroll);
  }
  
  void _onCategoryScroll() {
    if (_isProgrammaticScroll || _isDepartmentScrolling) return;
    
    _isCategoryScrolling = true;
    _debounceSync(() => _syncDepartmentWithCategoryScroll());
  }
  
  void _onDepartmentScroll() {
    // Only track manual scrolling, not programmatic
    if (!_isProgrammaticScroll) {
      _isDepartmentScrolling = true;
      
      // Stop tracking after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isDepartmentScrolling = false;
        }
      });
    }
  }
  
  void _debounceSync(VoidCallback callback) {
    final now = DateTime.now();
    _lastScrollTime = now;
    
    Future.delayed(_scrollDebounceDelay, () {
      if (_lastScrollTime == now && mounted && _isCategoryScrolling) {
        callback();
        _isCategoryScrolling = false;
      }
    });
  }
  
  @override
  void dispose() {
    _departmentsController.dispose();
    _categoriesController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _initializeData(
    List<DepartmentModel> departments, 
    Map<String, List<CategoryModel>> categoriesByDepartment
  ) {
    bool shouldRecalculate = false;
    
    if (_departments.length != departments.length || 
        _categoriesByDepartment.length != categoriesByDepartment.length) {
      shouldRecalculate = true;
    }
    
    _departments = List.from(departments);
    _categoriesByDepartment = Map.from(categoriesByDepartment);
    
    // Set initial selected department if none is selected
    if (_currentDepartmentId == null && departments.isNotEmpty) {
      _currentDepartmentId = departments[0].departmentId;
      _updateDepartmentSelection(_currentDepartmentId!);
      shouldRecalculate = true;
    }
    
    // Validate that current selection exists in new data
    if (_currentDepartmentId != null && 
        !departments.any((dept) => dept.departmentId == _currentDepartmentId)) {
      _currentDepartmentId = departments.isNotEmpty ? departments[0].departmentId : null;
      if (_currentDepartmentId != null) {
        _updateDepartmentSelection(_currentDepartmentId!);
      }
      shouldRecalculate = true;
    }
    
    // Pre-calculate section positions for smooth scrolling
    if (shouldRecalculate) {
      _calculateSectionPositions();
    }
    
    // Log current state for debugging
    final logger = ref.read(loggerProvider);
    logger.log('Initialized data - Current department: $_currentDepartmentId, Total departments: ${departments.length}');
  }
  
  void _calculateSectionPositions() {
    _sectionHeights.clear();
    _sectionPositions.clear();
    
    double currentPosition = 0;
    const double departmentHeaderHeight = 60.0; // Reduced header height
    const double categoryHeight = 200.0; // Reduced height for each category row
    const double sectionSpacing = 12.0; // Reduced spacing between sections
    
    // Log for debugging
    final logger = ref.read(loggerProvider);
    logger.log('Calculating section positions for ${_departments.length} departments');
    
    for (final department in _departments) {
      final departmentId = department.departmentId;
      final categories = _categoriesByDepartment[departmentId] ?? [];
      
      // Store the starting position of this section
      _sectionPositions[departmentId] = currentPosition;
      
      // Calculate section height
      final rows = (categories.length / 2).ceil().clamp(1, 10); // Ensure at least 1 row, max 10
      final categoriesHeight = rows * categoryHeight;
      final totalSectionHeight = departmentHeaderHeight + categoriesHeight + sectionSpacing;
      
      _sectionHeights[departmentId] = totalSectionHeight;
      currentPosition += totalSectionHeight;
      
      // Log each section for debugging
      logger.log('Department: ${department.departmentName}, Position: ${_sectionPositions[departmentId]}, Height: ${_sectionHeights[departmentId]}, Categories: ${categories.length}');
    }
    
    logger.log('Total scroll height: $currentPosition');
  }
  
  void _syncDepartmentWithCategoryScroll() {
    if (!_categoriesController.hasClients || _departments.isEmpty) return;
    
    final scrollOffset = _categoriesController.offset;
    final viewportHeight = _categoriesController.position.viewportDimension;
    
    // Find which department section is currently in view
    String? visibleDepartmentId = _findVisibleDepartment(scrollOffset, viewportHeight);
    
    if (visibleDepartmentId != null && visibleDepartmentId != _currentDepartmentId) {
      _updateDepartmentSelection(visibleDepartmentId);
      _scrollDepartmentIntoView(visibleDepartmentId);
    }
  }
  
  String? _findVisibleDepartment(double scrollOffset, double viewportHeight) {
    // Use a smaller offset to be more precise about which section is visible
    final targetOffset = scrollOffset + (viewportHeight * 0.1); // Changed from 0.3 to 0.1
    
    for (final department in _departments) {
      final departmentId = department.departmentId;
      final sectionStart = _sectionPositions[departmentId] ?? 0;
      final sectionHeight = _sectionHeights[departmentId] ?? 0;
      final sectionEnd = sectionStart + sectionHeight;
      
      // More precise visibility check
      if (targetOffset >= sectionStart && targetOffset < sectionEnd) {
        return departmentId;
      }
    }
    
    // If nothing matches exactly, find the closest section
    double minDistance = double.infinity;
    String? closestDepartmentId;
    
    for (final department in _departments) {
      final departmentId = department.departmentId;
      final sectionStart = _sectionPositions[departmentId] ?? 0;
      final distance = (targetOffset - sectionStart).abs();
      
      if (distance < minDistance) {
        minDistance = distance;
        closestDepartmentId = departmentId;
      }
    }
    
    return closestDepartmentId ?? _departments.firstOrNull?.departmentId;
  }
  
  void _updateDepartmentSelection(String departmentId) {
    if (departmentId == _currentDepartmentId) return;
    
    setState(() {
      _currentDepartmentId = departmentId;
      
      // Update selection state
      for (int i = 0; i < _departments.length; i++) {
        _departments[i] = _departments[i].copyWith(
          isSelected: _departments[i].departmentId == departmentId
        );
      }
    });
  }
  
  void _selectDepartment(DepartmentModel department) {
    if (department.departmentId == _currentDepartmentId) return;
    
    // Immediately update the selection to show visual feedback
    _updateDepartmentSelection(department.departmentId);
    
    // Then scroll to the categories for that department
    _scrollToCategories(department.departmentId);
    
    // Log for debugging
    final logger = ref.read(loggerProvider);
    logger.log('Selected department: ${department.departmentName} (ID: ${department.departmentId})');
  }
  
  void _scrollToCategories(String departmentId) {
    if (!_categoriesController.hasClients) return;
    
    final targetPosition = _sectionPositions[departmentId] ?? 0;
    
    // Log for debugging
    final logger = ref.read(loggerProvider);
    logger.log('Scrolling to department $departmentId at position $targetPosition');
    
    _setProgrammaticScroll(true);
    
    _categoriesController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 500), // Slightly slower for better UX
      curve: Curves.easeInOutCubic, // Smoother curve
    ).then((_) {
      _setProgrammaticScrollWithDelay(false, 500); // Longer delay to ensure scroll completes
      
      // Force a rebuild to ensure UI is in sync
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  void _scrollDepartmentIntoView(String departmentId) {
    if (!_departmentsController.hasClients) return;
    
    final departmentIndex = _departments.indexWhere(
      (dept) => dept.departmentId == departmentId
    );
    
    if (departmentIndex < 0) return;
    
    const double itemHeight = 100.0; // Reduced department item height
    final targetPosition = departmentIndex * itemHeight;
    final currentPosition = _departmentsController.offset;
    final viewportHeight = _departmentsController.position.viewportDimension;
    
    // Only scroll if the item is not fully visible
    if (targetPosition < currentPosition || 
        targetPosition > currentPosition + viewportHeight - itemHeight) {
      
      _setProgrammaticScroll(true);
      
      _departmentsController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ).then((_) {
        _setProgrammaticScrollWithDelay(false, 200);
      });
    }
  }
  
  void _setProgrammaticScroll(bool value) {
    _isProgrammaticScroll = value;
  }
  
  void _setProgrammaticScrollWithDelay(bool value, int delayMs) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _isProgrammaticScroll = value;
      }
    });
  }
  
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final refreshAction = ref.read(categoryRefreshProvider);
      await refreshAction();
      
      // Reset selections after refresh
      _currentDepartmentId = null;
      _sectionHeights.clear();
      _sectionPositions.clear();
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
                        _initializeData(departments, categoriesByDepartment);
                        
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
        controller: _departmentsController,
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
              onTap: () => _selectDepartment(department),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // REDUCED PADDING
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Department image - REDUCED PADDING
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
                    const SizedBox(height: 6), // REDUCED SPACING
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
  
  Widget _buildCategoriesList(Map<String, List<CategoryModel>> categoriesByDepartment) {
    final widgets = <Widget>[];
    
    for (int i = 0; i < _departments.length; i++) {
      final department = _departments[i];
      final categories = categoriesByDepartment[department.departmentId] ?? [];
      
      // Department header
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // FURTHER REDUCED MARGIN
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // FURTHER REDUCED PADDING
          decoration: BoxDecoration(
            color: AppColors.primaryLighter.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            department.departmentName,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
      
      // Categories grid
      if (categories.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10), // REDUCED PADDING
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.95, // Further increased for more compact layout
                crossAxisSpacing: 3, // FURTHER REDUCED SPACING
                mainAxisSpacing: 3, // FURTHER REDUCED SPACING
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(categories[index]);
              },
            ),
          ),
        );
      }
      
      // Spacing between sections
      if (i < _departments.length - 1) {
        widgets.add(const SizedBox(height: 6)); // FURTHER REDUCED SPACING
      }
    }
    
    return ListView(
      controller: _categoriesController,
      children: widgets,
      physics: const AlwaysScrollableScrollPhysics(),
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
              flex: 3, // Give more space to the image
              child: Padding(
                padding: const EdgeInsets.all(8.0), // REDUCED PADDING
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
              flex: 1, // Less space for text
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                child: Text(
                  category.categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 10,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // REDUCED PADDING
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
                  const SizedBox(height: 6), // REDUCED SPACING
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
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            for (int section = 0; section < 3; section++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // FURTHER REDUCED PADDING
                child: Container(
                  width: 150,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95, // Updated aspect ratio to match main grid
                  crossAxisSpacing: 3, // FURTHER REDUCED SPACING
                  mainAxisSpacing: 3, // FURTHER REDUCED SPACING
                ),
                itemCount: 4,
                padding: const EdgeInsets.symmetric(horizontal: 10), // REDUCED PADDING
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
                            padding: const EdgeInsets.all(8.0), // REDUCED PADDING
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
              const SizedBox(height: 6), // FURTHER REDUCED SPACING
            ],
          ],
        ),
      ),
    );
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
                  if (mounted) {
                    context.go('/category');
                  }
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
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title),
          trailing: const Icon(Icons.navigate_next),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}