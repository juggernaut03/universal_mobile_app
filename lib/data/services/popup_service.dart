
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../models/popup_model.dart';

class PopupService {
  final http.Client _client;
  final Logger _logger;
  static const String _baseUrl = 'https://newtech.shalviadvision.com/api';

  PopupService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  Future<PopupResponse?> getPopupScreen(String storeCode) async {
    try {
      _logger.log('Fetching popup for store: $storeCode');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/get_popup_screen'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'store_code': storeCode}),
      ).timeout(const Duration(seconds: 10));
      
      _logger.log('Popup API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final popup = PopupResponse.fromJson(data);
        _logger.log('Popup URL received: ${popup.offerImageUrl}');
        return popup;
      } else {
        _logger.error('Failed to fetch popup: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.error('Error fetching popup: $e');
      return null;
    }
  }
}