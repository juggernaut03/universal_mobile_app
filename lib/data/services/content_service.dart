// lib/data/services/content_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

/// Fetches tenant-scoped static content pages from the universal backend
/// (GET /api/content/:slug). Slugs: about-us, privacy-policy, terms,
/// refund-policy, faq.
class ContentService {
  final http.Client _client;

  ContentService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> fetchContentPage(String slug) async {
    final response = await _client.get(
      Uri.parse(
          '${ApiConstants.contentPage(slug)}?project_code=${ApiConstants.projectCode}'),
      headers: {
        'Accept': 'application/json',
        'X-Project-Code': ApiConstants.projectCode,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is Map) {
        final html = (decoded['data'] as Map)['html'];
        if (html is String && html.trim().isNotEmpty) {
          return html;
        }
      }
      throw Exception('Content page "$slug" is empty');
    }

    throw Exception('Failed to load content "$slug": ${response.statusCode}');
  }
}
