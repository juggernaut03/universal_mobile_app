// lib/data/repositories/top_seller_repository.dart
//
// Top sellers: the one home collection the app could never show.
//
// The endpoint and the admin page have both existed all along — there was just
// no client for them, so anything a merchandiser configured here was invisible
// on the phone.
//
// Sections are returned as [HomeSection]s rather than a model of their own, so
// they render through the same rail the feed uses. Top sellers must not go
// through the best-seller widget: that addresses its content by sequence
// *within the best_sellers collection* and would draw a different rail's
// products under this one's heading.

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/home_feed_models.dart';

class TopSellerRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  TopSellerRepository({required ApiClient apiClient, required Logger logger})
      : _apiClient = apiClient,
        _logger = logger;

  /// Active top-seller sections for [storeCode], in the admin's order.
  ///
  /// Returns an empty list on any failure: a home screen missing one rail is a
  /// far better outcome than a home screen that fails to build.
  Future<List<HomeSection>> getSections(String storeCode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.topSellersList,
        body: {
          'store_code': storeCode,
          // Without this the response carries p_codes only, and there is
          // nothing to render.
          'enrich_products': true,
        },
      );

      final data = response is Map ? response['data'] : null;
      if (data is! List) return const [];

      final sections = <HomeSection>[];

      for (var i = 0; i < data.length; i++) {
        final raw = data[i];
        if (raw is! Map) continue;

        final products = raw['products'];
        final items = products is List
            ? products.whereType<Map>().map(Map<String, dynamic>.from).toList()
            : <Map<String, dynamic>>[];

        // A section with no products would render as a bare heading.
        if (items.isEmpty) continue;

        sections.add(
          HomeSection(
            id: (raw['_id'] ?? 'top_seller_$i').toString(),
            type: HomeSectionType.productRail,
            slot: i,
            title: (raw['title'] ?? '').toString(),
            // This collection spells it bg_color; the others use
            // background_color. Read both so a colour set in the panel is not
            // quietly dropped.
            style: HomeSectionStyle(
              backgroundColor:
                  (raw['bg_color'] ?? raw['background_color'] ?? '').toString(),
            ),
            sourceSequence: int.tryParse('${raw['sequence']}'),
            sourceCollection: HomeSectionSource.topSellers,
            items: items,
          ),
        );
      }

      return sections;
    } catch (e) {
      _logger.error('Error fetching top sellers: $e');
      return const [];
    }
  }
}
