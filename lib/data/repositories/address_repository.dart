// lib/data/repositories/address_repository.dart

import '../../core/constants/app_constants.dart';
import '../models/address_model.dart';
import 'base_repository.dart';

/// Addresses against the universal backend (/api/address-crud/*).
/// The customer's mobile number comes from the JWT, not the request body.
class AddressRepository extends BaseRepository {

  AddressRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });

  Map<String, dynamic> _toApiBody(Address address) {
    return {
      "full_name": address.fullName.trim(),
      "email_id": address.emailId.trim(),
      "delivery_addr_line_1": address.deliveryAddrLine1.trim(),
      "delivery_addr_line_2": address.deliveryAddrLine2.trim(),
      "delivery_addr_city": address.deliveryAddrCity.trim(),
      "delivery_addr_pincode": address.deliveryAddrPincode.trim(),
      "is_default": address.isDefault,
      "latitude": address.latitude ?? "",
      "longitude": address.longitude ?? "",
      "area_id": address.areaId.isEmpty ? "1" : address.areaId,
    };
  }

  /// Add a new address (POST /api/address-crud/add-address)
  Future<bool> addAddress(Address address) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Adding new address');

        final response = await postWithAuth(
          ApiConstants.addressAdd,
          body: _toApiBody(address),
        );

        if (response is Map<String, dynamic> && response['success'] == true) {
          logActivity('Address added successfully');
          return true;
        }

        logActivity('Failed to add address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Get all addresses for the current user (POST /api/address-crud/get-addresses)
  Future<List<Address>> getAddresses() async {
    return await makeAuthenticatedRequest<List<Address>>(
      () async {
        logActivity('Fetching user addresses');

        final response = await postWithAuth(
          ApiConstants.addressGet,
          body: {},
        );

        if (response is Map<String, dynamic> && response['data'] is List) {
          final addressList = response['data'] as List<dynamic>;
          final addresses = addressList
              .whereType<Map>()
              .map((addressJson) =>
                  Address.fromJson(Map<String, dynamic>.from(addressJson)))
              .toList();

          logActivity('Successfully fetched ${addresses.length} addresses');
          return addresses;
        }

        logActivity('No addresses found or invalid response format');
        return <Address>[];
      },
      onAuthError: () => <Address>[],
    ) ?? <Address>[];
  }

  /// Update an existing address (PUT /api/address-crud/update-address/:id)
  Future<bool> updateAddress(Address address) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Updating address ${address.id}');

        final response = await putWithAuth(
          ApiConstants.addressUpdate(address.id),
          body: _toApiBody(address),
        );

        if (response is Map<String, dynamic> && response['success'] == true) {
          logActivity('Address updated successfully');
          return true;
        }

        logActivity('Failed to update address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Delete an address (DELETE /api/address-crud/delete-address/:id)
  Future<bool> deleteAddress(String addressId) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Deleting address $addressId');

        final response = await deleteWithAuth(
          ApiConstants.addressDelete(addressId),
        );

        if (response is Map<String, dynamic> && response['success'] == true) {
          logActivity('Address deleted successfully');
          return true;
        }

        logActivity('Failed to delete address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Set an address as default — the universal backend clears other defaults
  /// when an address is updated with is_default = 'Yes'.
  Future<bool> setDefaultAddress(String addressId) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Setting default address $addressId');

        final response = await putWithAuth(
          ApiConstants.addressUpdate(addressId),
          body: {"is_default": "Yes"},
        );

        if (response is Map<String, dynamic> && response['success'] == true) {
          logActivity('Default address set successfully');
          return true;
        }

        logActivity('Failed to set default address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }
}

/// Provider for AddressRepository using centralized dependencies
