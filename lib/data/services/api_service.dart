// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:patelmart/core/constants/app_constants.dart';
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

  /// POST /check_if_pincode_exists
  /// Body: { pincode, project_code }
  Future<PincodeCheckResponse> checkIfPincodeExists(String pincode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.checkPincode,
        body: {'pincode': pincode},
        // Note: project_code is automatically added by ApiClient.post()
      );
      return PincodeCheckResponse.fromJson(response);
    } catch (e) {
      _logger.error('Error checking pincode: $e');
      rethrow;
    }
  }

  /// GET /get_pincode_list
  /// project_code is automatically sent as a query param by ApiClient.get()
  Future<List<PincodeModel>> getPincodeList() async {
    try {
      final response = await _apiClient.get(ApiConstants.getPincodeList, includeProjectCode: false);
      final list = (response as List);
      return list.map((json) => PincodeModel.fromJson(json)).toList();
    } catch (e) {
      _logger.error('Error fetching pincode list: $e');
      rethrow;
    }
  }

  /// POST /get_pincodewise_outlet
  /// Body: { pincode, project_code }
  Future<List<OutletModel>> getPincodewiseOutlet(String pincode) async {
    try {
      // Fixed: was incorrectly using GET with query params.
      // Postman spec requires POST with { pincode, project_code } in body.
      final response = await _apiClient.post(
        ApiConstants.getPincodewiseOutlet,
        body: {'pincode': pincode},
        // project_code is automatically added by ApiClient.post()
      );
      return (response as List)
          .map((json) => OutletModel.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching outlets: $e');
      rethrow;
    }
  }

  /// POST /get_store_details
  /// Body: { store_code, project_code }
  Future<Map<String, dynamic>?> getStoreDetails(String storeCode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.getStoreDetails,
        body: {'store_code': storeCode},
        // project_code is automatically added by ApiClient.post()
      );
      if (response is List && response.isNotEmpty) {
        return response.first as Map<String, dynamic>;
      }
      return response as Map<String, dynamic>?;
    } catch (e) {
      _logger.error('Error fetching store details: $e');
      rethrow;
    }
  }

  /// POST /get_active_department_list
  /// Body: { store_code, project_code }
  Future<List<dynamic>> getActiveDepartmentList(String storeCode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.getActiveDepartmentList,
        body: {'store_code': storeCode},
        // project_code is automatically added by ApiClient.post()
      );
      return response as List;
    } catch (e) {
      _logger.error('Error fetching department list: $e');
      rethrow;
    }
  }

  /// POST /get_active_categories_list
  /// Body: { department_id, store_code, project_code }
  Future<List<dynamic>> getActiveCategoriesList({
    required String departmentId,
    required String storeCode,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.getActiveCategoriesList,
        body: {
          'department_id': departmentId,
          'store_code': storeCode,
        },
        // project_code is automatically added by ApiClient.post()
      );
      return response as List;
    } catch (e) {
      _logger.error('Error fetching categories list: $e');
      rethrow;
    }
  }

  /// POST /get_offer
  /// Body: { temp_order_id, access_key, store_code, project_code, ipo_order_amount, cart_items }
  Future<List<Map<String, dynamic>>> getOffer({
    required String tempOrderId,
    required String accessKey,
    required String storeCode,
    required double ipoOrderAmount,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    try {
      final body = {
        'temp_order_id': tempOrderId,
        'access_key': accessKey,
        'store_code': storeCode,
        'ipo_order_amount': ipoOrderAmount,
        'cart_items': cartItems,
      };
      debugPrint('=== GET OFFER REQUEST BODY ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(body));
      debugPrint('=============================');
      final response = await _apiClient.post(
        ApiConstants.getOffer,
        body: body,
      );
      debugPrint('=== GET OFFER RESPONSE BODY ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(response));
      debugPrint('===============================');
      // Handle new response format: { "offer_list": [...] }
      if (response is Map<String, dynamic> &&
          response.containsKey('offer_list')) {
        final offerList = response['offer_list'];
        if (offerList is List) {
          return offerList.cast<Map<String, dynamic>>();
        }
      }
      // Legacy format: direct list
      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _logger.error('Error fetching offers: $e');
      rethrow;
    }
  }

  /// POST /get_offerscreen
  /// Body: { store_code, project_code }
  Future<OfferModel> getOfferScreen(String storeCode) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.getOfferScreen,
        body: {'store_code': storeCode},
        // Note: project_code is automatically added by ApiClient.post()
      );
      return OfferModel.fromJson(response);
    } catch (e) {
      _logger.error('Error fetching offer: $e');
      rethrow;
    }
  }
}