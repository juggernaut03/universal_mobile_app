import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/error_widgets.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/models/department_model.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/launch_flow_provider.dart';
import 'category_section.dart';

/// Widget that displays multiple category sections in the home screen,
/// automatically fetching data from category providers
class HomeCategoriesWidget extends ConsumerWidget {
  /// List of section data to display
  final List<SectionData> sections;
  
  /// Callback when a department view all button is tapped
  final Function(DepartmentModel)? onDepartmentTap;
  
  /// Show shimmer loading effect when data is loading
  final bool showShimmerLoading;
  
  /// Show error widget when error occurs
  final bool showError;

  const HomeCategoriesWidget({
    Key? key,
    this.sections = const [
      SectionData(title: 'Bite Into Biscuits', keywords: ['biscuit', 'cookie', 'bakery' , 'ghee','Grocery ' , 'staples']),
      SectionData(title: 'Munch On Snacks', keywords: ['beverages', 'bakery', 'food', 'biscuit', 'cookie', ]),
      SectionData(title: 'Fresh Fruits & Veggies', keywords: ['fruit', 'vegetable', 'fresh']),
      SectionData(title: 'Daily Essentials', keywords: ['dairy', 'milk', 'essentials', 'biscuit', 'cookie', 'bakery']),

    ],
    this.onDepartmentTap,
    this.showShimmerLoading = true,
    this.showError = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    final departmentsAsync = ref.watch(departmentsProvider);
    final allCategoriesAsync = ref.watch(allCategoriesProvider);

    return departmentsAsync.when(
      data: (departments) {
        return allCategoriesAsync.when(
          data: (categoriesByDepartment) {
            if (departments.isEmpty) {
              logger.log('No departments available for categories');
              return const SizedBox.shrink();
            }
            
            // Build list of category sections
            final List<Widget> sectionWidgets = [];
            
            for (final sectionData in sections) {
              final matchingDept = _findDepartmentByKeywords(
                departments, 
                sectionData.keywords
              );
              
              if (matchingDept != null) {
                final categories = categoriesByDepartment[matchingDept.departmentId] ?? [];
                
                if (categories.isNotEmpty) {
                  final items = categories.map(
                    (category) => CategoryItem.fromCategoryModel(
                      category, 
                      matchingDept.departmentId
                    )
                  ).toList();
                  
                  sectionWidgets.add(CategorySection(
                    title: sectionData.title,
                    items: items,
                    onViewAllTap: () => _handleViewAllTap(context, matchingDept),
                  ));
                }
              }
            }
            
            if (sectionWidgets.isEmpty) {
              logger.log('No matching departments found for category sections');
              return const SizedBox.shrink();
            }
            
            return Column(children: sectionWidgets);
          },
          loading: () => showShimmerLoading 
              ? _buildLoadingState()
              : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (error, stack) => showError
              ? _buildErrorState(error, () => ref.refresh(allCategoriesProvider))
              : const SizedBox.shrink(),
        );
      },
      loading: () => showShimmerLoading
          ? _buildLoadingState()
          : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (error, stack) => showError
          ? _buildErrorState(error, () => ref.refresh(departmentsProvider)) 
          : const SizedBox.shrink(),
    );
  }
  
  /// Find department that matches any of the keywords
  DepartmentModel? _findDepartmentByKeywords(
    List<DepartmentModel> departments, 
    List<String> keywords
  ) {
    for (final dept in departments) {
      final name = dept.departmentName.toLowerCase();
      for (final keyword in keywords) {
        if (name.contains(keyword.toLowerCase())) {
          return dept;
        }
      }
    }
    
    // No matching department found
    return null;
  }
  
  /// Handle view all button tap for a department
  void _handleViewAllTap(BuildContext context, DepartmentModel department) {
    if (onDepartmentTap != null) {
      onDepartmentTap!(department);
    } else {
      // Default navigation
      context.push('/category', extra: {'selectedDepartment': department});
    }
  }
  
  /// Build loading state shimmer
  Widget _buildLoadingState() {
    // TODO: Implement shimmer loading effect
    return SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  /// Build error state widget
  Widget _buildErrorState(Object error, VoidCallback onRetry) {
    return AppErrorWidget(
      errorType: ErrorType.generic, 
      message: 'Error loading categories. Please try again.',
      onRetry: onRetry,
    );
  }
}

/// Data class for defining category sections
class SectionData {
  /// Title to display in the category section
  final String title;
  
  /// Keywords to match against department names
  final List<String> keywords;
  
  const SectionData({
    required this.title,
    required this.keywords,
  });
}