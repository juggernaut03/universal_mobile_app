// lib/data/models/home_feed_mappers.dart
//
// Turns the items the home feed already carries into the models the existing
// section widgets expect.
//
// The point of these is call count: the feed ships every section's content in
// one response, so a strip that can build itself from `section.items` does not
// need its own request. Anything the feed cannot supply falls through to the
// section's original fetch.

import '../../domain/entities/promo_section.dart';
import '../services/banner_service.dart';
import 'home_feed_models.dart';
import 'popular_category_models.dart';
import 'product_model.dart';

/// Reads a nested map off a raw feed item without throwing on shape drift.
Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String _str(dynamic value) => (value ?? '').toString();

extension HomeSectionPromoMapper on HomeSection {
  /// A category strip/grid as the promo-section entity the widgets render.
  ///
  /// Mirrors the legacy shaping in `PopularCategoryRepository` so a strip looks
  /// identical whether it came from the feed or from its own endpoint.
  PromoSection toPromoSection(int sectionId) {
    final promoItems = <PromoItem>[];

    for (final item in items) {
      final sub = _map(item['subcategory_details']);
      final cat = _map(item['category_details']);

      final categoryCode =
          _str(cat['idcategory_master']).isNotEmpty ? _str(cat['idcategory_master']) : _str(sub['category_id']);
      final label = _str(sub['sub_category_name']).isNotEmpty
          ? _str(sub['sub_category_name'])
          : _str(cat['category_name']);

      promoItems.add(
        PromoItem(
          id: _str(sub['id']).isNotEmpty ? _str(sub['id']) : _str(item['sub_category_id']),
          categoryCode: categoryCode,
          departmentCode: _str(cat['dept_id']),
          label: label,
          imageUrl: _str(item['image_link']),
        ),
      );
    }

    return PromoSection(
      sectionId: sectionId,
      // The backend's historic misspelling is corrected in one place; see
      // PopularCategoryResponse.fromJson.
      title: title.replaceAll('Cateogory', 'Category').trim(),
      items: promoItems,
    );
  }

  /// The same content in the legacy DTO, for the widgets still typed to it.
  PopularCategoryResponse toPopularCategoryResponse() {
    final legacyItems = <Map<String, dynamic>>[];
    var position = 0;

    for (final item in items) {
      final sub = _map(item['subcategory_details']);
      final cat = _map(item['category_details']);
      position += 1;

      legacyItems.add({
        '_id': _str(sub['id']).isNotEmpty ? _str(sub['id']) : _str(item['sub_category_id']),
        'idcategory_master': _str(cat['idcategory_master']).isNotEmpty
            ? _str(cat['idcategory_master'])
            : _str(sub['category_id']),
        'category_name': _str(sub['sub_category_name']).isNotEmpty
            ? _str(sub['sub_category_name'])
            : _str(cat['category_name']),
        'dept_id': _str(cat['dept_id']),
        'sequence_id': item['position'] ?? position,
        'store_code': '',
        'no_of_col': '4',
        'image_link': _str(item['image_link']),
      });
    }

    return PopularCategoryResponse.fromJson({
      'title': title,
      'category_bg_color': style.backgroundColor.isNotEmpty ? style.backgroundColor : '#FFFFFF',
      'categories_details': legacyItems,
    });
  }

  /// Hero banners as the banner service's model.
  ///
  /// The feed carries the banner objects the `/banners` endpoint returns, so
  /// this repeats the same legacy-key shaping `BannerService` applies —
  /// `PromotionalBanner.fromJson` reads those keys, not the API's.
  List<PromotionalBanner> toPromotionalBanners(String storeCode) {
    final banners = <PromotionalBanner>[];

    for (final item in items) {
      final assets = _map(item['banner_urls']);

      var imageUrl = _str(item['image_url']);
      for (final asset in assets.values) {
        if (asset is Map) {
          final candidate = _str(asset['mobile']).isNotEmpty
              ? _str(asset['mobile'])
              : _str(asset['desktop']);
          if (candidate.isNotEmpty) {
            imageUrl = candidate;
            break;
          }
        }
      }
      if (imageUrl.isEmpty) continue;

      final action = _map(item['action']);

      banners.add(
        PromotionalBanner.fromJson({
          '_id': _str(item['id']),
          'redirect_link': _str(action['value']),
          'banner_img': imageUrl,
          'is_active': item['is_active'] == false ? 'Disabled' : 'Enabled',
          'banner_type_id': 1,
          'sequence_id': item['sequence'] ?? 0,
          // The feed already filtered by store; pin the requested code so the
          // widget's store-equality checks keep matching.
          'store_code': storeCode,
          'banner_bg_color': style.backgroundColor.isNotEmpty
              ? style.backgroundColor
              : '#FFFFFF',
        }),
      );
    }

    banners.sort((a, b) => a.sequenceId.compareTo(b.sequenceId));
    return banners;
  }

  /// A product rail's products, filtered the same way the best-seller
  /// repository filters them.
  List<ProductModel> toProducts() {
    final products = <ProductModel>[];

    for (final item in items) {
      final details = _map(item['product_details']);
      if (details.isEmpty) continue;
      try {
        final product = ProductModel.fromJson(details);
        if (product.isAvailable) products.add(product);
      } catch (_) {
        // A single malformed product must not empty the whole rail.
      }
    }

    return products;
  }
}
