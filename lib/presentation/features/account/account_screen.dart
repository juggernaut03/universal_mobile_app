// lib/presentation/features/account/account_screen.dart (updated with improved AppBar and Drawer)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bottom_navigation_widget.dart';
import '../../providers/splash_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/best_seller_providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    final isLoggedInAsync = ref.watch(isLoggedInProvider);
    final int _navIndex = 4; // Account tab selected by default

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, ref),
      drawer: _buildDrawer(context, ref),
      
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // User Profile menu item
                  _buildMenuItem(
                    context,
                    icon: Icons.person_outline,
                    title: 'My Profile',
                    onTap: () {
                      // Check login status before navigating to profile
                      isLoggedInAsync.whenData((isLoggedIn) {
                        if (isLoggedIn) {
                          // If logged in, go to profile screen
                          context.push('/profile');
                        } else {
                          // If not logged in, go to login screen first
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/profile'
                          });
                        }
                      });
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'My Orders',
                    onTap: () {
                      // Check login status before navigating
                      isLoggedInAsync.whenData((isLoggedIn) {
                        if (isLoggedIn) {
                          // Navigate to orders if logged in
                          context.push('/my-orders');
                        } else {
                          // Go to login first if not logged in
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/my-orders'
                          });
                        }
                      });
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.bookmark_border_outlined,
                    title: 'My Saved List',
                    onTap: () {
                      // Check login status
                      isLoggedInAsync.whenData((isLoggedIn) {
                        if (isLoggedIn) {
                          // Navigate to saved list if logged in
                          context.push('/favorites');
                        } else {
                          // Go to login first if not logged in
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/favorites'
                          });
                        }
                      });
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.replay_outlined,
                    title: 'Quick Reorder',
                    onTap: () {
                      // Check login status
                      isLoggedInAsync.whenData((isLoggedIn) {
                        if (isLoggedIn) {
                          context.push('/reorder');
                        } else {
                          // Go to login first
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/reorder'
                          });
                        }
                      });
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.location_on_outlined,
                    title: 'My Addresses',
                    onTap: () {
                      // Check login status
                      isLoggedInAsync.whenData((isLoggedIn) {
                        if (isLoggedIn) {
                          // Navigate to address book
                          context.go('/address-book');
                        } else {
                          // Go to login first if not logged in
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/address-book'
                          });
                        }
                      });
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.savings_outlined,
                    title: 'My Savings',
                    onTap: () {
                      // Check login status
                      isLoggedInAsync.whenData((isLoggedIn) {
                        if (isLoggedIn) {
                          context.push('/savings');
                        } else {
                          // Go to login first if not logged in
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/savings'
                          });
                        }
                      });
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.chat_bubble_outline,
                    title: 'Help @ Patel Rmart',
                    onTap: () {
                      // Navigate to help (no login required)
                      context.push('/help-support');
                    },
                  ),
                  _buildDivider(),
                  
                  // Conditionally show Sign In or Sign Out based on login status
                  isLoggedInAsync.when(
                    data: (isLoggedIn) {
                      return isLoggedIn 
                          ? _buildMenuItem(
                              context,
                              icon: Icons.logout,
                              title: 'Sign Out',
                              onTap: () {
                                // Handle sign out
                                _showSignOutConfirmation(context, ref);
                              },
                            )
                          : _buildMenuItem(
                              context,
                              icon: Icons.login,
                              title: 'Sign In',
                              onTap: () {
                                // Navigate to login
                                context.push('/auth/login');
                              },
                            );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, __) => _buildMenuItem(
                      context,
                      icon: Icons.login,
                      title: 'Sign In',
                      onTap: () {
                        // Navigate to login on error
                        context.push('/auth/login');
                      },
                    ),
                  ),
                  _buildDivider(),
                  
                  // Savings banner
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildSavingsBanner(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: _navIndex,
        onTap: (index) {
          if (_navIndex == index) return; // Don't navigate if already on this tab
          
          switch (index) {
            case 0: // Home
              context.go('/home');
              break;
            case 1: // Category
              context.go('/category');
              break;
            case 2: // Orders
              context.push('/cart');
              break;
            case 3: // Reorder
              if (context.mounted) context.go('/reorder');
              break;
            case 4: // Account
              // Already on account, do nothing
              break;
          }
        },
      ),
    );
  }

 PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
  final cartCount = ref.watch(cartCountProvider);
  final logger = ref.read(loggerProvider);
  
  return AppBar(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false, // Change to false to align title to the left
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/patelLogo.png',
          height: 42, // Increased from 32 to 40
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            logger.error('Error loading logo: $error');
            return const Icon(Icons.store, color: Colors.white, size: 40);
          },
        ),
      ],
    ),
    titleSpacing: 0, // Reduce spacing to move logo closer to drawer icon
    leading: Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
    ),
    actions: [
      // Wishlist/Favorites icon
      IconButton(
        icon: const Icon(Icons.favorite_border_outlined, color: Colors.white),
        onPressed: () {
          logger.log('Favorites button pressed from account screen');
          if (context.mounted) {
            context.push('/favorites');
          }
        },
      ),
      // Cart icon with badge
      Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            onPressed: () {
              logger.log('Cart button pressed from account screen');
              if (context.mounted) {
                context.push('/cart');
              }
            },
          ),
          if (cartCount > 0)
            Positioned(
              right: 0,
              top: 0,
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
      ),
    ],
  );
}
  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final selectedOutletAsync = ref.watch(selectedOutletProvider);
    final logger = ref.read(loggerProvider);
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final isLoggedInAsync = ref.watch(isLoggedInProvider);
    
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
                    // Show user status based on login
                    isLoggedInAsync.when(
                      data: (isLoggedIn) => Text(
                        isLoggedIn ? 'Hi, User' : 'Hi, Guest',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      loading: () => const Text(
                        'Hi, Guest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      error: (_, __) => const Text(
                        'Hi, Guest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                        logger.log('Edit location pressed from account drawer');
                        Navigator.pop(context);
                        if (context.mounted) {
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
                    logger.log('Shop by category pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
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
                    logger.log('View Cart pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.push('/cart');
                    }
                  },
                ),
                const Divider(height: 1),

                ListTile(
                  leading: Icon(Icons.favorite_border, color: AppColors.primary),
                  title: const Text('My Favorites'),
                  onTap: () {
                    logger.log('My Favorites pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.push('/favorites');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.help_outline, color: AppColors.primary),
                  title: const Text('Help & Support'),
                  onTap: () {
                    logger.log('Help & Support pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.go('/help-support');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.description_outlined, color: AppColors.primary),
                  title: const Text('Refund, Terms and Policies'),
                  onTap: () {
                    logger.log('Refund policies pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.go('/refund-policies');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  title: const Text('Frequently Asked Questions'),
                  onTap: () {
                    logger.log('FAQ pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.go('/faq');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('About Us'),
                  onTap: () {
                    logger.log('About Us pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.go('/about-us');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.store, color: AppColors.primary),
                  title: const Text('Store Information'),
                  onTap: () {
                    logger.log('Store Information pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.go('/store-info');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.location_on, color: AppColors.primary),
                  title: const Text('Change Location'),
                  onTap: () {
                    logger.log('Change Location pressed from account drawer');
                    Navigator.pop(context);
                    if (context.mounted) {
                      context.go('/location-change');
                    }
                  },
                ),
                const Divider(height: 1),
                
                ListTile(
                  leading: Icon(Icons.refresh, color: AppColors.primary),
                  title: const Text('Refresh All Best Sellers'),
                  onTap: () async {
                    logger.log('Refresh Best Sellers pressed from account drawer');
                    Navigator.pop(context);
                    await ref.read(bestSellerRefreshProvider)();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Best seller data refreshed'),
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.grey[600],
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
    );
  }

  Widget _buildSavingsBanner(BuildContext context, WidgetRef ref) {
    final isLoggedInAsync = ref.watch(isLoggedInProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD1EAD5), // Light mint green color
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You\'re SAVING a LOT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'on every order',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // Check login status before navigating to savings
                    isLoggedInAsync.whenData((isLoggedIn) {
                      if (isLoggedIn) {
                        context.push('/savings');
                      } else {
                        context.push('/auth/login', extra: {
                          'redirectRoute': '/savings'
                        });
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Check My Savings'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Use Lottie animation here or fallback to icon
          SizedBox(
            width: 100,
            height: 100,
            child: Icon(
              Icons.savings_outlined,
              size: 80,
              color: AppColors.primary.withOpacity(0.7),
            ),
            // TODO: Uncomment when Lottie asset is available
            // child: Lottie.asset(
            //   'assets/images/saving.json',
            //   fit: BoxFit.contain,
            // ),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Perform sign out logic here
              await ref.read(logoutProvider)();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You have been signed out'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}