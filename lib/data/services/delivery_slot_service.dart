// lib/data/services/delivery_slot_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/delivery_slot_model.dart';

class DeliverySlotService {
  final http.Client _client;
  final Logger _logger;

  DeliverySlotService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  /// Get available delivery slots for a specific store
  Future<List<DeliverySlot>> getDeliverySlots({
    required String storeCode,
    DateTime? orderDate,
  }) async {
    try {
      _logger.log('Fetching delivery slots for store: $storeCode');
      
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/get_delivery_slot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
          'order_date': _formatOrderDate(orderDate ?? DateTime.now()),
        }),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Delivery slots API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<DeliverySlot> slots = data
            .map((json) => DeliverySlot.fromJson(json))
            .where((slot) => slot.isActive) // Only return active slots
            .toList();
        
        _logger.log('Retrieved ${slots.length} active delivery slots');
        return slots;
      } else {
        _logger.error('Failed to fetch delivery slots: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load delivery slots');
      }
    } catch (e) {
      _logger.error('Error fetching delivery slots: $e');
      rethrow;
    }
  }

  /// Get delivery slots grouped by availability (today, tomorrow, etc.)
  Future<Map<String, List<DeliverySlot>>> getDeliverySlotsGrouped({
    required String storeCode,
    DateTime? orderDate,
  }) async {
    try {
      final slots = await getDeliverySlots(storeCode: storeCode, orderDate: orderDate);
      
      // For now, we'll return all slots for each day
      // In a more complex implementation, you might have different slots for different days
      final Map<String, List<DeliverySlot>> groupedSlots = {};
      
      // Generate for next 3 days
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final date = DateTime(now.year, now.month, now.day + i);
        final dateKey = _formatDateKey(date);
        groupedSlots[dateKey] = List.from(slots);
      }
      
      return groupedSlots;
    } catch (e) {
      _logger.error('Error grouping delivery slots: $e');
      rethrow;
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}_${date.month}_${date.day}';
  }

  /// Get available self-pickup delivery slots for a specific store
  Future<List<DeliverySlot>> getSelfPickupDeliverySlots({
    required String storeCode,
  }) async {
    try {
      _logger.log('Fetching self-pickup delivery slots for store: $storeCode');
      
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/get_self_pickup_delivery_slot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
        }),
      ).timeout(const Duration(seconds: 15));
      
      _logger.log('Self-pickup slots API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<DeliverySlot> slots = data
            .map((json) => DeliverySlot.fromJson(json))
            .where((slot) => slot.isActive) // Only return active slots
            .toList();
        
        _logger.log('Retrieved ${slots.length} active self-pickup delivery slots');
        return slots;
      } else {
        _logger.error('Failed to fetch self-pickup delivery slots: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load self-pickup delivery slots');
      }
    } catch (e) {
      _logger.error('Error fetching self-pickup delivery slots: $e');
      rethrow;
    }
  }

  String _formatOrderDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}