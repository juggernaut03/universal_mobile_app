
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../core/constants/app_constants.dart';
import '../models/popup_model.dart';

class PopupService {
  final http.Client _client;
  final Logger _logger;

  PopupService({
    http.Client? client,
    Logger? logger,
  }) : 
    _client = client ?? http.Client(),
    _logger = logger ?? Logger();

  /// Home popup image. Sourced from the universal backend's advertisements
  /// (POST /api/advertisements/active with category 'popup') — admins manage
  /// these in the panel's Dynamic Sections. Returns null (no popup) when
  /// nothing is configured.
  Future<PopupResponse?> getPopupScreen(String storeCode) async {
    try {
      _logger.log('Fetching popup for store: $storeCode');

      final response = await _client.post(
        Uri.parse(ApiConstants.advertisementsActive),
        headers: {
          'Content-Type': 'application/json',
          'X-Project-Code': ApiConstants.projectCode,
        },
        body: jsonEncode({
          'store_code': storeCode,
          'project_code': ApiConstants.projectCode,
          'category': 'popup',
          'limit': 1,
        }),
      ).timeout(const Duration(seconds: 10));

      _logger.log('Popup API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final ads = decoded is Map ? (decoded['data'] as List? ?? []) : [];
        if (ads.isEmpty || ads.first is! Map) {
          _logger.log('No popup advertisement configured');
          return null;
        }

        final ad = ads.first as Map;
        final bannerUrls =
            ad['banner_urls'] is Map ? ad['banner_urls'] as Map : {};
        final imageUrl = (bannerUrls['mobile'] ??
                bannerUrls['desktop'] ??
                ad['banner_url'] ??
                '')
            .toString();
        if (imageUrl.isEmpty) return null;

        final popup = PopupResponse.fromJson({'offerimgUrl': imageUrl});
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