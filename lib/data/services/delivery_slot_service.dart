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
  /// (POST /api/delivery-slots/get-delivery-slots on the universal backend;
  /// slots are not date-specific there, so [orderDate] is accepted for
  /// call-site compatibility but not sent).
  Future<List<DeliverySlot>> getDeliverySlots({
    required String storeCode,
    DateTime? orderDate,
  }) async {
    try {
      _logger.log('Fetching delivery slots for store: $storeCode');

      final response = await _client.post(
        Uri.parse(ApiConstants.deliverySlotsGet),
        headers: {
          'Content-Type': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
        },
        body: jsonEncode({
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
        }),
      ).timeout(const Duration(seconds: 15));

      _logger.log('Delivery slots API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data =
            decoded is Map ? (decoded['data'] as List? ?? []) : (decoded as List);
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

  /// Self-pickup uses the same slot list on the universal backend — the store
  /// object's delivery_options.self_pickup flag decides whether to offer it.
  Future<List<DeliverySlot>> getSelfPickupDeliverySlots({
    required String storeCode,
  }) async {
    return getDeliverySlots(storeCode: storeCode);
  }

  /// Get available delivery dates for a specific store.
  /// The universal backend has no delivery-dates endpoint - selectable dates
  /// are generated client-side (dd/MM/yyyy format), starting [startOffsetDays]
  /// from today (0 = same-day, 1 = next-day only, 2 = day after tomorrow,
  /// ...) per the store's own Admin > Outlet > Stores setting
  /// (Outlet.deliveryStartOffsetDays) and running 7 days from there.
  Future<List<String>> fetchDeliveryDates({
    required String storeCode,
    int startOffsetDays = 0,
  }) async {
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final date = DateTime(now.year, now.month, now.day + startOffsetDays + i);
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      return '$d/$m/${date.year}';
    });
    _logger.log(
        'Generated ${dates.length} delivery dates for store $storeCode (offset: $startOffsetDays days)');
    return dates;
  }
}
