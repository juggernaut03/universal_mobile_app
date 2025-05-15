// lib/presentation/providers/reorder_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/data/repositories/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/utils/logger.dart';
import '../../data/services/payment_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/cart_validator.dart';
import '../../data/models/order_model.dart';
import 'launch_flow_provider.dart';
import 'cart_provider.dart';
import 'auth_providers.dart';

// Provider for OrderRepository
final orderRepositoryProvider = Provider((ref) {
  final logger = ref.read(loggerProvider);
  final authRepository = ref.read(authRepositoryProvider);
  
  return OrderRepository(
    client: http.Client(),
    authRepository: authRepository,
    logger: logger,
  );
});

// Provider to store and retrieve user orders
final userOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final logger = ref.read(loggerProvider);
  logger.log('Fetching order history from provider');
  
  try {
    // Check if user is logged in
    final authRepository = ref.read(authRepositoryProvider);
    final isLoggedIn = await authRepository.isLoggedIn();
    
    if (isLoggedIn) {
      try {
        // Create and use OrderRepository
        final orderRepository = OrderRepository(
          client: http.Client(),
          authRepository: authRepository,
          logger: logger,
        );
        
        logger.log('Calling getOrderHistory from API');
        final apiOrders = await orderRepository.getOrderHistory();
        
        if (apiOrders.isNotEmpty) {
          logger.log('Successfully fetched ${apiOrders.length} orders from API');
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
        orders.add(Order.fromJson(orderJson));
      } catch (e) {
        logger.error('Error parsing order from local storage: $e');
      }
    }
    
    // Sort by most recent first
    orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    
    logger.log('Loaded ${orders.length} orders from local storage');
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
      
      // Add new order
      ordersJson.add(json.encode(order.toJson()));
      
      // Save updated list
      await prefs.setStringList('user_orders', ordersJson);
      
      logger.log('Order saved successfully: ${order.orderId}');
      
      // Refresh the orders provider
      ref.refresh(userOrdersProvider);
      
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
      final cartItems = ref.read(cartProvider);
      if (cartItems.isEmpty) {
        logger.error('Cannot create order from empty cart');
        return null;
      }
      
      // Calculate totals
      final totalAmount = ref.read(cartTotalProvider);
      final savings = ref.read(cartSavingsProvider);
      
      // Generate a unique order ID
      final orderId = 'AND_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      
      // Create the order
      final order = Order(
        orderId: orderId,
        orderDate: DateTime.now(),
        deliveryMethod: deliveryMethod,
        deliverySlot: deliverySlot,
        totalAmount: totalAmount,
        savings: savings,
        paymentMethod: paymentMethod,
        items: List.from(cartItems), // Create a copy of cart items
        status: 'Order Confirmed',
        deliveryAddress: deliveryAddress,
      );
      
      // Store the order
      final success = await ref.read(storeOrderProvider)(order);
      
      if (success) {
        logger.log('Order created successfully: $orderId');
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