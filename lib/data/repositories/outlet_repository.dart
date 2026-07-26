// lib/data/repositories/outlet_repository.dart

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/outlet_model.dart';
import '../models/offer_model.dart';

class OutletRepository {
  final ApiService _apiService;
  final StorageService _storageService;

  OutletRepository({
    required ApiService apiService,
    required StorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService;

  Future<List<OutletModel>> getOutletsForPincode(String pincode) async {
    return await _apiService.getPincodewiseOutlet(pincode);
  }

  Future<bool> saveSelectedOutlet(OutletModel outlet) async {
    return await _storageService.saveSelectedOutlet(outlet);
  }

  OutletModel? getSelectedOutlet() {
    return _storageService.getSelectedOutlet();
  }

  Future<OfferModel> getOfferForOutlet(String storeCode) async {
    return await _apiService.getOfferScreen(storeCode);
  }
}