// lib/presentation/providers/support_content_providers.dart
//
// Static content pages (about us, refund policy, terms, privacy).
//
// These four providers were declared inside about_us_screen.dart and
// refund_tnc_screen.dart as four near-identical copies, each constructing its
// own `ContentService()` rather than resolving one. They are now one family
// provider over a single injected service.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/content_service.dart';
import '../../di/infrastructure_providers.dart';
import '../../di/service_providers.dart';
import 'outlet_provider.dart';

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

final helpSupportContentProvider = contentPageProvider('help-support');

/// Structured FAQs from the backend, grouped and ordered as an admin arranged
/// them.
///
/// Returns an empty list rather than throwing when the tenant has configured
/// none — the FAQ screen reads that as "use the built-in set", so a tenant that
/// has not filled these in still gets a useful screen instead of an error.
final faqsProvider = FutureProvider<List<FaqGroup>>((ref) async {
  final logger = ref.read(loggerProvider);
  final storeCode = ref.watch(selectedOutletProvider).valueOrNull?.storeCode;
  try {
    final groups =
        await ref.read(contentServiceProvider).fetchFaqs(storeCode: storeCode);
    logger.log('Loaded ${groups.length} FAQ group(s) from the API');
    return groups;
  } catch (e) {
    // Not rethrown: FAQs are reference material, and an unreachable backend
    // should leave the built-in questions on screen rather than an error page.
    logger.warning('FAQ fetch failed, falling back to built-in list: $e');
    return const [];
  }
});
