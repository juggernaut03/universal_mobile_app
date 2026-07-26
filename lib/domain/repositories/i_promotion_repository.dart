// lib/domain/repositories/i_promotion_repository.dart

import '../../core/result/result.dart';
import '../entities/promo_section.dart';

/// Home-screen merchandising strips.
abstract interface class IPromotionRepository {
  /// One promo section for a store.
  Future<Result<PromoSection>> section({
    required int sectionId,
    required String departmentId,
    required String storeCode,
    bool forceRefresh = false,
  });

  /// Drops cached promo data.
  Future<Result<void>> clearCache();
}
