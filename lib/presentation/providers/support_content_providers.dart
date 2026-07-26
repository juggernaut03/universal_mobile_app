// lib/presentation/providers/support_content_providers.dart
//
// Static content pages (about us, refund policy, terms, privacy).
//
// These four providers were declared inside about_us_screen.dart and
// refund_tnc_screen.dart as four near-identical copies, each constructing its
// own `ContentService()` rather than resolving one. They are now one family
// provider over a single injected service.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/infrastructure_providers.dart';
import '../../di/service_providers.dart';

/// Fetches a static content page by its backend slug.
final contentPageProvider =
    FutureProvider.family<String, String>((ref, slug) async {
  final logger = ref.read(loggerProvider);
  try {
    logger.log('Fetching content page: $slug');
    return await ref.read(contentServiceProvider).fetchContentPage(slug);
  } catch (e) {
    logger.error('Error fetching content page $slug: $e');
    throw Exception(
        'Unable to load content. Please check your connection and try again.');
  }
});

final aboutUsContentProvider = contentPageProvider('about-us');
final refundPolicyContentProvider = contentPageProvider('refund-policy');
final termsConditionsContentProvider = contentPageProvider('terms-conditions');
final privacyPolicyContentProvider = contentPageProvider('privacy-policy');
