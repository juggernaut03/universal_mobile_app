// lib/presentation/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/widgets/bottom_navigation_widget.dart';
import 'package:patelmart/core/widgets/empty_state_widget.dart';
import 'package:patelmart/core/widgets/header_widget.dart';
import 'package:patelmart/core/widgets/search_widget.dart';
import 'package:patelmart/presentation/features/cart/widgets/persistent_cart_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/category_grid_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/home_categories_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/popular_categories_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/promotional_banner_widget.dart';
import 'package:patelmart/presentation/features/home/widgets/best_seller_widget.dart';
import 'package:patelmart/presentation/providers/best_seller_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/back_handler.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/category_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _currentNavIndex = 0;
  bool _isAppBarCollapsed = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrollOffset = _scrollController.offset;
    final isCollapsed = scrollOffset > 45;
    
    if (isCollapsed != _isAppBarCollapsed) {
      setState(() {
        _isAppBarCollapsed = isCollapsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPincode = ref.watch(selectedPincodeProvider);
    final logger = ref.read(loggerProvider);
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final now = DateTime.now();
          final exitConfirmTime = const Duration(seconds: 2);
          
          if (_lastBackPressTime == null || 
              now.difference(_lastBackPressTime!) > exitConfirmTime) {
            
            // First back press
            _lastBackPressTime = now;
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
              ),
            );
            
            logger.log('First back press on Home, showing exit confirmation');
          } else {
            // Second back press - exit app
            logger.log('Second back press on Home, exiting app');
            // This will pop the route and exit the app since this is the root route
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          toolbarHeight: 56,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/images/patelLogo.png', // Replace with your actual logo
                height: 32,
                fit: BoxFit.contain,
              ),
            ],
          ),
          titleSpacing: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
              onPressed: () {
                // Navigate to favorites
              },
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              onPressed: () {
                context.push('/cart');
              },
              padding: const EdgeInsets.only(right: 16),
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            // Header with delivery location
            HeaderWidget(
              pincode: selectedPincode ?? 'Not Set',
              onChangeTap: () => context.go('/location-change'),
            ),
            
            // Sticky search bar that appears when scrolled
            if (_isAppBarCollapsed) 
              SearchWidget(
                controller: _searchController,
                onSearch: (query) {
                  // Handle search
                },
              ),
            
            // Main content with scrollview
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Refresh data providers
                  await ref.read(bestSellerRefreshProvider)();
                  ref.refresh(promotionalBannersProvider);
                  ref.refresh(departmentsProvider);
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Search bar at the top that disappears when scrolled
                    if (!_isAppBarCollapsed)
                      SliverToBoxAdapter(
                        child: SearchWidget(
                          controller: _searchController,
                          onSearch: (query) {
                            // Handle search
                          },
                        ),
                      ),

                    // Popular Categories Widget
                    SliverToBoxAdapter(
                      child: PopularCategoriesWidget(
                        height: 135,
                        imageSize: 70,
                        crossAxisCount: 4,
                        showTitle: false,
                        title: 'Popular Category',
                        showViewAll: false,
                        onViewAllTap: () => context.go('/category'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    
                    // Main Promotional Banner
                    SliverToBoxAdapter(
                      child: const PromotionalBannerWidget(
                        height: 280,
                        autoPlay: true,
                        autoPlayInterval: Duration(seconds: 5),
                        enlargeCenterPage: true,
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                      ),
                    ),
                    
                    // Best Seller 1
                    SliverToBoxAdapter(
                      child: BestSellerWidget(
                        bestSellerId: 1,
                        title: 'Today\'s Special',
                        height: 320,
                        showViewAll: true,
                        onViewAllTap: () {
                          // Navigate to see all products from this best seller
                        },
                      ),
                    ),
                    
                    // Best Seller 2
                    SliverToBoxAdapter(
                      child: BestSellerWidget(
                        bestSellerId: 2,
                        title: 'Best Deals',
                        height: 320,
                        showViewAll: true,
                        onViewAllTap: () {
                          // Navigate to see all products from this best seller
                        },
                      ),
                    ),
                    
                    // Best Seller 3
                    SliverToBoxAdapter(
                      child: BestSellerWidget(
                        bestSellerId: 3,
                        title: 'Chai Time',
                        height: 320,
                        showViewAll: true,
                        onViewAllTap: () {
                          // Navigate to see all products from this best seller
                        },
                      ),
                    ),
                    
                    // Best Seller 4
                    SliverToBoxAdapter(
                      child: BestSellerWidget(
                        bestSellerId: 4,
                        title: 'Top Picks For You',
                        height: 320,
                        showViewAll: true,
                        onViewAllTap: () {
                          // Navigate to see all products from this best seller
                        },
                      ),
                    ),
                           SliverToBoxAdapter(
                      child: HomeCategoriesWidget(
                        sections: const [
                          SectionData(
                            title: 'Bite Into Biscuits', 
                            keywords: ['biscuit', 'cookie', 'bakery', 'snack']
                          ),
                          SectionData(
                            title: 'Munch On Snacks', 
                            keywords: ['snack', 'namkeen', 'chips', 'food']
                          ),
                        ],
                        onDepartmentTap: (department) {
                          // Handle department tap (view all)
                          ref.read(selectedDepartmentProvider.notifier).state = department;
                          context.go('/category');
                        },
                      ),
                    ),

                    // Extra space at the bottom to ensure scrollability
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 60),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // This is our new persistent cart widget
            const PersistentCartWidget(),
            
            BottomNavigationWidget(
              currentIndex: _currentNavIndex,
              onTap: (index) {
                setState(() {
                  _currentNavIndex = index;
                });
                switch (index) {
                  case 0: // Home
                    if (context.mounted) context.go('/home');
                    break;
                  case 1: // Category
                    if (context.mounted) context.go('/category');
                    break;
                  case 2: // Cart/Order
                    if (context.mounted) context.go('/cart');
                    break;
                  case 3: // Reorder
                    if (context.mounted) context.go('/reorder');
                    break;
                  case 4: // Account
                    context.go('/account');
                    break;
                }
              },
            ),
          ]
        ),
      )
    );
  }

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
                  title: const Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/help-support');
                  },
                ),
                const Divider(height: 1),
                
                // Refund, Terms and Policies
                ListTile(
                  leading: Icon(Icons.description_outlined, color: AppColors.primary),
                  title: const Text('Refund, Terms and Policies'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/refund-policies');
                  },
                ),
                const Divider(height: 1),
                
                // Frequently Asked Questions
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  title: const Text('Frequently Asked Questions'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/faq');
                  },
                ),
                const Divider(height: 1),
                
                // About Us
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('About Us'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/about-us');
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
}