import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../core/auth/centralized_auth_manager.dart';
import 'launch_flow_provider.dart';
import 'outlet_provider.dart';
import 'cart_provider.dart';
import 'subcategory_providers.dart';

/// Debounced cart state that only updates after 800ms of inactivity.
/// This prevents rapid API calls when user is adding/removing items quickly.
final _debouncedCartProvider =
    StateNotifierProvider.autoDispose<_DebouncedCartNotifier, _CartSnapshot>(
        (ref) {
  final notifier = _DebouncedCartNotifier();
  // Listen to cart changes and debounce them
  ref.listen(cartProvider, (_, cartItems) {
    final cartTotal = ref.read(cartTotalProvider);
    notifier.update(cartItems, cartTotal);
  });
  // Set initial value
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

/// Provider that fetches offers from the get_offer API and returns
/// the product details for each offer's offer_p_code.
/// Uses keepAlive + previous data caching to avoid flickering on cart changes.
final stealDealsOffersProvider =
    FutureProvider.autoDispose<List<StealDealOffer>>((ref) async {
  // Keep alive so it doesn't dispose between rebuilds
  // ignore: unused_local_variable
  final link = ref.keepAlive();

  final apiService = ref.watch(apiServiceProvider);
  final logger = ref.watch(loggerProvider);
  final selectedOutlet = ref.watch(selectedOutletProvider).valueOrNull;
  final storeCode = selectedOutlet?.storeCode ?? 'KLK';

  logger.log('StealDeals: Provider triggered - storeCode: $storeCode');

  // Get temp_order_id from SharedPreferences
  final prefs = ref.watch(sharedPreferencesProvider);
  final tempOrderId = prefs.getString('temp_order_id') ?? '';

  // Get access_key from auth manager
  final authManager = ref.watch(centralizedAuthManagerProvider);
  final accessKey = await authManager.getValidAccessKey() ?? '';

  // Watch debounced cart state instead of raw cart
  final cartSnapshot = ref.watch(_debouncedCartProvider);

  // Build cart items for the request
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
      'StealDeals: Request params - tempOrderId: $tempOrderId, accessKey: ${accessKey.isNotEmpty ? "present" : "empty"}, cartTotal: ${cartSnapshot.total}, cartItems: ${cartItemsList.length}');

  try {
    final offers = await apiService.getOffer(
      tempOrderId: tempOrderId,
      accessKey: accessKey,
      storeCode: storeCode,
      ipoOrderAmount: cartSnapshot.total,
      cartItems: cartItemsList,
    );

    logger.log('StealDeals: get_offer API returned ${offers.length} offers');
    if (offers.isEmpty) {
      logger.log('StealDeals: No offers returned, widget will be hidden');
      return [];
    }

    // Log each offer briefly
    for (int i = 0; i < offers.length; i++) {
      logger.log(
          'StealDeals: Offer[$i] - offer_p_code: ${offers[i]['offer_p_code']}, offer_name: ${offers[i]['offer_name']}, deal_status: ${offers[i]['deal_status']}');
    }

    // For each offer, fetch product details using offer_p_code
    final productRepository = ref.watch(productRepositoryProvider);
    final List<StealDealOffer> stealDeals = [];

    for (final offer in offers) {
      final pCode = offer['offer_p_code']?.toString() ?? '';
      if (pCode.isEmpty) {
        logger.log(
            'StealDeals: Skipping offer with empty p_code - offer_name: ${offer['offer_name']}');
        continue;
      }

      try {
        logger.log('StealDeals: Fetching product details for pCode: $pCode');
        final product =
            await productRepository.getProductByCode(pCode, storeCode);
        if (product != null) {
          logger.log(
              'StealDeals: Product fetched - ${product.productName} (pCode: $pCode)');
          stealDeals.add(StealDealOffer(
            offer: offer,
            product: product,
          ));
        } else {
          logger.log('StealDeals: Product returned null for pCode: $pCode');
        }
      } catch (e) {
        logger.error(
            'StealDeals: Error fetching product for offer pCode $pCode: $e');
      }
    }

    logger.log(
        'StealDeals: Final result - ${stealDeals.length} steal deals to display');
    return stealDeals;
  } catch (e, stackTrace) {
    logger.error('StealDeals: Error fetching steal deals offers: $e');
    logger.error('StealDeals: StackTrace: $stackTrace');
    return [];
  }
});

/// Model combining offer data with its product details.
class StealDealOffer {
  final Map<String, dynamic> offer;
  final ProductModel product;

  StealDealOffer({required this.offer, required this.product});

  String get offerName => offer['offer_name']?.toString() ?? '';
  String get offerDesc => offer['offer_desc']?.toString() ?? '';
  String get offerConditionText =>
      offer['offer_condition_text']?.toString() ?? '';
  String get offerCouponCode =>
      offer['offer_coupon_code']?.toString() ?? '';
  String get imgPath => offer['img_path']?.toString() ?? '';
  bool get visible =>
      offer['deal_status']?.toString().toLowerCase() == 'unlocked';
  double get minOrderValue =>
      double.tryParse(offer['min_order_value']?.toString() ?? '0') ?? 0;
  double get maxOrderValue =>
      double.tryParse(offer['max_order_value']?.toString() ?? '0') ?? 0;
}
