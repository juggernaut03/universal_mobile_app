// lib/presentation/providers/popular_category_section_providers.dart
//
// Home-screen promo strips 2-5.
//
// Was four copies of the same four providers — a repository alias, a refresh
// flag, a FutureProvider and a refresh callback — differing only by a section
// number, and each carrying its own copy of the "no outlet yet" special case.
// One family, keyed by section id, replaces all sixteen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result/result.dart';
import '../../di/promotion_providers.dart';
import '../../domain/entities/promo_section.dart';
import '../../domain/usecases/promotion/get_promo_section.dart';
import 'outlet_provider.dart';

/// Sections rendered on the home screen, in order.
const promoSectionIds = [2, 3, 4, 5];

/// Force-refresh flag per section.
final promoSectionRefreshFlagProvider =
    StateProvider.family<bool, int>((ref, sectionId) => false);

/// One promo strip.
///
/// An unselected outlet yields an empty section rather than throwing — the home
/// screen builds before a store is chosen, and a strip with nothing to show is
/// not an error.
final promoSectionProvider =
    FutureProvider.family<PromoSection, int>((ref, sectionId) async {
  final storeCode = ref.watch(selectedOutletProvider).valueOrNull?.storeCode;
  if (storeCode == null) return PromoSection.empty(sectionId);

  final result = await ref.watch(getPromoSectionUseCaseProvider)(
    GetPromoSectionParams(
      sectionId: sectionId,
      storeCode: storeCode,
      forceRefresh: ref.read(promoSectionRefreshFlagProvider(sectionId)),
    ),
  );

  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw Exception(failure.userMessage),
  };
});

/// Pull-to-refresh for one strip.
final promoSectionRefreshProvider =
    Provider.family<Future<void> Function(), int>((ref, sectionId) {
  return () async {
    await ref.read(promotionRepositoryProvider).clearCache();
    ref.read(promoSectionRefreshFlagProvider(sectionId).notifier).state = true;
    try {
      // ignore: unused_result — awaited for completion; the value is not needed.
      await ref.refresh(promoSectionProvider(sectionId).future);
    } finally {
      ref.read(promoSectionRefreshFlagProvider(sectionId).notifier).state = false;
    }
  };
});

// Named aliases so the four section widgets keep compiling while they are
// merged into one parameterised widget.
final popularCategorySection2Provider = promoSectionProvider(2);
final popularCategorySection3Provider = promoSectionProvider(3);
final popularCategorySection4Provider = promoSectionProvider(4);
final popularCategorySection5Provider = promoSectionProvider(5);

final section2RefreshProvider = promoSectionRefreshProvider(2);
final section3RefreshProvider = promoSectionRefreshProvider(3);
final section4RefreshProvider = promoSectionRefreshProvider(4);
final section5RefreshProvider = promoSectionRefreshProvider(5);

/// Refreshes every strip. Used by the home screen's pull-to-refresh.
///
/// Clears the cache once rather than once per strip: all four strips are slices
/// of a single `/popular-categories/list` response, so per-strip clearing only
/// serves to fragment one refresh into several requests.
final allSectionsRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(promotionRepositoryProvider).clearCache();

    for (final id in promoSectionIds) {
      ref.read(promoSectionRefreshFlagProvider(id).notifier).state = true;
    }
    try {
      await Future.wait(
        // ignore: unused_result — awaited for completion; the value is not needed.
        promoSectionIds.map((id) => ref.refresh(promoSectionProvider(id).future)),
      );
    } finally {
      for (final id in promoSectionIds) {
        ref.read(promoSectionRefreshFlagProvider(id).notifier).state = false;
      }
    }
  };
});
