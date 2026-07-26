// test/domain/promo_section_test.dart
//
// Home-screen merchandising strips.
//
// These rules were previously spread across four copies of the same 200-line
// widget, each deciding for itself when a strip was worth rendering.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/result/result.dart';
import 'package:patelmart/core/usecase/usecase.dart';
import 'package:patelmart/domain/entities/promo_section.dart';
import 'package:patelmart/domain/repositories/i_promotion_repository.dart';
import 'package:patelmart/domain/usecases/promotion/get_promo_section.dart';

PromoItem item({
  String id = 'i1',
  String categoryCode = 'C1',
  String label = 'Snacks',
}) =>
    PromoItem(
      id: id,
      categoryCode: categoryCode,
      departmentCode: 'D1',
      label: label,
      imageUrl: '',
    );

final class _FakePromoRepo implements IPromotionRepository {
  int? lastSectionId;
  String? lastStoreCode;
  PromoSection response = const PromoSection(sectionId: 2, title: 'x', items: []);

  @override
  Future<Result<PromoSection>> section({
    required int sectionId,
    required String departmentId,
    required String storeCode,
    bool forceRefresh = false,
  }) async {
    lastSectionId = sectionId;
    lastStoreCode = storeCode;
    return Ok(response);
  }

  @override
  Future<Result<void>> clearCache() async => const Ok(null);
}

void main() {
  group('PromoItem', () {
    test('needs a category code and a label to be displayable', () {
      expect(item().isDisplayable, isTrue);
      expect(item(categoryCode: '').isDisplayable, isFalse);
      expect(item(label: '   ').isDisplayable, isFalse);
    });
  });

  group('PromoSection', () {
    test('is renderable when it has at least one usable tile', () {
      expect(
        PromoSection(sectionId: 2, title: 'Popular', items: [item()])
            .isRenderable,
        isTrue,
      );
    });

    test('is not renderable when every tile is unusable', () {
      // A title with no tappable tiles renders as a heading over blank space.
      expect(
        PromoSection(
          sectionId: 2,
          title: 'Popular',
          items: [item(categoryCode: ''), item(label: '')],
        ).isRenderable,
        isFalse,
      );
    });

    test('an empty section is not renderable', () {
      expect(const PromoSection.empty(3).isRenderable, isFalse);
      expect(const PromoSection.empty(3).sectionId, 3);
      expect(const PromoSection.empty(3).title, isEmpty);
    });

    test('displayableItems drops unusable tiles', () {
      final section = PromoSection(
        sectionId: 2,
        title: 'Popular',
        items: [item(id: 'a'), item(id: 'b', categoryCode: '')],
      );

      expect(section.displayableItems.map((i) => i.id), ['a']);
    });

    test('displayableItems is unmodifiable', () {
      final section =
          PromoSection(sectionId: 2, title: 't', items: [item()]);

      expect(() => section.displayableItems.add(item(id: 'x')),
          throwsUnsupportedError);
    });
  });

  group('GetPromoSection', () {
    late _FakePromoRepo repo;
    setUp(() => repo = _FakePromoRepo());

    test('returns an empty section when no store is selected', () async {
      // The home screen builds before an outlet is chosen. Each of the four
      // duplicated providers had its own copy of this special case.
      final result = await GetPromoSection(repo)(
        const GetPromoSectionParams(sectionId: 4, storeCode: ''),
      );

      expect(result.valueOrNull!.sectionId, 4);
      expect(result.valueOrNull!.items, isEmpty);
      expect(repo.lastSectionId, isNull, reason: 'must not call the backend');
    });

    test('passes the section id and store through', () async {
      await GetPromoSection(repo)(
        const GetPromoSectionParams(sectionId: 5, storeCode: 'KLK'),
      );

      expect(repo.lastSectionId, 5);
      expect(repo.lastStoreCode, 'KLK');
    });
  });

  group('params identity', () {
    test('equal params are equal, so family providers cache', () {
      const a = GetPromoSectionParams(sectionId: 2, storeCode: 'KLK');
      const b = GetPromoSectionParams(sectionId: 2, storeCode: 'KLK');
      const c = GetPromoSectionParams(sectionId: 3, storeCode: 'KLK');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('NoParams stays a value type', () {
      expect(const NoParams(), const NoParams());
    });
  });
}
