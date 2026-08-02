// lib/data/services/content_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

/// Fetches tenant-scoped static content from the universal backend.
///
/// Content pages (GET /api/content/:slug) are HTML, edited per tenant in the
/// admin panel. Slugs: about-us, privacy-policy, terms-conditions,
/// refund-policy, help-support, faq.
///
/// FAQs (GET /api/faqs) are structured rather than HTML, because the FAQ
/// screen searches across questions and renders each as an expandable row —
/// both of which flat HTML would cost.
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

  /// Structured FAQs, already grouped and ordered by the backend.
  ///
  /// Returns an empty list when the tenant has none configured, which callers
  /// treat as "fall back to the built-in set" rather than "show nothing".
  Future<List<FaqGroup>> fetchFaqs({String? storeCode}) async {
    final query = {
      'project_code': ApiConstants.projectCode,
      if (storeCode != null && storeCode.isNotEmpty) 'store_code': storeCode,
    };
    final uri = Uri.parse(ApiConstants.faqs).replace(queryParameters: query);

    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'X-Project-Code': ApiConstants.projectCode,
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('FAQ request failed (HTTP ${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final groups = decoded is Map ? decoded['data'] : null;
    if (groups is! List) return const [];

    return groups
        .whereType<Map>()
        .map(FaqGroup.fromJson)
        .where((g) => g.faqs.isNotEmpty)
        .toList();
  }
}

/// A heading and the questions listed under it.
class FaqGroup {
  final String title;
  final List<FaqEntry> faqs;

  const FaqGroup({required this.title, required this.faqs});

  factory FaqGroup.fromJson(Map<dynamic, dynamic> json) => FaqGroup(
        title: (json['title'] ?? 'General').toString(),
        faqs: (json['faqs'] is List ? json['faqs'] as List : const [])
            .whereType<Map>()
            .map(FaqEntry.fromJson)
            .where((f) => f.question.isNotEmpty && f.answer.isNotEmpty)
            .toList(),
      );
}

class FaqEntry {
  final String question;
  final String answer;

  const FaqEntry({required this.question, required this.answer});

  factory FaqEntry.fromJson(Map<dynamic, dynamic> json) => FaqEntry(
        question: (json['question'] ?? '').toString(),
        answer: (json['answer'] ?? '').toString(),
      );
}
