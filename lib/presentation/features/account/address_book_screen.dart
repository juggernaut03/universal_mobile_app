// lib/presentation/features/account/address_book_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../../data/models/address_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/location_provider.dart';

// Address list provider using direct API call approach
final directAddressListProvider = FutureProvider<List<Address>>((ref) async {
  final logger = ref.read(loggerProvider);
  logger.log('Fetching addresses using direct implementation...');
  
  try {
    // Get access key using the same approach that worked for saving
    String? accessKey;
    
    // Try from user profile first
    try {
      final userProfile = await ref.read(userProfileProvider.future);
      accessKey = userProfile?.accessKey;
      logger.log('Access key from userProfileProvider: $accessKey');
    } catch (e) {
      logger.error('Error getting access key from userProfileProvider: $e');
    }
    
    // If not found, try from SharedPreferences
    if (accessKey == null || accessKey.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      
      // Try user_profile format
      final authProfileStr = prefs.getString('user_profile');
      if (authProfileStr != null) {
        try {
          final authProfile = jsonDecode(authProfileStr);
          accessKey = authProfile['accessKey'];
          logger.log('Access key from SharedPreferences user_profile: $accessKey');
        } catch (e) {
          logger.error('Error parsing user_profile: $e');
        }
      }
      
      // Try otp_validation_response format
      if (accessKey == null || accessKey.isEmpty) {
        final otpResponseStr = prefs.getString('otp_validation_response');
        if (otpResponseStr != null) {
          try {
            final otpResponse = jsonDecode(otpResponseStr);
            accessKey = otpResponse['access_key'];
            logger.log('Access key from otp_validation_response: $accessKey');
          } catch (e) {
            logger.error('Error parsing otp_validation_response: $e');
          }
        }
      }
      
      // Try direct storage format
      if (accessKey == null || accessKey.isEmpty) {
        accessKey = prefs.getString('user_access_key');
        logger.log('Access key from user_access_key: $accessKey');
      }
    }
    
    if (accessKey == null || accessKey.isEmpty) {
      throw Exception('Access key not found. Please log in again.');
    }
    
    // Create request body exactly as in Postman
    final requestBody = {
      "access_key": accessKey,
      "project_code": "RET5890" // Hardcoded to match Postman exactly
    };
    
    logger.log('Request body: ${jsonEncode(requestBody)}');
    
    // Make direct HTTP request to fetch addresses
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse('https://newtech.shalviadvision.com/api/get_address_list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      logger.log('Get address list response status: ${response.statusCode}');
      logger.log('Get address list response body: ${response.body}');
      
      if (response.statusCode == 200) {
        // Try to parse the response as a list first
        try {
          List<dynamic> addressesJson = jsonDecode(response.body);
          return addressesJson.map((json) => Address.fromJson(json)).toList();
        } catch (e) {
          // If list parsing fails, try to parse as a map with a data/addresses field
          final Map<String, dynamic> responseMap = jsonDecode(response.body);
          
          if (responseMap.containsKey('data') && responseMap['data'] is List) {
            List<dynamic> addressesJson = responseMap['data'];
            return addressesJson.map((json) => Address.fromJson(json)).toList();
          } else if (responseMap.containsKey('addresses') && responseMap['addresses'] is List) {
            List<dynamic> addressesJson = responseMap['addresses'];
            return addressesJson.map((json) => Address.fromJson(json)).toList();
          } else if (responseMap.containsKey('insertedItems') && responseMap['insertedItems'] is List) {
            List<dynamic> addressesJson = responseMap['insertedItems'];
            return addressesJson.map((json) => Address.fromJson(json)).toList();
          }
          
          logger.error('Unexpected response format: $responseMap');
          return [];
        }
      } else {
        logger.error('Failed to load addresses: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load addresses: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  } catch (e) {
    logger.error('Error fetching addresses: $e');
    throw e;
  }
});

// Main Address Book Screen
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the direct address list provider instead of the repository-based one
    final addressesAsyncValue = ref.watch(directAddressListProvider);
    final logger = ref.read(loggerProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Book'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/account'),  // Use go instead of pop
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: addressesAsyncValue.when(
          data: (addresses) {
            logger.log('Rendering ${addresses.length} addresses');
            return _buildAddressList(context, ref, addresses);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            logger.error('Error loading addresses: $error');
            return AppErrorWidget(
              errorType: ErrorType.network,
              message: 'Failed to load addresses: $error',
              onRetry: () => ref.refresh(directAddressListProvider),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-address'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAddressList(BuildContext context, WidgetRef ref, List<Address> addresses) {
    if (addresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No addresses found',
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first delivery address',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-address'),
              icon: const Icon(Icons.add),
              label: const Text('ADD NEW ADDRESS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: addresses.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final address = addresses[index];
        return _buildAddressCard(context, ref, address);
      },
    );
  }

  Widget _buildAddressCard(BuildContext context, WidgetRef ref, Address address) {
    final isDefault = address.isDefault.toLowerCase() == 'yes';
    final logger = ref.read(loggerProvider);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDefault ? AppColors.primary : Colors.transparent,
          width: isDefault ? 1 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.fullName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        address.mobileNumber,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '${address.deliveryAddrLine1}, ${address.deliveryAddrLine2}',
              style: AppTextStyles.bodyMedium,
            ),
            Text(
              '${address.deliveryAddrCity} - ${address.deliveryAddrPincode}',
              style: AppTextStyles.bodyMedium,
            ),
            if (address.landmark.isNotEmpty)
              Text(
                'Landmark: ${address.landmark}',
                style: AppTextStyles.bodyMedium,
              ),
            if (address.state.isNotEmpty)
              Text(
                'State: ${address.state}',
                style: AppTextStyles.bodyMedium,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _navigateToEditAddress(context, ref, address, logger);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('EDIT'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                if (!isDefault)
                  TextButton.icon(
                    onPressed: () {
                      _setAsDefault(context, ref, address, logger);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Set Default'), // Fixed typo
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () {
                    _showDeleteConfirmation(context, ref, address, logger);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('DELETE'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditAddress(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Preparing to edit address: ${address.id}');
    
    try {
      // Get current app data to update the address with current pincode and mobile
      String currentPincode = address.deliveryAddrPincode; // fallback
      String currentMobile = address.mobileNumber; // fallback
      
      // Get current selected pincode from the app
      try {
        final selectedPincode = ref.read(selectedPincodeProvider);
        if (selectedPincode != null && selectedPincode.isNotEmpty) {
          currentPincode = selectedPincode;
          logger.log('Using current app pincode: $currentPincode');
        } else {
          logger.warning('No current pincode selected, using stored address pincode: $currentPincode');
        }
      } catch (e) {
        logger.error('Error getting current pincode: $e');
      }
      
      // Get current user mobile from auth provider
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        if (userProfile != null && userProfile.mobile.isNotEmpty) {
          currentMobile = userProfile.mobile;
          logger.log('Using current user mobile: $currentMobile');
        } else {
          logger.warning('No current user mobile, using stored address mobile: $currentMobile');
        }
      } catch (e) {
        logger.error('Error getting current user mobile: $e');
      }
      
      // Create an updated address with current app data for pincode and mobile
      final updatedAddress = address.copyWith(
        deliveryAddrPincode: currentPincode,
        mobileNumber: currentMobile,
      );
      
      // Store the updated address in shared preferences for the edit screen to access
      final prefs = await SharedPreferences.getInstance();
      final addressJson = jsonEncode(updatedAddress.toJson());
      
      logger.log('Saving updated address to edit with current app data: $addressJson');
      await prefs.setString('address_to_edit', addressJson);
      
      if (context.mounted) {
        context.push('/edit-address');
      }
    } catch (e) {
      logger.error('Error preparing address for editing: $e');
      
      // Fallback: use original address if updating fails
      final prefs = await SharedPreferences.getInstance();
      final addressJson = jsonEncode(address.toJson());
      await prefs.setString('address_to_edit', addressJson);
      
      if (context.mounted) {
        context.push('/edit-address');
      }
    }
  }

  // Direct API implementation for setting address as default
  void _setAsDefault(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Setting address as default: ${address.id}');
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Get access key
      String? accessKey;
      
      // Try from user profile first
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        accessKey = userProfile?.accessKey;
        logger.log('Access key from userProfileProvider: $accessKey');
      } catch (e) {
        logger.error('Error getting access key from userProfileProvider: $e');
      }
      
      // If not found, try from SharedPreferences
      if (accessKey == null || accessKey.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        
        // Try user_profile format
        final authProfileStr = prefs.getString('user_profile');
        if (authProfileStr != null) {
          try {
            final authProfile = jsonDecode(authProfileStr);
            accessKey = authProfile['accessKey'];
            logger.log('Access key from SharedPreferences user_profile: $accessKey');
          } catch (e) {
            logger.error('Error parsing user_profile: $e');
          }
        }
        
        // Try otp_validation_response format
        if (accessKey == null || accessKey.isEmpty) {
          final otpResponseStr = prefs.getString('otp_validation_response');
          if (otpResponseStr != null) {
            try {
              final otpResponse = jsonDecode(otpResponseStr);
              accessKey = otpResponse['access_key'];
              logger.log('Access key from otp_validation_response: $accessKey');
            } catch (e) {
              logger.error('Error parsing otp_validation_response: $e');
            }
          }
        }
        
        // Try direct storage format
        if (accessKey == null || accessKey.isEmpty) {
          accessKey = prefs.getString('user_access_key');
          logger.log('Access key from user_access_key: $accessKey');
        }
      }
      
      if (accessKey == null || accessKey.isEmpty) {
        throw Exception('Access key not found. Please log in again.');
      }
      
      // Get current app data for consistency
      String currentPincode = address.deliveryAddrPincode; // fallback
      String currentMobile = address.mobileNumber; // fallback
      
      // Get current selected pincode from the app
      try {
        final selectedPincode = ref.read(selectedPincodeProvider);
        if (selectedPincode != null && selectedPincode.isNotEmpty) {
          currentPincode = selectedPincode;
        }
      } catch (e) {
        logger.error('Error getting current pincode for default update: $e');
      }
      
      // Get current user mobile from auth provider
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        if (userProfile != null && userProfile.mobile.isNotEmpty) {
          currentMobile = userProfile.mobile;
        }
      } catch (e) {
        logger.error('Error getting current user mobile for default update: $e');
      }
      
      // Create a new address with isDefault set to "Yes" and current app data
      final updatedAddress = address.copyWith(
        isDefault: 'Yes',
        deliveryAddrPincode: currentPincode,
        mobileNumber: currentMobile,
      );
      
      // Create request body exactly as in Postman
      final requestBody = {
        "idaddress_book": updatedAddress.id,
        "project_code": "RET5890",
        "full_name": updatedAddress.fullName.trim(),
        "access_key": accessKey,
        "mobile_number": currentMobile.trim(),
        "email_id": updatedAddress.emailId.trim(),
        "delivery_addr_line_1": updatedAddress.deliveryAddrLine1.trim(),
        "delivery_addr_line_2": updatedAddress.deliveryAddrLine2.trim(),
        "delivery_addr_city": updatedAddress.deliveryAddrCity.trim(),
        "delivery_addr_pincode": currentPincode.trim(),
        "is_default": "Yes", // Set as default
        "latitude": updatedAddress.latitude ?? "",
        "longitude": updatedAddress.longitude ?? "",
        "area_id": updatedAddress.areaId.isEmpty ? "1" : updatedAddress.areaId,
      };
      
      logger.log('Request body: ${jsonEncode(requestBody)}');
      
      // Make direct HTTP request
      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse('https://newtech.shalviadvision.com/api/update_address/${address.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );
        
        logger.log('Update address response status: ${response.statusCode}');
        logger.log('Update address response body: ${response.body}');
        
        bool success = false;
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          if (responseData.containsKey('message') && 
              responseData['message'].toString().toLowerCase().contains('success')) {
            logger.log('Address updated successfully');
            success = true;
          }
        }
        
        // If first attempt fails, try the add_address endpoint
        if (!success) {
          logger.log('First update attempt failed, trying add_address endpoint');
          final addResponse = await client.post(
            Uri.parse('https://newtech.shalviadvision.com/api/add_address'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          );
          
          logger.log('Alternative update response status: ${addResponse.statusCode}');
          logger.log('Alternative update response body: ${addResponse.body}');
          
          if (addResponse.statusCode == 200 || addResponse.statusCode == 201) {
            final responseData = jsonDecode(addResponse.body);
            if (responseData.containsKey('message') && 
                responseData['message'].toString().toLowerCase().contains('success')) {
              logger.log('Address updated successfully via add_address');
              success = true;
            }
          }
        }
        
        // Close loading dialog
        if (context.mounted) {
          Navigator.pop(context);
          
          // Show result message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success 
                    ? 'Address set as default' 
                    : 'Failed to set address as default',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          
          // Refresh addresses
          if (success) {
            ref.refresh(directAddressListProvider);
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      logger.error('Error setting address as default: $e');
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting address as default: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Address address, Logger logger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // Close the confirmation dialog
              Navigator.pop(context);
              // Call the delete function
              _deleteAddress(context, ref, address, logger);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // Direct API implementation for deleting address
  void _deleteAddress(BuildContext context, WidgetRef ref, Address address, Logger logger) async {
    logger.log('Deleting address: ${address.id}');
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Get access key
      String? accessKey;
      
      // Try from user profile first
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        accessKey = userProfile?.accessKey;
        logger.log('Access key from userProfileProvider: $accessKey');
      } catch (e) {
        logger.error('Error getting access key from userProfileProvider: $e');
      }
      
      // If not found, try from SharedPreferences
      if (accessKey == null || accessKey.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        
        // Try user_profile format
        final authProfileStr = prefs.getString('user_profile');
        if (authProfileStr != null) {
          try {
            final authProfile = jsonDecode(authProfileStr);
            accessKey = authProfile['accessKey'];
            logger.log('Access key from SharedPreferences user_profile: $accessKey');
          } catch (e) {
            logger.error('Error parsing user_profile: $e');
          }
        }
        
        // Try otp_validation_response format
        if (accessKey == null || accessKey.isEmpty) {
          final otpResponseStr = prefs.getString('otp_validation_response');
          if (otpResponseStr != null) {
            try {
              final otpResponse = jsonDecode(otpResponseStr);
              accessKey = otpResponse['access_key'];
              logger.log('Access key from otp_validation_response: $accessKey');
            } catch (e) {
              logger.error('Error parsing otp_validation_response: $e');
            }
          }
        }
        
        // Try direct storage format
        if (accessKey == null || accessKey.isEmpty) {
          accessKey = prefs.getString('user_access_key');
          logger.log('Access key from user_access_key: $accessKey');
        }
      }
      
      if (accessKey == null || accessKey.isEmpty) {
        throw Exception('Access key not found. Please log in again.');
      }
      
      // Create request body exactly as in Postman
      final requestBody = {
        "access_key": accessKey,
        "project_code": "RET5890"
      };
      
      logger.log('Request body: ${jsonEncode(requestBody)}');
      
      // Make direct HTTP request
      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse('https://newtech.shalviadvision.com/api/delete_address/${address.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );
        
        logger.log('Delete address response status: ${response.statusCode}');
        logger.log('Delete address response body: ${response.body}');
        
        bool success = false;
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          if (responseData.containsKey('message') && 
              responseData['message'].toString().toLowerCase().contains('success')) {
            logger.log('Address deleted successfully');
            success = true;
          }
        }
        
        // Close loading dialog
        if (context.mounted) {
          Navigator.pop(context);
          
          // Show result message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success 
                    ? 'Address deleted successfully' 
                    : 'Failed to delete address',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          
          // Refresh addresses list if successful
          if (success) {
            ref.refresh(directAddressListProvider);
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      logger.error('Error deleting address: $e');
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}