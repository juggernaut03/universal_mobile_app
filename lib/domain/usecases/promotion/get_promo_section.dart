// lib/domain/usecases/promotion/get_promo_section.dart

import '../../../core/result/result.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/promo_section.dart';
import '../../repositories/i_promotion_repository.dart';

final class GetPromoSectionParams extends UseCaseParams {
  final int sectionId;
  final String departmentId;
  final String storeCode;
  final bool forceRefresh;

  const GetPromoSectionParams({
    required this.sectionId,
    required this.storeCode,
    this.departmentId = '1',
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [sectionId, departmentId, storeCode, forceRefresh];
}

/// Loads one home-screen promo strip.
///
/// An absent store yields an empty section rather than a failure: the home
/// screen builds before an outlet is chosen, and each of the four duplicated
/// providers had its own copy of that special case.
final class GetPromoSection extends UseCase<PromoSection, GetPromoSectionParams> {
  final IPromotionRepository _repository;

  const GetPromoSection(this._repository);

  @override
  Future<Result<PromoSection>> call(GetPromoSectionParams params) async {
    if (params.storeCode.isEmpty) {
      return Ok(PromoSection.empty(params.sectionId));
    }
    return _repository.section(
      sectionId: params.sectionId,
      departmentId: params.departmentId,
      storeCode: params.storeCode,
      forceRefresh: params.forceRefresh,
    );
  }
}
