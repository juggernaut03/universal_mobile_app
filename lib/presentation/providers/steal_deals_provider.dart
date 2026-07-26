import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result/result.dart';
import '../../di/product_providers.dart';
import '../../domain/usecases/product/get_product_by_code.dart';
import '../../data/models/product_model.dart';
import 'outlet_provider.dart';
import 'cart_provider.dart';
import '../../di/service_providers.dart';
import '../../di/infrastructure_providers.dart';

/// Debounced cart state that only updates after 800ms of inactivity.
/// This prevents rapid API calls when user is adding/removing items quickly.
final _debouncedCartProvider =
    StateNotifierProvider.autoDispose<_DebouncedCartNotifier, _CartSnapshot>(
        (ref) {
  final notifier = _DebouncedCartNotifier();
  ref.listen(cartProvider, (_, cartItems) {
    final cartTotal = ref.read(cartTotalProvider);
    notifier.update(cartItems, cartTotal);
  });
  final cartItems = ref.watch(cartProvider);
  final cartTotal = ref.watch(cartTotalProvider);
  notifier.setInitial(cartItems, cartTotal);
  return notifier;
});

class _CartSnapshot {
  final List<CartItem> items;
  final double total;
  _CartSnapshot(this.items, this.total);
}

class _DebouncedCartNotifier extends StateNotifier<_CartSnapshot> {
  _DebouncedCartNotifier() : super(_CartSnapshot([], 0));
  Timer? _debounce;

  void setInitial(List<CartItem> items, double total) {
    state = _CartSnapshot(items, total);
  }

  void update(List<CartItem> items, double total) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        state = _CartSnapshot(items, total);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Panel colors from the get_offer API response (top-level fields).
class OfferPanelColors {
  final String bgColor;
  final String headingTxtColor;
  final String descriptTxtColor;
  final String unlockTxtColor;
  final String unlockBgColor;

  const OfferPanelColors({
    this.bgColor = '',
    this.headingTxtColor = '',
    this.descriptTxtColor = '',
    this.unlockTxtColor = '',
    this.unlockBgColor = '',
  });
}

final _offerPanelColorsState =
    StateProvider<OfferPanelColors>((ref) => const OfferPanelColors());

/// Public provider to read panel colors.
final offerPanelColorsProvider = Provider<OfferPanelColors>((ref) {
  return ref.watch(_offerPanelColorsState);
});

/// Provider that fetches offers from the get_offer API and returns
/// the product details for each offer's offer_p_code (array of codes).
/// Uses keepAlive + previous data caching to avoid flickering on cart changes.
final stealDealsOffersProvider =
    FutureProvider.autoDispose<List<StealDealOffer>>((ref) async {
  // ignore: unused_local_variable
  final link = ref.keepAlive();

  final apiService = ref.watch(apiServiceProvider);
  final logger = ref.watch(loggerProvider);
  final selectedOutlet = ref.watch(selectedOutletProvider).valueOrNull;
  final storeCode = selectedOutlet?.storeCode ?? 'KLK';

  logger.log('StealDeals: Provider triggered - storeCode: $storeCode');

  final prefs = ref.watch(sharedPreferencesProvider);
  final tempOrderId = prefs.getString('temp_order_id') ?? '';

  final authManager = ref.watch(centralizedAuthManagerProvider);
  final accessKey = await authManager.getValidAccessKey() ?? '';

  final cartSnapshot = ref.watch(_debouncedCartProvider);

  final cartItemsList = cartSnapshot.items
      .map((item) => {
            'pcode': item.product.pCode,
            'product_name': item.product.productName,
            'product_mrp': item.product.productMrp,
            'selling_price': item.product.ourPrice,
            'package_size': item.product.packageSize,
            'package_unit': item.product.packageUnit,
            'stock_message': item.product.storeQuantity > 0 ? 'Yes' : 'No',
            'price_alert_message': 'Yes',
            'quantity': item.quantity,
            'product_image_link': item.product.pcodeImg,
          })
      .toList();

  logger.log(
      'StealDeals: Request - tempOrderId: $tempOrderId, cartTotal: ${cartSnapshot.total}, cartItems: ${cartItemsList.length}');

  try {
    final apiResponse = await apiService.getOffer(
      tempOrderId: tempOrderId,
      accessKey: accessKey,
      storeCode: storeCode,
      ipoOrderAmount: cartSnapshot.total,
      cartItems: cartItemsList,
    );

    // Store panel colors
    ref.read(_offerPanelColorsState.notifier).state = OfferPanelColors(
      bgColor: apiResponse.pannelBgColor,
      headingTxtColor: apiResponse.pannelHeadingTxtColor,
      descriptTxtColor: apiResponse.pannelDescriptTxtColor,
      unlockTxtColor: apiResponse.pannelUnlockTxtColor,
      unlockBgColor: apiResponse.pannelUnlockBgColor,
    );

    final offers = apiResponse.offers;
    logger.log('StealDeals: get_offer API returned ${offers.length} offers');
    if (offers.isEmpty) return [];

    final getProductByCode = ref.watch(getProductByCodeUseCaseProvider);
    final List<StealDealOffer> stealDeals = [];

    for (final offer in offers) {
      // offer_p_code is an array of product codes
      final rawPCode = offer['offer_p_code'];
      final List<String> pCodes = [];

      if (rawPCode is List) {
        for (final code in rawPCode) {
          final s = code.toString();
          if (s.isNotEmpty) pCodes.add(s);
        }
      } else if (rawPCode != null) {
        final s = rawPCode.toString();
        if (s.isNotEmpty) pCodes.add(s);
      }

      if (pCodes.isEmpty) {
        logger.log(
            'StealDeals: Skipping offer with empty p_codes - offer_name: ${offer['offer_name']}');
        continue;
      }

      // Fetch all products for this offer.
      // A failure on one code must not abandon the whole offer, so each Err is
      // logged and skipped — but now with a typed reason instead of a bare null.
      final List<ProductModel> products = [];
      for (final pCode in pCodes) {
        final result = await getProductByCode(
          GetProductByCodeParams(code: pCode, storeCode: storeCode),
        );
        switch (result) {
          case Ok(:final value):
            if (value.isAvailable) {
              products.add(ProductModel.fromEntity(value));
            }
          case Err(:final failure):
            logger.error(
                'StealDeals: could not fetch pCode $pCode: ${failure.message}');
        }
      }

      if (products.isNotEmpty) {
        stealDeals.add(StealDealOffer(offer: offer, products: products));
        logger.log(
            'StealDeals: Offer "${offer['offer_heading_text']}" - ${products.length} products loaded');
      }
    }

    // Filter out offers where offer_visible is false
    final visibleDeals =
        stealDeals.where((deal) => deal.offerVisible).toList();

    logger.log(
        'StealDeals: Final result - ${visibleDeals.length} visible offers (${stealDeals.length} total)');
    return visibleDeals;
  } catch (e, stackTrace) {
    logger.error('StealDeals: Error fetching steal deals offers: $e');
    logger.error('StealDeals: StackTrace: $stackTrace');
    return [];
  }
});

/// Model combining offer data with its list of products.
class StealDealOffer {
  final Map<String, dynamic> offer;
  final List<ProductModel> products;

  StealDealOffer({required this.offer, required this.products});

  // Text fields
  String get offerStatus =>
      offer['offer_status']?.toString() ?? '';
  String get offerHeadingText =>
      offer['offer_heading_text']?.toString() ?? '';
  String get offerName =>
      offer['offer_name']?.toString() ?? '';
  String get offerDesc =>
      offer['offer_desc']?.toString() ?? '';
  String get offerConditionText =>
      offer['offer_condition_text']?.toString() ?? '';
  String get offerCouponCode =>
      offer['offer_coupon_code']?.toString() ?? '';
  String get imgPath =>
      offer['img_path']?.toString() ?? '';

  // Visibility
  bool get offerVisible =>
      offer['offer_visible']?.toString().toLowerCase() == 'true';

  // Status
  bool get isUnlocked =>
      offerStatus.toLowerCase() == 'unlocked';

  // Values
  double get minOrderValue =>
      double.tryParse(offer['min_order_value']?.toString() ?? '0') ?? 0;
  double get maxOrderValue =>
      double.tryParse(offer['max_order_value']?.toString() ?? '0') ?? 0;
  double get ipoOrderAmount =>
      double.tryParse(offer['ipo_order_amount']?.toString() ?? '0') ?? 0;

  // API-driven colors
  String get headingBgColor =>
      offer['offer_heading_bg_color']?.toString() ?? '#F4BB44';
  String get headingTextColor =>
      offer['offer_heading_text_color']?.toString() ?? '#000000';
  String get cardBgColor =>
      offer['offer_card_bg_color']?.toString() ?? '#FFFFFF';
  String get progressFillColor =>
      offer['offer_progress_fill_color']?.toString() ?? '#4CAF50';
  String get lockedBadgeColor =>
      offer['offer_locked_badge_color']?.toString() ?? '#CCCCCC';
  String get unlockedBadgeColor =>
      offer['offer_unlocked_badge_color']?.toString() ?? '#4CAF50';
  String get claimBgColor =>
      offer['offer_claim_bg_color']?.toString() ?? '';
}

/// Set of product codes that belong to unlocked offers — max 1 qty allowed.
final offerProductCodesProvider = Provider<Set<String>>((ref) {
  final offersAsync = ref.watch(stealDealsOffersProvider);
  final offers = offersAsync.valueOrNull;
  if (offers == null || offers.isEmpty) return {};

  final Set<String> codes = {};
  for (final offer in offers) {
    if (offer.isUnlocked) {
      for (final product in offer.products) {
        codes.add(product.pCode);
      }
    }
  }
  return codes;
});

/// Set of ALL offer product codes (locked + unlocked).
final allOfferProductCodesProvider = Provider<Set<String>>((ref) {
  final offersAsync = ref.watch(stealDealsOffersProvider);
  final offers = offersAsync.valueOrNull;
  if (offers == null || offers.isEmpty) return {};

  final Set<String> codes = {};
  for (final offer in offers) {
    for (final product in offer.products) {
      codes.add(product.pCode);
    }
  }
  return codes;
});
