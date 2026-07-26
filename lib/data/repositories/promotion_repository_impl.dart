// lib/data/repositories/promotion_repository_impl.dart

import '../../core/error/failure_mapper.dart';
import '../../core/result/result.dart';
import '../../domain/entities/promo_section.dart';
import '../../domain/repositories/i_promotion_repository.dart';
import 'popular_category_repository.dart';

final class PromotionRepositoryImpl implements IPromotionRepository {
  final PopularCategoryRepository _delegate;

  PromotionRepositoryImpl({required PopularCategoryRepository delegate})
      : _delegate = delegate;

  @override
  Future<Result<PromoSection>> section({
    required int sectionId,
    required String departmentId,
    required String storeCode,
    bool forceRefresh = false,
  }) =>
      guard(() async {
        final response = await _delegate.getPopularCategories(
          sectionId: sectionId,
          departmentId: departmentId,
          storeCode: storeCode,
          forceRefresh: forceRefresh,
        );
        return response.toEntity(sectionId);
      });

  @override
  Future<Result<void>> clearCache() => guard(_delegate.clearCache);
}
