// lib/data/repositories/order_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/order_model.dart';
import '../models/last_order_status_model.dart';
import '../../domain/repositories/i_auth_repository.dart';

/// Orders against the universal backend. All endpoints are JWT-protected;
/// the token comes from the stored user profile (accessKey slot).
class OrderRepository {
  final http.Client _client;

  /// Reads the bearer token.
  ///
  /// Was the whole `AuthRepository`, of which this class used exactly one
  /// method — to fetch a profile purely to pull its access key out. Depending
  /// on the two-method [ITokenStore] instead means an order repository can no
  /// longer reach login, logout or session state.
  final ITokenStore _tokenStore;
  final Logger _logger;

  OrderRepository({
    required http.Client client,
    required ITokenStore tokenStore,
    required Logger logger,
  })  : _client = client,
        _tokenStore = tokenStore,
        _logger = logger;

  Future<Map<String, String>?> _authHeaders() async {
    final token = await _tokenStore.readValidToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Project-Code': ApiConstants.projectCode,
      'Authorization': 'Bearer $token',
    };
  }

  // Get order history (GET /api/orders/my-orders)
  Future<List<Order>> getOrderHistory({int limit = 50}) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) {
        throw Exception('User not logged in');
      }

      final uri = Uri.parse(
          '${ApiConstants.ordersMy}?limit=$limit&project_code=${ApiConstants.projectCode}');
      _logger.log('Fetching order history');

      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));

      _logger.log('Order history response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData is Map && jsonData['orders'] is List) {
          return (jsonData['orders'] as List)
              .whereType<Map>()
              .map((item) => Order.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        _logger.error('Unexpected order history response format');
        return [];
      } else {
        _logger.error(
            'Failed to fetch order history: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      _logger.error('Error fetching order history: $e');
      return [];
    }
  }

  // Get order details (GET /api/orders/:orderNumber)
  Future<Order?> getOrderDetails(String orderNumber) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) {
        throw Exception('User not logged in');
      }

      final uri = Uri.parse(
          '${ApiConstants.orderByNumber(orderNumber)}?project_code=${ApiConstants.projectCode}');
      _logger.log('Fetching order details for: $orderNumber');

      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData is Map && jsonData['order'] is Map) {
          return Order.fromJson(
              Map<String, dynamic>.from(jsonData['order'] as Map));
        }
        _logger.error('Unexpected order details response format');
        return null;
      } else {
        _logger.error(
            'Failed to fetch order details: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.error('Error fetching order details: $e');
      return null;
    }
  }

  // Cancel an order (POST /api/orders/:orderNumber/cancel)
  Future<bool> cancelOrder(String orderNumber, String reason) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) {
        throw Exception('User not logged in');
      }

      final uri = Uri.parse(ApiConstants.orderCancel(orderNumber));
      _logger.log('Cancelling order: $orderNumber (reason: $reason)');

      final response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'cancel_reason': reason,
              'project_code': ApiConstants.projectCode,
            }),
          )
          .timeout(const Duration(seconds: ApiConstants.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        return jsonData is Map && jsonData['success'] == true;
      }
      _logger.error(
          'Failed to cancel order: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      _logger.error('Error cancelling order: $e');
      return false;
    }
  }

  // Reorder — the universal backend has no reorder endpoint; the provider
  // layer re-adds the order's items to the local cart via getOrderDetails.
  Future<bool> reorder(String orderNumber) async {
    _logger.warning(
        'OrderRepository.reorder is handled client-side now — use getOrderDetails + cart notifier');
    return false;
  }

  // Get last order status — derived from the most recent order in my-orders.
  Future<LastOrderStatus?> getLastOrderStatus() async {
    try {
      final orders = await getOrderHistory(limit: 1);
      if (orders.isEmpty) {
        return null;
      }

      final latest = orders.first;
      final status = latest.status.toLowerCase();

      // Show the tracking banner only while the order is in flight and recent
      final bool inFlight =
          !status.contains('delivered') && !status.contains('cancelled') &&
              !status.contains('refunded');
      final bool recent =
          DateTime.now().difference(latest.orderDate).inDays <= 7;

      return LastOrderStatus(
        orderStatusTxt: latest.status,
        actualOrderNo: latest.orderId,
        orderStatusImg: '',
        isVisible: inFlight && recent,
        lastOrder: latest,
      );
    } catch (e) {
      _logger.error('Error fetching last order status: $e');
      return null;
    }
  }
}
