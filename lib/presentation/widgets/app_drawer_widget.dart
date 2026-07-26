// lib/core/widgets/app_drawer_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../di/repository_providers.dart';
import '../../di/auth_providers.dart';

// Provider for the profile repository (removed local definition, use the global one from profile_repository.dart)



class AppDrawerWidget extends ConsumerWidget {
  const AppDrawerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: Colors.white, // Added white background color
      child: Column(
        children: [
          _buildDrawerHeader(context, ref),
          Expanded(child: _buildDrawerItems(context, ref)),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, WidgetRef ref) {
    return DrawerHeader(
      decoration: BoxDecoration(color: AppColors.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with back button and greeting
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: _buildUserGreeting(context, ref),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Location row
          _buildLocationRow(context, ref),
          
          const SizedBox(height: 8),
          
          // Logo space (commented out but structure preserved)
          // _buildLogoSection(),
        ],
      ),
    );
  }

  Widget _buildUserGreeting(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(quickLoginStatusProvider);
    
    if (!isLoggedIn) {
      return GestureDetector(
        onTap: () {
          Navigator.pop(context);
          context.go('/auth/login');
        },
        child: const Text(
          'Hi, Guest (Tap to Login)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    // User is logged in - show display name with optimized loading
    return Consumer(
      builder: (context, ref, _) {
        final displayNameAsync = ref.watch(userDisplayNameProvider);
        
        return displayNameAsync.when(
          data: (displayName) => Text(
            'Hi, $displayName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => _buildLoadingGreeting(),
          error: (error, _) => const Text(
            'Hi, User',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingGreeting() {
    return Row(
      children: [
        const Text(
          'Hi, ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          width: 60,
          height: 18,
          child: LinearProgressIndicator(
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        final selectedPincode = ref.watch(selectedPincodeProvider);
        return Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedPincode ?? 'No pincode selected',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }

  Widget _buildDrawerItems(BuildContext context, WidgetRef ref) {
    const drawerItems = [
      _DrawerItem(
        icon: Icons.grid_view,
        title: 'SHOP BY CATEGORY',
        route: '/category',
      ),
      _DrawerItem(
        icon: Icons.shopping_cart,
        title: 'View Cart',
        route: '/cart',
        showCartInfo: true,
      ),
      _DrawerItem(
        icon: Icons.help_outline,
        title: 'Help & Support',
        route: '/help-support',
      ),
      _DrawerItem(
        icon: Icons.description_outlined,
        title: 'Refund,Terms and Policies',
        route: '/refund',
      ),
      _DrawerItem(
        icon: Icons.chat_bubble_outline,
        title: 'Frequently Asked Questions',
        route: '/faq',
      ),
      _DrawerItem(
        icon: Icons.info_outline,
        title: 'About Us',
        route: '/about-us',
      ),
      _DrawerItem(
        icon: Icons.store,
        title: 'Store Information',
        route: '/store-info',
      ),
      _DrawerItem(
        icon: Icons.location_on,
        title: 'Change Location',
        route: '/location-change',
      ),
      _DrawerItem(
        icon: Icons.delete_outline,
        title: 'Delete Account',
        route: '/delete-account',
        isDeleteAccount: true,
      ),
    ];

    return Container(
      color: Colors.white, // Added white background for drawer items section
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: drawerItems.length + 1, // +1 for version info
        separatorBuilder: (context, index) => 
            index < drawerItems.length 
              ? const Divider(height: 1, thickness: 0.5) 
              : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index < drawerItems.length) {
            final item = drawerItems[index];
            return _DrawerItemTile(item: item);
          } else {
            return buildVersionInfo();
          }
        },
      ),
    );
  }

Widget buildVersionInfo() {
  return FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final packageInfo = snapshot.data!;
        final versionText = packageInfo.buildNumber.isNotEmpty
            ? 'Version ${packageInfo.version} (${packageInfo.buildNumber})'
            : 'Version ${packageInfo.version}';
        
        return Container(
          color: Colors.white, // Added white background for version info
          padding: const EdgeInsets.all(16.0),
          child: Text(
            versionText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
      
      return Container(
        color: Colors.white, // Added white background for loading state
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Loading version...',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    },
  );
}
}

// Optimized drawer item tile widget
class _DrawerItemTile extends ConsumerWidget {
  final _DrawerItem item;

  const _DrawerItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white, // Added white background for each list tile
      child: ListTile(
        leading: Icon(item.icon, color: AppColors.primary),
        title: Text(
          item.title,
          style: const TextStyle(fontSize: 16),
        ),
        trailing: item.showCartInfo 
          ? _buildCartTrailing(ref)
          : const Icon(Icons.navigate_next),
        onTap: () => item.isDeleteAccount 
          ? _handleDeleteAccount(context, ref)
          : _navigateFromDrawer(context, item.route),
      ),
    );
  }

  Widget _buildCartTrailing(WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    
    return cartCount > 0
      ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${cartTotal.toStringAsFixed(0)}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '$cartCount ${cartCount == 1 ? 'item' : 'items'}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ],
        )
      : const Icon(Icons.navigate_next);
  }

  void _handleDeleteAccount(BuildContext context, WidgetRef ref) {
    Navigator.pop(context); // Close drawer first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone and you will be signed out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Perform sign out logic (same as account screen)
              await ref.read(logoutProvider)();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You have been signed out'),
                    backgroundColor: Colors.green,
                  ),
                );
                // After logout, navigate to home screen
                context.pushReplacement('/home');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateFromDrawer(BuildContext context, String route) {
    Navigator.pop(context);
    if (context.mounted) {
      context.go(route);
    }
  }
}

// Simplified drawer item model
class _DrawerItem {
  final IconData icon;
  final String title;
  final String route;
  final bool showCartInfo;
  final bool isDeleteAccount;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
    this.showCartInfo = false,
    this.isDeleteAccount = false,
  });
}

final userDisplayNameProvider = FutureProvider.autoDispose<String>((ref) async {
  final userProfile = (await ref.read(authRepositoryProvider).currentSession()).valueOrNull;
  
  if (userProfile == null) {
    return 'Guest';
  }
  
  // Try to get cached profile data first from secure storage or local cache
  // If not available, fetch from API
  final profileRepository = ref.read(profileRepositoryProvider);
  try {
    final profileData = await profileRepository.getUserProfile();
    
    // Extract and format display name
    final firstName = profileData['first_name']?.toString().trim() ?? '';
    final lastName = profileData['last_name']?.toString().trim() ?? '';
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    } else {
      // Fallback to masked mobile number
      final mobile = userProfile.mobile;
      return mobile.length > 4 ? '***${mobile.substring(mobile.length - 4)}' : mobile;
    }
  } catch (e) {
    // On error, return mobile-based fallback
    final mobile = userProfile.mobile;
    return mobile.length > 4 ? '***${mobile.substring(mobile.length - 4)}' : mobile;
  }
});

// Simple login status provider for immediate UI updates
final quickLoginStatusProvider = Provider<bool>((ref) {
  final userProfileAsync = ref.watch(userProfileProvider);
  return userProfileAsync.valueOrNull != null;
});
