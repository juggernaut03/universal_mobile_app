import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../../core/auth/centralized_auth_manager.dart';
import 'launch_flow_provider.dart';
import 'outlet_provider.dart';
import 'cart_provider.dart';
import 'subcategory_providers.dart';

/// Provider that fetches offers from the get_offer API and returns
/// the product details for each offer's offer_p_code.
final stealDealsOffersProvider =
    FutureProvider.autoDispose<List<StealDealOffer>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final logger = ref.watch(loggerProvider);
  final selectedOutlet = ref.watch(selectedOutletProvider).valueOrNull;
  final storeCode = selectedOutlet?.storeCode ?? 'KLK';

  // Get temp_order_id from SharedPreferences
  final prefs = ref.watch(sharedPreferencesProvider);
  final tempOrderId = prefs.getString('temp_order_id') ?? '';

  // Get access_key from auth manager
  final authManager = ref.watch(centralizedAuthManagerProvider);
  final accessKey = await authManager.getValidAccessKey() ?? '';

  // Get cart total as ipo_order_amount
  final cartTotal = ref.watch(cartTotalProvider);

  // Get cart items for the request
  final cartItems = ref.watch(cartProvider);
  final cartItemsList = cartItems
      .map((item) => {
            'p_code': item.product.pCode,
            'quantity': item.quantity,
          })
      .toList();

  try {
    final offers = await apiService.getOffer(
      tempOrderId: tempOrderId,
      accessKey: accessKey,
      storeCode: storeCode,
      ipoOrderAmount: cartTotal,
      cartItems: cartItemsList,
    );

    if (offers.isEmpty) return [];

    // For each offer, fetch product details using offer_p_code
    final productRepository = ref.watch(productRepositoryProvider);
    final List<StealDealOffer> stealDeals = [];

    for (final offer in offers) {
      final pCode = offer['offer_p_code']?.toString() ?? '';
      if (pCode.isEmpty) continue;

      try {
        final product = await productRepository.getProductByCode(pCode, storeCode);
        if (product != null) {
          stealDeals.add(StealDealOffer(
            offer: offer,
            product: product,
          ));
        }
      } catch (e) {
        logger.error('Error fetching product for offer pCode $pCode: $e');
      }
    }

    return stealDeals;
  } catch (e) {
    logger.error('Error fetching steal deals offers: $e');
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
  String get offerConditionText => offer['offer_condition_text']?.toString() ?? '';
  String get offerCouponCode => offer['offer_coupon_code']?.toString() ?? '';
  String get imgPath => offer['img_path']?.toString() ?? '';
  bool get visible => offer['visible']?.toString() == 'true';
  double get minOrderValue =>
      double.tryParse(offer['min_order_value']?.toString() ?? '0') ?? 0;
  double get maxOrderValue =>
      double.tryParse(offer['max_order_value']?.toString() ?? '0') ?? 0;
}
