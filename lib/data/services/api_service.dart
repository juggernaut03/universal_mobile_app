// lib/data/services/api_service.dart

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

  Future<PincodeModel?> getPincodeList() async {
    try {
      // API returns an array with a single pincode object
      // project_code is automatically added by ApiClient.get()
      final response = await _apiClient.get(ApiConstants.getPincodeList);
      final list = (response as List);
      if (list.isEmpty) return null;
      return PincodeModel.fromJson(list.first);
    } catch (e) {
      _logger.error('Error fetching pincode list: $e');
      rethrow;
    }
  }

  Future<List<OutletModel>> getPincodewiseOutlet(String pincode) async {
    try {
      // project_code is automatically added by ApiClient.get()
      final response = await _apiClient.get(
        '${ApiConstants.getPincodewiseOutlet}?pincode=$pincode',
      );
      return (response as List)
          .map((json) => OutletModel.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching outlets: $e');
      rethrow;
    }
  }

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