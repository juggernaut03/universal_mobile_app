import 'package:go_router/go_router.dart';
import '../features/orders/my_orders_screen.dart';

// This class contains updates that need to be added to your existing app_router.dart file
class RouterUpdates {
  // Add these routes to your existing GoRouter configuration in app_router.dart
  static final List<RouteBase> orderRoutes = [
    // My Orders route
    GoRoute(
      path: '/my-orders',
      name: 'myOrders',
      builder: (context, state) => const MyOrdersScreen(),
    ),
  ];
}