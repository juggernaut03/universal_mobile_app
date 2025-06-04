// lib/presentation/routes/app_router.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/data/models/order_model.dart';
import 'package:patelmart/presentation/features/account/savings_screen.dart';
import 'package:patelmart/presentation/features/best_seller/best_seller_screen.dart';
import 'package:patelmart/presentation/features/account/add_address_screen.dart';
import 'package:patelmart/presentation/features/account/edit_address_screen.dart';
import 'package:patelmart/presentation/features/debug/access_key_debugger.dart';
import 'package:patelmart/presentation/features/favorites/favorites_screen.dart';
import 'package:patelmart/presentation/features/orders/my_orders_screen.dart';
import 'package:patelmart/presentation/features/orders/order_detail_screen.dart';
import 'package:patelmart/presentation/features/orders/reorder_screen.dart';
import 'package:patelmart/presentation/features/search/search_screen.dart';
import '../features/account/account_screen.dart';
import '../features/account/address_book_screen.dart';
import '../features/account/my_profile_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_validation_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/category/category_screen.dart';
import '../features/checkout/checkout_flow_screen.dart';
import '../features/home/home_screen.dart';
import '../features/location/location_change_screen.dart';
import '../features/location/outlet_selection_screen.dart';
import '../features/location/pincode_selection_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/product/single_product_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/store/store_info_screen.dart';
import '../features/subcategory/subcategory_screen.dart';
import '../providers/auth_providers.dart';
import '../providers/launch_flow_provider.dart';
import '../providers/location_provider.dart';
import '../providers/outlet_provider.dart';
import '../providers/splash_provider.dart';
import '../features/support/about_us_screen.dart';
import '../features/support/faq_screen.dart';
import '../features/support/help_support_screen.dart';
import '../features/support/refund_tnc_screen.dart';
import 'route_names.dart';

// Import for navigatorKey
import '../../main.dart';

// Import for debug screens
import '../features/debug/notification_debug_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final launchState = ref.watch(launchFlowProvider);
  final splashCompleted = ref.watch(splashCompletedProvider);
  final selectedPincode = ref.watch(selectedPincodeProvider);
  final logger = ref.read(loggerProvider);
  
  // Helper function to get address to edit from shared preferences
  Address _getAddressToEdit(BuildContext context) {
    try {
      final prefs = ProviderScope.containerOf(context).read(sharedPreferencesProvider);
      final addressJson = prefs.getString('address_to_edit');
      if (addressJson != null) {
        final addressMap = jsonDecode(addressJson);
        return Address.fromJson(addressMap);
      }
    } catch (e) {
      logger.error('Error getting address to edit: $e');
    }
    
    // Return a default empty address if something fails
    return Address(
      id: '',
      fullName: '',
      mobileNumber: '',
      emailId: '',
      deliveryAddrLine1: '',
      deliveryAddrLine2: '',
      deliveryAddrCity: '',
      deliveryAddrPincode: '',
      isDefault: 'No',
      areaId: '1',
    );
  }
  
  return GoRouter(
    navigatorKey: navigatorKey, // ADD GLOBAL NAVIGATOR KEY HERE
    initialLocation: '/',
    debugLogDiagnostics: true, // Enable logging for debugging
    redirect: (context, state) {
      // Get current path
      final path = state.uri.path;
      
      logger.log('Router redirect: Path: $path, LaunchState: $launchState, SplashCompleted: $splashCompleted');
      
      // Never return to splash once it's completed
      if (splashCompleted && (path == '/' || path == '/splash')) {
        if (launchState == AppLaunchState.firstLaunch) {
          logger.log('Redirecting to onboarding from splash (first launch)');
          return '/onboarding';
        } else if (launchState == AppLaunchState.needPincodeSelection) {
          logger.log('Redirecting to pincode selection from splash');
          return '/pincode-selection';
        } else if (launchState == AppLaunchState.needOutletSelection) {
          logger.log('Redirecting to outlet selection from splash');
          return '/outlet-selection';
        } else if (launchState == AppLaunchState.readyToLaunch || 
                  launchState == AppLaunchState.subsequentLaunch) {
          logger.log('Redirecting to home from splash (ready/subsequent)');
          return '/home';
        }
      }

      // If splash is not completed and initializing, stay on splash
      if (!splashCompleted && launchState == AppLaunchState.initializing) {
        if (path != '/' && path != '/splash') {
          logger.log('Redirecting to splash (not completed yet)');
          return '/';
        }
        return null; // Stay on splash
      }

      // Don't redirect for these screens when in ready state
      if ((path == '/location-change' || path == '/store-info' || 
          path.startsWith('/product/') || path.startsWith('/subcategory/') ||
          path == '/profile' || path == '/checkout-flow' ||
          path.startsWith('/debug/')) && // Allow debug routes
          (launchState == AppLaunchState.readyToLaunch || 
           launchState == AppLaunchState.subsequentLaunch)) {
        return null;
      }
      
      // Don't redirect for auth screens
      if (path == '/auth/login' || path == '/auth/otp') {
        return null;
      }

      // Normal flow redirects based on launch state after splash is completed
      if (splashCompleted) {
        switch (launchState) {
          case AppLaunchState.firstLaunch:
            if (path != '/onboarding') {
              logger.log('Redirecting to onboarding from $path (first launch)');
              return '/onboarding';
            }
            break;
          
          case AppLaunchState.needLocationPermission:
            if (path != '/pincode-selection') {
              logger.log('Redirecting to pincode selection from $path (need location permission)');
              return '/pincode-selection';
            }
            break;
          
          case AppLaunchState.needPincodeSelection:
            if (path != '/pincode-selection') {
              logger.log('Redirecting to pincode selection from $path (need pincode selection)');
              return '/pincode-selection';
            }
            break;
          
          case AppLaunchState.needOutletSelection:
            if (path != '/outlet-selection') {
              logger.log('Redirecting to outlet selection from $path (need outlet selection)');
              return '/outlet-selection';
            }
            break;
          
          case AppLaunchState.readyToLaunch:
          case AppLaunchState.subsequentLaunch:
            // Only redirect these paths, allow all others (for back navigation)
            if (path == '/onboarding' || 
                path == '/pincode-selection' || 
                (path == '/outlet-selection' && path != state.matchedLocation)) {
              logger.log('Redirecting to home from $path (ready to launch)');
              return '/home';
            }
            break;
            
          case AppLaunchState.initializing:
            // This shouldn't happen if splash is completed
            return '/';
        }
      }
      
      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(
          logoAsset: 'assets/images/patelLogo.png',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/pincode-selection',
        name: RouteNames.pincodeSelection,
        builder: (context, state) {
          // Check if we're in location fetching state and show loading
          final launchState = ProviderScope.containerOf(context).read(launchFlowProvider);
          if (launchState == AppLaunchState.needLocationPermission) {
            // If we're in this state, trigger the location fetching
            // This ensures location fetching happens even if we navigate directly here
            Future.microtask(() {
              ProviderScope.containerOf(context)
                  .read(launchFlowProvider.notifier)
                  .fetchLocationAndCheckPincode();
            });
          }
          
          // Always show normal pincode selection - it'll handle loading state internally
          return const PincodeSelectionScreen();
        },
      ),
      GoRoute(
        path: '/outlet-selection',
        name: RouteNames.outletSelection,
        builder: (context, state) {
          final pincode = ProviderScope.containerOf(context)
              .read(selectedPincodeProvider);
          if (pincode == null) {
            return const PincodeSelectionScreen();
          }
          return OutletSelectionScreen(pincode: pincode);
        },
      ),
      GoRoute(
        path: '/home',
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/location-change',
        name: RouteNames.locationChange,
        builder: (context, state) => const LocationChangeScreen(),
      ),
      GoRoute(
        path: '/store-info',
        name: RouteNames.storeInfo,
        builder: (context, state) => const StoreInfoScreen(),
      ),
      GoRoute(
        path: '/account',
        name: RouteNames.account,
        builder: (context, state) => const AccountScreen(),
        // redirect: (context, state) async {
        //   // Check if user is logged in
        //   final container = ProviderScope.containerOf(context);
        //   final authRepository = container.read(authRepositoryProvider);
          
        //   final isLoggedIn = await authRepository.isLoggedIn();
        //   if (!isLoggedIn) {
        //     return '/auth/login?redirectRoute=/account';
        //   }
        //   return null;
        // },
      ),
      GoRoute(
        path: '/category',
        name: RouteNames.category,
        builder: (context, state) => const CategoryScreen(),
      ),
      // Subcategory route
      GoRoute(
        path: '/subcategory/:categoryId/:deptId/:categoryName',
        name: RouteNames.subcategory,
        builder: (context, state) => SubcategoryScreen(
          categoryId: state.pathParameters['categoryId'] ?? '',
          deptId: state.pathParameters['deptId'] ?? '',
          categoryName: state.pathParameters['categoryName'] ?? '',
        ),
      ),
      // Orders routes
      GoRoute(
        path: '/my-orders',
        name: RouteNames.myOrders,
        builder: (context, state) => const MyOrdersScreen(),
        redirect: (context, state) async {
          // Check if user is logged in
          final container = ProviderScope.containerOf(context);
          final authRepository = container.read(authRepositoryProvider);
          
          final isLoggedIn = await authRepository.isLoggedIn();
          if (!isLoggedIn) {
            return '/auth/login?redirectRoute=/my-orders';
          }
          return null;
        },
      ),

      GoRoute(
        path: '/savings',
        name: RouteNames.savings,
        builder: (context, state) => const SavingsScreen(),
        redirect: (context, state) async {
          // Check if user is logged in
          final container = ProviderScope.containerOf(context);
          final authRepository = container.read(authRepositoryProvider);
          
          final isLoggedIn = await authRepository.isLoggedIn();
          if (!isLoggedIn) {
            return '/auth/login?redirectRoute=/savings';
          }
          return null;
        },
      ),

      GoRoute(
        path: '/reorder',
        name: RouteNames.reorder,
        builder: (context, state) => const ReorderScreen(),
        redirect: (context, state) async {
          // Check if user is logged in
          final container = ProviderScope.containerOf(context);
          final authRepository = container.read(authRepositoryProvider);
          
          final isLoggedIn = await authRepository.isLoggedIn();
          if (!isLoggedIn) {
            return '/auth/login?redirectRoute=/reorder';
          }
          return null;
        },
      ),
      // Single product route
      GoRoute(
        path: '/product/:pCode',
        name: RouteNames.productDetail,
        builder: (context, state) {
          final pCode = state.pathParameters['pCode'] ?? '';
          // If storeCode is not provided in query params, use the selected outlet's store code
          final storeCode = state.uri.queryParameters['storeCode'] ?? 
            (ProviderScope.containerOf(context).read(selectedOutletProvider).value?.storeCode ?? 'TTL');
          
          return SingleProductScreen(
            pCode: pCode,
            storeCode: storeCode,
          );
        },
      ),
      // Profile route
      GoRoute(
        path: '/profile',
        name: RouteNames.profile,
        builder: (context, state) => const MyProfileScreen(),
        redirect: (context, state) async {
          // Check if user is logged in
          final container = ProviderScope.containerOf(context);
          final authRepository = container.read(authRepositoryProvider);
          
          final isLoggedIn = await authRepository.isLoggedIn();
          if (!isLoggedIn) {
            return '/auth/login?redirectRoute=/profile';
          }
          return null;
        },
      ),
      // Cart route
      GoRoute(
        path: '/cart',
        name: RouteNames.cart,
        builder: (context, state) => const CartScreen(),
      ),
      // Authentication routes
      GoRoute(
  path: '/auth/login',
  name: RouteNames.login,
  builder: (context, state) {
    final redirectRoute = state.uri.queryParameters['redirectRoute']; // ✅ From URL
    return LoginScreen(redirectRoute: redirectRoute);
  },
),
      
      GoRoute(
        path: '/auth/otp',
        name: RouteNames.otp,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final mobile = extra?['mobile'] as String? ?? '';
          final redirectRoute = extra?['redirectRoute'] as String?;
          return OtpValidationScreen(
            mobileNumber: mobile,
            redirectRoute: redirectRoute,
          );
        },
      ),
      // Legacy Checkout route (keeping for backward compatibility)
      GoRoute(
        path: '/checkout',
        name: RouteNames.checkout,
        redirect: (context, state) async {
          // Redirect to the new checkout flow
          return '/checkout-flow';
        },
      ),
      // New Checkout Flow route
      GoRoute(
  path: '/checkout-flow',
  name: RouteNames.checkoutFlow,
  builder: (context, state) => const CheckoutFlowScreen(),
  redirect: (context, state) async {
    // Check if user is logged in
    final container = ProviderScope.containerOf(context);
    final authRepository = container.read(authRepositoryProvider);
    
    final isLoggedIn = await authRepository.isLoggedIn();
    if (!isLoggedIn) {
      return '/auth/login?redirectRoute=/checkout-flow'; // ✅ Protected
    }
    return null;
  },
),
      // Support and help routes
      GoRoute(
        path: '/about-us',
        name: RouteNames.aboutUs,
        builder: (context, state) => const AboutUsScreen(),
      ),
      GoRoute(
        path: '/faq',
        name: RouteNames.faq,
        builder: (context, state) => const FAQScreen(),
      ),
      GoRoute(
        path: '/help-support',
        name: RouteNames.helpSupport,
        builder: (context, state) => const HelpSupportScreen(),
      ),
         GoRoute(
        path: '/refund',
        name: RouteNames.refundPolicies,
        builder: (context, state) => const RefundTncScreen(),
      ),
      GoRoute(
        path: '/favorites',
        name: RouteNames.favorites,
        builder: (context, state) => const FavoritesScreen(),
        redirect: (context, state) async {
          // Check if user is logged in
          final container = ProviderScope.containerOf(context);
          final authRepository = container.read(authRepositoryProvider);
          
          final isLoggedIn = await authRepository.isLoggedIn();
          if (!isLoggedIn) {
            return '/auth/login?redirectRoute=/favorites';
          }
          return null;
        },
      ),

      GoRoute(
        path: '/search',
        name: RouteNames.search,
        builder: (context, state) {
          final query = state.uri.queryParameters['query'];
          return SearchScreen(initialQuery: query);
        },
      ),
      // Address Book routes
      GoRoute(
        path: '/address-book',
        name: RouteNames.addressBook,
        builder: (context, state) => const AddressBookScreen(),
        // Optional: Add a redirect to check if user is logged in
        redirect: (context, state) async {
          // Get the repository reference
          final container = ProviderScope.containerOf(context);
          final authRepository = container.read(authRepositoryProvider);
          
          // Check if user is logged in
          final isLoggedIn = await authRepository.isLoggedIn();
          if (!isLoggedIn) {
            return '/auth/login?redirectRoute=/address-book';
          }
          return null;
        },
      ),
      // Add Address route with return to checkout support
      GoRoute(
        path: '/add-address',
        name: RouteNames.addAddress,
        builder: (context, state) {
          final returnToCheckout = state.extra is Map && (state.extra as Map).containsKey('returnToCheckout')
              ? (state.extra as Map)['returnToCheckout'] as bool
              : false;
          return AddAddressScreen(returnToCheckout: returnToCheckout);
        },
      ),
      // Edit Address route
      GoRoute(
        path: '/edit-address',
        name: RouteNames.editAddress,
        builder: (context, state) {
          // We'll need to retrieve the address from SharedPreferences directly in the route
          // since we're not passing it as a parameter
          return EditAddressScreen(
            returnToCheckout: state.extra is Map && (state.extra as Map).containsKey('returnToCheckout')
                ? (state.extra as Map)['returnToCheckout'] as bool
                : false,
          );
        },
      ),
      GoRoute(
        path: '/best-seller/:bestSellerId',
        name: RouteNames.bestSeller,
        builder: (context, state) {
          final bestSellerIdParam = state.pathParameters['bestSellerId'] ?? '1';
          final bestSellerId = int.tryParse(bestSellerIdParam) ?? 1;
          return BestSellerScreen(bestSellerId: bestSellerId);
        },
      ),
      
      // DEBUG ROUTES - Add these for debugging notifications and other features
      GoRoute(
        path: '/debug/notifications',
        name: RouteNames.debugNotifications,
        builder: (context, state) => const NotificationDebugScreen(),
      ),
      GoRoute(
        path: '/debug/access-key',
        name: RouteNames.debugAccessKey,
        builder: (context, state) => const AccessKeyDebuggerScreen(),
      ),
    ],
    
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Safe navigation back to home
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Page Not Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Route not found: ${state.uri}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
    // Add observers for better debugging
    observers: [
      GoRouterObserver(),
    ],
  );
});

// Custom GoRouter observer for better debugging
class GoRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('GoRouter: Pushed ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('GoRouter: Popped ${route.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    print('GoRouter: Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }
}

extension GoRouterExtensions on GoRouter {
  void pushOrderDetail(BuildContext context, Order order) {
    // Navigate to order detail screen using the Material page route
    // This is used instead of GoRouter navigation to easily pass the full Order object
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: order),
      ),
    );
  }
}