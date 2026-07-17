// lib/data/services/api_service.dart

import 'package:patelmart/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/pincode_model.dart';
import '../models/outlet_model.dart';
import '../models/offer_model.dart';

class ApiService {
  final ApiClient _apiClient;
  final Logger _logger;

  ApiService({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// POST /api/pincodes/check-availability
  Future<PincodeCheckResponse> checkIfPincodeExists(String pincode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.checkPincode,
        body: {'pincode': pincode},
      );
      return PincodeCheckResponse.fromJson(response);
    } catch (e) {
      _logger.error('Error checking pincode: $e');
      rethrow;
    }
  }

  /// GET /api/pincodes/enabled/list
  Future<List<PincodeModel>> getPincodeList() async {
    try {
      final response = await _apiClient.get(ApiConstants.getPincodeList);
      final list = (response is Map ? response['data'] : response) as List? ?? [];
      return list.map((json) => PincodeModel.fromJson(json)).toList();
    } catch (e) {
      _logger.error('Error fetching pincode list: $e');
      rethrow;
    }
  }

  /// POST /api/stores/by-pincode
  Future<List<OutletModel>> getPincodewiseOutlet(String pincode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.getPincodewiseOutlet,
        body: {'pincode': pincode},
      );
      final list = (response is Map ? response['data'] : response) as List? ?? [];
      return list.map((json) => OutletModel.fromJson(json)).toList();
    } catch (e) {
      _logger.error('Error fetching outlets: $e');
      rethrow;
    }
  }

  /// Store details come from /api/stores/by-pincode (there is no separate
  /// details endpoint on the universal backend). Looks up the saved pincode
  /// and returns the matching store as a legacy-keyed map so existing
  /// consumers (StoreDetails.fromJson) keep working.
  Future<Map<String, dynamic>?> getStoreDetails(String storeCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pincode = prefs.getString(ApiConstants.keyPincode);
      if (pincode == null || pincode.isEmpty) {
        _logger.warning('getStoreDetails: no saved pincode');
        return null;
      }

      final response = await _apiClient.post(
        ApiConstants.getPincodewiseOutlet,
        body: {'pincode': pincode},
      );
      final list = (response is Map ? response['data'] : response) as List? ?? [];
      final store = list.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s?['store_code'] == storeCode,
            orElse: () => null,
          );
      if (store == null) return null;

      final location = store['location'] is Map<String, dynamic>
          ? store['location'] as Map<String, dynamic>
          : <String, dynamic>{};
      final contact = store['contact'] is Map<String, dynamic>
          ? store['contact'] as Map<String, dynamic>
          : <String, dynamic>{};

      // Legacy key names expected by StoreDetails.fromJson
      return {
        '_id': (store['id'] ?? '').toString(),
        'pincode': store['pincode'] ?? '',
        'mobile_outlet_name': store['store_name'] ?? '',
        'store_code': store['store_code'] ?? '',
        'is_enabled': store['is_enabled'] ?? '',
        'store_address': store['address'] ?? '',
        'min_order_amount': store['min_order_amount'] ?? 0,
        'store_open_time': store['store_open_time'] ?? '',
        'store_delivery_time': store['delivery_time'] ?? '',
        'latitude': location['latitude'] ?? '',
        'longitude': location['longitude'] ?? '',
        'contact_number': contact['phone'] ?? '',
        'email': contact['email'] ?? '',
      };
    } catch (e) {
      _logger.error('Error fetching store details: $e');
      rethrow;
    }
  }

  /// POST /api/departments/by-store.
  /// Departments may be tenant-global (store_code null in the DB) — if the
  /// store-specific query is empty, fall back to the shared catalog.
  Future<List<dynamic>> getActiveDepartmentList(String storeCode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.getActiveDepartmentList,
        body: {'store_code': storeCode},
      );
      final list = (response is Map ? response['data'] : response) as List? ?? [];
      if (list.isNotEmpty) return list;

      final fallback = await _apiClient.post(
        ApiConstants.getActiveDepartmentList,
        body: {'store_code': 'null'},
      );
      return (fallback is Map ? fallback['data'] : fallback) as List? ?? [];
    } catch (e) {
      _logger.error('Error fetching department list: $e');
      rethrow;
    }
  }

  /// POST /api/categories/get-categories
  Future<List<dynamic>> getActiveCategoriesList({
    required String departmentId,
    required String storeCode,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.getActiveCategoriesList,
        body: {
          'dept_id': departmentId,
          'store_code': storeCode,
        },
      );
      return (response is Map ? response['data'] : response) as List? ?? [];
    } catch (e) {
      _logger.error('Error fetching categories list: $e');
      rethrow;
    }
  }

  /// GET /api/offers/for-cart — cart offers and product deals.
  /// Maps the universal backend's product_deals onto the legacy offer keys
  /// the steal-deals UI reads (offer_p_code, offer_status, offer_visible...).
  Future<OfferApiResponse> getOffer({
    required String tempOrderId,
    required String accessKey,
    required String storeCode,
    required double ipoOrderAmount,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    try {
      final response = await _apiClient.getWithAuth(
        ApiConstants.offersForCart,
        additionalParams: {
          'store_code': storeCode,
          'cart_total': ipoOrderAmount.toStringAsFixed(2),
        },
      );

      final data = response is Map<String, dynamic> &&
              response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      final List<Map<String, dynamic>> offers = [];

      final deals = data['product_deals'];
      if (deals is List) {
        for (final deal in deals) {
          if (deal is! Map<String, dynamic>) continue;
          final dealProducts = deal['deal_products'];
          final pCodes = <String>[];
          if (dealProducts is List) {
            for (final p in dealProducts) {
              final code = (p is Map ? p['p_code'] : null)?.toString() ?? '';
              if (code.isNotEmpty) pCodes.add(code);
            }
          }

          offers.add({
            ...deal,
            'offer_p_code': pCodes,
            'offer_name': deal['title'] ?? '',
            'offer_heading_text': deal['title'] ?? '',
            'offer_desc': deal['description'] ?? '',
            'offer_status': deal['unlocked'] == true ? 'Unlocked' : 'Locked',
            'offer_visible': 'true',
            'min_order_value': deal['min_cart_value'] ?? 0,
            'ipo_order_amount': ipoOrderAmount,
          });
        }
      }

      _logger.log('offers/for-cart returned ${offers.length} product deal(s)');
      return OfferApiResponse(offers: offers);
    } catch (e) {
      _logger.error('Error fetching offers: $e');
      rethrow;
    }
  }

  /// The legacy offer-screen endpoint has no universal equivalent — return an
  /// empty banner so the UI hides the section (fail-soft).
  Future<OfferModel> getOfferScreen(String storeCode) async {
    return OfferModel(imageUrl: '');
  }
}

/// Response model for cart offers containing panel colors + offer list.
class OfferApiResponse {
  final List<Map<String, dynamic>> offers;
  final String pannelBgColor;
  final String pannelHeadingTxtColor;
  final String pannelDescriptTxtColor;
  final String pannelUnlockTxtColor;
  final String pannelUnlockBgColor;

  OfferApiResponse({
    required this.offers,
    this.pannelBgColor = '',
    this.pannelHeadingTxtColor = '',
    this.pannelDescriptTxtColor = '',
    this.pannelUnlockTxtColor = '',
    this.pannelUnlockBgColor = '',
  });
}
