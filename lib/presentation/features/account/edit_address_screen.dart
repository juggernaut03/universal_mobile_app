// lib/presentation/features/account/edit_address_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';

class EditAddressScreen extends ConsumerStatefulWidget {
  final bool returnToCheckout;
  
  const EditAddressScreen({
    Key? key,
    this.returnToCheckout = false,
  }) : super(key: key);

  @override
  ConsumerState<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends ConsumerState<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late Address _address;
  late TextEditingController _fullNameController;
  late TextEditingController _pincodeController;
  late TextEditingController _areaController;
  late TextEditingController _localityController;
  late TextEditingController _wingFloorController;
  late TextEditingController _landmarkController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _contactNumberController;
  
  bool _isLoading = true;
  bool _isDefault = false;
  String _errorMessage = '';
  
  // Variables to store coordinates
  String _latitude = '';
  String _longitude = '';
  
  @override
  void initState() {
    super.initState();
    _loadAddress();
  }
  
  Future<void> _loadAddress() async {
    final logger = ref.read(loggerProvider);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressJson = prefs.getString('address_to_edit');
      
      if (addressJson == null) {
        logger.error('No address found to edit');
        setState(() {
          _errorMessage = 'No address found to edit';
          _isLoading = false;
        });
        return;
      }
      
      logger.log('Loading address from storage: $addressJson');
      final addressMap = jsonDecode(addressJson);
      _address = Address.fromJson(addressMap);
      
      _fullNameController = TextEditingController(text: _address.fullName);
      _pincodeController = TextEditingController(text: _address.deliveryAddrPincode);
      _areaController = TextEditingController(text: _address.areaId.isEmpty ? "1" : _address.areaId); 
      _localityController = TextEditingController(text: _address.deliveryAddrLine2);
      _wingFloorController = TextEditingController(text: _address.deliveryAddrLine1);
      _landmarkController = TextEditingController(text: _address.landmark);
      _cityController = TextEditingController(text: _address.deliveryAddrCity);
      _stateController = TextEditingController(text: _address.state);
      _contactNumberController = TextEditingController(text: _address.mobileNumber);
      
      // Extract coordinates if available (will be empty strings if not set)
      _latitude = _address.latitude ?? '';
      _longitude = _address.longitude ?? '';
      
      _isDefault = _address.isDefault.toLowerCase() == 'yes';
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      logger.error('Error loading address to edit: $e');
      setState(() {
        _errorMessage = 'Error loading address: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _pincodeController.dispose();
    _areaController.dispose();
    _localityController.dispose();
    _wingFloorController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }
  
  // Get coordinates from the entered address
  Future<void> _getCoordinatesFromAddress() async {
    final logger = ref.read(loggerProvider);
    
    try {
      // Build a complete address string from form fields
      final addressString = [
        _wingFloorController.text.trim(),
        _localityController.text.trim(),
        _areaController.text.trim(),
        _cityController.text.trim(),
        _stateController.text.trim(),
        _pincodeController.text.trim(),
      ].where((part) => part.isNotEmpty).join(', ');
      
      if (addressString.isEmpty) {
        logger.error('Address string is empty, cannot geocode');
        return;
      }
      
      logger.log('Geocoding address: $addressString');
      
      // Use geocoding package to get coordinates
      final locations = await locationFromAddress(addressString);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _latitude = location.latitude.toString();
          _longitude = location.longitude.toString();
        });
        
        logger.log('Got coordinates: $_latitude, $_longitude');
      } else {
        logger.error('No coordinates found for address');
      }
    } catch (e) {
      logger.error('Error geocoding address: $e');
      // We'll still continue even if geocoding fails
    }
  }
  
  // Direct implementation to update address
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final logger = ref.read(loggerProvider);
    logger.log('Saving changes to address: ${_address.id}');
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Attempt to get coordinates if we don't have them yet
      if (_latitude.isEmpty || _longitude.isEmpty) {
        await _getCoordinatesFromAddress();
      }
      
      // Get access key
      String? accessKey;
      
      // Try from user profile first
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        accessKey = userProfile?.accessKey;
        logger.log('Access key from userProfile: $accessKey');
      } catch (e) {
        logger.error('Error getting access key from userProfile: $e');
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
        setState(() {
          _isLoading = false;
          _errorMessage = 'Access key not found. Please log in again.';
        });
        return;
      }
      
      // Format mobile number (remove prefix if present)
      String mobileNumber = _contactNumberController.text;
      if (mobileNumber.startsWith('+91 | ')) {
        mobileNumber = mobileNumber.replaceAll('+91 | ', '');
      }
      
      // Create request body exactly like Postman
      final requestBody = {
        "idaddress_book": _address.id,
        "project_code": "RET5890",
        "full_name": _fullNameController.text.trim(),
        "access_key": accessKey,
        "mobile_number": mobileNumber.trim(),
        "email_id": _address.emailId.isEmpty ? "test@example.com" : _address.emailId.trim(),
        "delivery_addr_line_1": _wingFloorController.text.trim(),
        "delivery_addr_line_2": _localityController.text.trim(),
        "delivery_addr_city": _cityController.text.trim(),
        "delivery_addr_pincode": _pincodeController.text.trim(),
        "is_default": _isDefault ? "Yes" : "No",
        "latitude": _latitude,
        "longitude": _longitude,
        "area_id": _areaController.text.isEmpty ? "1" : _areaController.text.trim(),
      };
      
      logger.log('Request body: ${jsonEncode(requestBody)}');
      
      // Make direct HTTP request
      final client = http.Client();
      bool success = false;
      
      try {
        // First try the update_address/{id} endpoint
        logger.log('Trying update_address endpoint');
        var response = await client.post(
          Uri.parse('https://newtech.shalviadvision.com/api/update_address/${_address.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );
        
        logger.log('Update address response status: ${response.statusCode}');
        logger.log('Update address response body: ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          if (responseData.containsKey('message') && 
              responseData['message'].toString().toLowerCase().contains('success')) {
            logger.log('Address updated successfully');
            success = true;
          }
        }
        
        // If the first attempt fails, try the add_address endpoint
        if (!success) {
          logger.log('First update attempt failed, trying add_address endpoint');
          response = await client.post(
            Uri.parse('https://newtech.shalviadvision.com/api/add_address'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          );
          
          logger.log('Alternative update response status: ${response.statusCode}');
          logger.log('Alternative update response body: ${response.body}');
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            final responseData = jsonDecode(response.body);
            if (responseData.containsKey('message') && 
                responseData['message'].toString().toLowerCase().contains('success')) {
              logger.log('Address updated successfully via add_address');
              success = true;
            }
          }
        }
      } finally {
        client.close();
      }
      
      // Show success/failure message and navigate
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Address updated successfully' : 'Failed to update address'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        
        // Navigate based on where we came from
        if (success) {
          if (widget.returnToCheckout) {
            context.go('/checkout-flow');
          } else {
            context.go('/address-book');
          }
        }
      }
    } catch (e) {
      logger.error('Error updating address: $e');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error updating address: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Address'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty && _isLoading == false) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Address'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error Loading Address',
                style: AppTextStyles.h5,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.go('/address-book');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('GO BACK'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Address'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.returnToCheckout) {
              context.go('/checkout-flow'); // Go back to checkout flow
            } else {
              context.go('/address-book'); // Go back to address book
            }
          },
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message if any
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                    
                  // Form fields
                  _buildFormField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  
                  _buildFormField(
                    controller: _pincodeController,
                    label: 'Pincode',
                    isRequired: true,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter pincode';
                      }
                      if (value.length != 6) {
                        return 'Pincode must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  
                  _buildFormField(
                    controller: _areaController,
                    label: 'Area',
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter area';
                      }
                      return null;
                    },
                  ),
                  
                  _buildFormField(
                    controller: _localityController,
                    label: 'Locality/ Street Name/ Apartment',
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter locality details';
                      }
                      return null;
                    },
                  ),
                  
                  _buildFormField(
                    controller: _wingFloorController,
                    label: 'Wing/ Floor/ Flat/ House No.',
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter wing/floor details';
                      }
                      return null;
                    },
                  ),
                  
                  _buildFormField(
                    controller: _landmarkController,
                    label: 'Landmark (optional)',
                    isRequired: false,
                  ),
                  
                  _buildFormField(
                    controller: _cityController,
                    label: 'City',
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter city';
                      }
                      return null;
                    },
                  ),
                  
                  _buildFormField(
                    controller: _stateController,
                    label: 'State',
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter state';
                      }
                      return null;
                    },
                  ),
                  
                  _buildFormField(
                    controller: _contactNumberController,
                    label: 'Contact Number for Order Delivery',
                    isRequired: true,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter contact number';
                      }
                      // Remove prefix if present
                      String mobileNumber = value;
                      if (mobileNumber.startsWith('+91 | ')) {
                        mobileNumber = mobileNumber.replaceAll('+91 | ', '');
                      }
                      if (mobileNumber.length != 10) {
                        return 'Please enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                    prefixText: '+91 | ',
                  ),
                  
                  // Display coordinates if available (can be removed in production)
                  if (_latitude.isNotEmpty && _longitude.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coordinates',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Latitude: $_latitude, Longitude: $_longitude',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Default address checkbox
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isDefault,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _isDefault = value ?? false;
                            });
                          },
                        ),
                        const Text('Set as default address'),
                      ],
                    ),
                  ),
                  
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE CHANGES'),
                    ),
                  ),
                  
                  // Regenerate geocoordinates button
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _getCoordinatesFromAddress,
                    icon: const Icon(Icons.refresh),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                    ),
                    label: const Text('REGENERATE COORDINATES'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required bool isRequired,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? prefixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            readOnly: readOnly,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixText: prefixText,
            ),
          ),
        ],
      ),
    );
  }
}