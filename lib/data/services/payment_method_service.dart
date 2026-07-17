import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/payment_method_model.dart';

class PaymentMethodService {
  final http.Client _client;
  final Logger _logger;

  PaymentMethodService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  /// Get available payment methods from API
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      _logger.log('Fetching payment methods from API');
      
      final response = await _client.get(
        Uri.parse(
            '${ApiConstants.baseUrl}/payment-modes/enabled?project_code=${ApiConstants.projectCode}'),
        headers: {
          'Content-Type': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
        },
      ).timeout(const Duration(seconds: 15));

      _logger.log('Payment methods API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> jsonData =
            decoded is Map ? (decoded['data'] as List? ?? []) : (decoded as List);
        final paymentMethods = jsonData
            .map((json) => PaymentMethod.fromJson(json))
            .toList();
        
        _logger.log('Successfully loaded ${paymentMethods.length} payment methods');
        return paymentMethods;
      } else {
        _logger.error('Failed to load payment methods: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load payment methods: ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Error fetching payment methods: $e');
      rethrow;
    }
  }
}
