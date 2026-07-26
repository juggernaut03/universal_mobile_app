// lib/di/promotion_providers.dart
//
// Composition root — home-screen merchandising.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/promotion_repository_impl.dart';
import '../domain/repositories/i_promotion_repository.dart';
import '../domain/usecases/promotion/get_promo_section.dart';
import 'repository_providers.dart';

final promotionRepositoryProvider = Provider<IPromotionRepository>(
  (ref) => PromotionRepositoryImpl(
    delegate: ref.watch(popularCategoryRepositoryProvider),
  ),
);

final getPromoSectionUseCaseProvider = Provider<GetPromoSection>(
  (ref) => GetPromoSection(ref.watch(promotionRepositoryProvider)),
);
