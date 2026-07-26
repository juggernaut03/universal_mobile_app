// lib/presentation/providers/reorder_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../../data/models/order_model.dart';
import 'cart_provider.dart';
import '../../di/auth_providers.dart';
import '../../di/repository_providers.dart';
import '../../di/infrastructure_providers.dart';

// Provider for OrderRepository
// orderRepositoryProvider now declared in lib/di/repository_providers.dart

// Provider to store and retrieve user orders - WITH LATEST DATE FIRST SORTING
final userOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final logger = ref.read(loggerProvider);
  logger.log('Fetching order history from provider');
  
  try {
    // Check if user is logged in
    final isLoggedIn = await ref.read(authRepositoryProvider).isSignedIn();
    
    if (isLoggedIn) {
      try {
        // Create and use OrderRepository
        // Was constructing its own OrderRepository with a fresh http.Client.
        // Uses the single wired instance from lib/di/repository_providers.dart.
        final orderRepository = ref.read(orderRepositoryProvider);
        
        logger.log('Calling getOrderHistory from API');
        final apiOrders = await orderRepository.getOrderHistory();
        
        if (apiOrders.isNotEmpty) {
          logger.log('Successfully fetched ${apiOrders.length} orders from API');
          
          // Sort by latest date first at frontend level
          apiOrders.sort((a, b) {
            final comparison = b.orderDate.compareTo(a.orderDate);
            return comparison;
          });
          
          logger.log('Orders sorted by latest date first');
          if (apiOrders.isNotEmpty) {
            logger.log('Latest order: ${apiOrders.first.orderId} - ${apiOrders.first.orderDate}');
          }
          
          return apiOrders;
        } else {
          logger.log('API returned empty order list');
        }
      } catch (e) {
        logger.error('Error fetching orders from API: $e - falling back to local storage');
        // Fall through to local storage on API failure
      }
    } else {
      logger.log('User not logged in, skipping API request');
    }
    
    // Get stored orders from SharedPreferences as fallback
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = prefs.getStringList('user_orders') ?? [];
    
    if (ordersJson.isEmpty) {
      logger.log('No orders found in local storage');
      return [];
    }
    
    // Convert JSON to Order objects
    final List<Order> orders = [];
    
    for (final orderJsonString in ordersJson) {
      try {
        final orderJson = json.decode(orderJsonString);
        
        // For stored orders, we need to ensure they have totalMrp field
        // If totalMrp is missing, calculate it from items or use totalAmount
        if (!orderJson.containsKey('totalMrp')) {
          // Try to calculate from items
          double totalMrp = 0.0;
          if (orderJson.containsKey('items') && orderJson['items'] is List) {
            for (final item in orderJson['items']) {
              final quantity = item['quantity'] ?? 1;
              final mrp = item['mrp'] ?? item['ourPrice'] ?? 0.0;
              totalMrp += (quantity * mrp);
            }
          } else {
            // If no items, use totalAmount as fallback
            totalMrp = orderJson['totalAmount'] ?? 0.0;
          }
          orderJson['totalMrp'] = totalMrp;
        }
        
        orders.add(Order.fromJson(orderJson));
      } catch (e) {
        logger.error('Error parsing order from local storage: $e');
      }
    }
    
    // Sort by most recent first (latest date first)
    orders.sort((a, b) {
      final comparison = b.orderDate.compareTo(a.orderDate);
      return comparison;
    });
    
    logger.log('Loaded ${orders.length} orders from local storage and sorted by latest date first');
    if (orders.isNotEmpty) {
      logger.log('Latest cached order: ${orders.first.orderId} - ${orders.first.orderDate}');
    }
    
    return orders;
  } catch (e) {
    ref.read(loggerProvider).error('Error in userOrdersProvider: $e');
    throw Exception('Failed to load orders: $e');
  }
});

// Provider to store a new order
final storeOrderProvider = Provider<Future<bool> Function(Order)>((ref) {
  return (Order order) async {
    try {
      final logger = ref.read(loggerProvider);
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing orders
      final List<String> ordersJson = prefs.getStringList('user_orders') ?? [];
      
      // Add new order at the beginning (latest first)
      ordersJson.insert(0, json.encode(order.toJson()));
      
      // Save updated list
      await prefs.setStringList('user_orders', ordersJson);
      
      logger.log('Order saved successfully at the top of the list: ${order.orderId}');
      
      // Refresh the orders provider
      ref.invalidate(userOrdersProvider);
      
      return true;
    } catch (e) {
      ref.read(loggerProvider).error('Error saving order: $e');
      return false;
    }
  };
});

// Provider to create an order from the current cart
final createOrderFromCartProvider = Provider<Future<Order?> Function(
  String paymentMethod,
  String deliveryMethod,
  String deliverySlot,
  String? deliveryAddress,
)>((ref) {
  return (
    String paymentMethod,
    String deliveryMethod,
    String deliverySlot,
    String? deliveryAddress,
  ) async {
    try {
      final logger = ref.read(loggerProvider);
      
      // Get the current cart
      final cartItems = ref.read(cartItemsProvider);
      if (cartItems.isEmpty) {
        logger.error('Cannot create order from empty cart');
        return null;
      }
      
      // Calculate totals correctly
      final totalOurPrice = ref.read(cartTotalProvider);
      
      // Calculate total MRP from cart items
      double totalMrp = 0.0;
      for (final item in cartItems) {
        totalMrp += (item.product.productMrp * item.quantity);
      }
      
      // Calculate correct savings (MRP - Our Price)
      final correctSavings = max(0.0, totalMrp - totalOurPrice);
      
      // Generate a unique order ID
      final orderId = 'AND_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      
      // Create the order with the updated fields and current timestamp
      final order = Order(
        orderId: orderId,
        orderDate: DateTime.now(), // Use current date/time for latest ordering
        deliveryMethod: deliveryMethod,
        deliverySlot: deliverySlot,
        totalAmount: totalOurPrice,
        totalMrp: totalMrp, // Add the totalMrp field
        savings: correctSavings, // Use correct savings calculation
        paymentMethod: paymentMethod,
        items: List.from(cartItems), // Create a copy of cart items
        status: 'Order Confirmed',
        deliveryAddress: deliveryAddress,
      );
      
      // Store the order (will be added at the top due to latest date)
      final success = await ref.read(storeOrderProvider)(order);
      
      if (success) {
        logger.log('Order created successfully with current timestamp: $orderId - ${order.orderDate}');
        return order;
      } else {
        logger.error('Failed to store order: $orderId');
        return null;
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error creating order: $e');
      return null;
    }
  };
});