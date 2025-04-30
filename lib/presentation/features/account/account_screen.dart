// lib/presentation/features/account/account_screen.dart (updated version)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bottom_navigation_widget.dart';
import '../../providers/splash_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/auth_providers.dart'; // Added for auth status

class AccountScreen extends ConsumerWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    final isLoggedInAsync = ref.watch(isLoggedInProvider);
    final int _navIndex = 4; // Account tab selected by default

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Patel\'s Rmart',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              ],
            ),
            onPressed: () {
              context.push('/cart');
            },
          ),
        ],
      ),
      
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // User Profile menu item - NEW
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
                          // context.push('/orders');
                        } else {
                          // Go to login first if not logged in
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/orders'
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
                          // context.push('/saved-list');
                        } else {
                          // Go to login first if not logged in
                          context.push('/auth/login', extra: {
                            'redirectRoute': '/saved-list'
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
                          // Navigate to reorder screen
                          // context.push('/reorder');
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
                    child: _buildSavingsBanner(context),
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
              // Placeholder for orders navigation
              break;
            case 3: // Reorder
              // Placeholder for reorder navigation
              break;
            case 4: // Account
              // Already on account, do nothing
              break;
          }
        },
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

  Widget _buildSavingsBanner(BuildContext context) {
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
                    // Navigate to savings page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Check My Savings'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Use Lottie animation here
          SizedBox(
            width: 100,
            height: 100,
            child: Lottie.asset(
              'assets/images/saving.json', // Make sure to add this to your pubspec.yaml
              fit: BoxFit.contain,
            ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You have been signed out'),
                ),
              );
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