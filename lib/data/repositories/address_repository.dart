// lib/data/repositories/address_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../models/address_model.dart';
import 'base_repository.dart';

class AddressRepository extends BaseRepository {
  
  AddressRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });

  /// Add a new address using centralized auth management
  Future<bool> addAddress(Address address) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Adding new address');
        
        // Format exactly as shown in the successful Postman request
        final requestData = {
          "idaddress_book": "12", // This is a default ID for new addresses as seen in Postman
          "full_name": address.fullName.trim(),
          "mobile_number": address.mobileNumber.trim(),
          "email_id": address.emailId.trim(),
          "delivery_addr_line_1": address.deliveryAddrLine1.trim(),
          "delivery_addr_line_2": address.deliveryAddrLine2.trim(),
          "delivery_addr_city": address.deliveryAddrCity.trim(),
          "delivery_addr_pincode": address.deliveryAddrPincode.trim(),
          "is_default": address.isDefault,
          "latitude": "", // Empty string as shown in Postman
          "longitude": "", // Empty string as shown in Postman
          "area_id": address.areaId.isEmpty ? "1" : address.areaId,
        };
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/add_address',
          body: requestData,
        );
        
        // Check for exact success message wording from Postman
        if (response is Map<String, dynamic>) {
          if (response.containsKey('insertedItems') || 
              (response.containsKey('message') && 
               response['message'].toString().contains("Address Inserted Successfully"))) {
            logActivity('Address added successfully');
            return true;
          }
        }
        
        logActivity('Failed to add address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Get all addresses for the current user using centralized auth management
  Future<List<Address>> getAddresses() async {
    return await makeAuthenticatedRequest<List<Address>>(
      () async {
        logActivity('Fetching user addresses');
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/get_address',
          body: {}, // Empty body as access_key is automatically added
        );
        
        if (response is Map<String, dynamic> && response.containsKey('addresses')) {
          final addressList = response['addresses'] as List<dynamic>;
          final addresses = addressList
              .map((addressJson) => Address.fromJson(addressJson as Map<String, dynamic>))
              .toList();
          
          logActivity('Successfully fetched addresses');
          return addresses;
        }
        
        logActivity('No addresses found or invalid response format');
        return <Address>[];
      },
      onAuthError: () => <Address>[],
    ) ?? <Address>[];
  }

  /// Update an existing address using centralized auth management
  Future<bool> updateAddress(Address address) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Updating address');
        
        // Format for update request
        final requestData = {
          "idaddress_book": address.id,
          "full_name": address.fullName.trim(),
          "mobile_number": address.mobileNumber.trim(),
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
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/update_address',
          body: requestData,
        );
        
        if (response is Map<String, dynamic>) {
          if (response.containsKey('message') && 
              response['message'].toString().contains("updated successfully")) {
            logActivity('Address updated successfully');
            return true;
          }
        }
        
        logActivity('Failed to update address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Delete an address using centralized auth management
  Future<bool> deleteAddress(String addressId) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Deleting address');
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/delete_address',
          body: {
            "idaddress_book": addressId,
          },
        );
        
        if (response is Map<String, dynamic>) {
          if (response.containsKey('message') && 
              response['message'].toString().contains("deleted successfully")) {
            logActivity('Address deleted successfully');
            return true;
          }
        }
        
        logActivity('Failed to delete address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }

  /// Set an address as default using centralized auth management
  Future<bool> setDefaultAddress(String addressId) async {
    return await makeAuthenticatedRequest<bool>(
      () async {
        logActivity('Setting default address');
        
        final response = await postWithAuth(
          '${ApiConstants.baseUrl}/set_default_address',
          body: {
            "idaddress_book": addressId,
          },
        );
        
        if (response is Map<String, dynamic>) {
          if (response.containsKey('message') && 
              (response['message'].toString().contains("default") ||
               response['message'].toString().contains("success"))) {
            logActivity('Default address set successfully');
            return true;
          }
        }
        
        logActivity('Failed to set default address');
        return false;
      },
      onAuthError: () => false,
    ) ?? false;
  }
}

/// Provider for AddressRepository using centralized dependencies
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final dependencies = ref.watch(baseRepositoryDependenciesProvider);
  
  return AddressRepository(
    authManager: dependencies.authManager,
    apiClient: dependencies.apiClient,
    logger: dependencies.logger,
  );
});