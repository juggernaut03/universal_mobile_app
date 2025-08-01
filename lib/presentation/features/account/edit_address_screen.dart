// lib/presentation/features/account/edit_address_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/core/auth/centralized_auth_manager.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/presentation/features/account/address_book_screen.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import 'package:patelmart/core/auth/centralized_auth_manager.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';


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
      _areaController = TextEditingController(text: _address.areaId.isEmpty ? "1" : _address.areaId); 
      _localityController = TextEditingController(text: _address.deliveryAddrLine2);
      _wingFloorController = TextEditingController(text: _address.deliveryAddrLine1);
      _landmarkController = TextEditingController(text: _address.landmark);
      _cityController = TextEditingController(text: _address.deliveryAddrCity);
      _stateController = TextEditingController(text: _address.state);
      
      // For pincode and contact number, use current app data instead of stored address data
      await _loadCurrentAppData();
      
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
  
  Future<void> _loadCurrentAppData() async {
    final logger = ref.read(loggerProvider);
    
    try {
      // Load current user mobile number from auth provider
      final userProfile = await ref.read(userProfileProvider.future);
      if (userProfile != null) {
        _contactNumberController = TextEditingController(text: userProfile.mobile);
        logger.log('Loaded current user mobile number: ${userProfile.mobile}');
      } else {
        // Fallback to address mobile number if auth provider fails
        _contactNumberController = TextEditingController(text: _address.mobileNumber);
        logger.warning('Using address mobile number as fallback: ${_address.mobileNumber}');
      }
    } catch (e) {
      logger.error('Error loading user mobile number, using address mobile: $e');
      _contactNumberController = TextEditingController(text: _address.mobileNumber);
    }
    
    try {
      // Load current selected pincode from location provider
      final selectedPincode = ref.read(selectedPincodeProvider);
      if (selectedPincode != null && selectedPincode.isNotEmpty) {
        _pincodeController = TextEditingController(text: selectedPincode);
        logger.log('Loaded current selected pincode: $selectedPincode');
      } else {
        // Fallback to address pincode if no pincode selected
        _pincodeController = TextEditingController(text: _address.deliveryAddrPincode);
        logger.warning('Using address pincode as fallback: ${_address.deliveryAddrPincode}');
      }
    } catch (e) {
      logger.error('Error loading selected pincode, using address pincode: $e');
      _pincodeController = TextEditingController(text: _address.deliveryAddrPincode);
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
  
  // Updated implementation using centralized access key management
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
      
      // Get access key using centralized manager
      final authManager = ref.read(auth.centralizedAuthManagerProvider);
      final accessKey = await authManager.getValidAccessKey();
      
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
        "email_id": _address.emailId.isEmpty ? "" : _address.emailId.trim(),
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
          Uri.parse('https://grahakpethnewtech.shalviadvision.com/grahakapi/update_address/${_address.id}'),
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
            Uri.parse('https://grahakpethnewtech.shalviadvision.com/grahakapi/add_address'),
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
      
      // Refresh address list if successful
      if (success) {
        try {
          // Import the updated address list provider from address_book_screen
          ref.refresh(addressListProvider);
          logger.log('Address list provider refreshed');
        } catch (e) {
          logger.warning('Could not refresh address list provider: $e');
        }
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
        backgroundColor: Colors.white, // Set white background
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
        backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
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
                  
                  // DISABLED PINCODE FIELD
                  _buildFormField(
                    controller: _pincodeController,
                    label: 'Pincode',
                    isRequired: true,
                    readOnly: true, // Disabled - can't be changed by user
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pincode is required';
                      }
                      if (value.length != 6) {
                        return 'Pincode must be 6 digits';
                      }
                      return null;
                    },
                    helperText: 'Pincode is based on your current location selection',
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
                  
                  // DISABLED CONTACT NUMBER FIELD
                  _buildFormField(
                    controller: _contactNumberController,
                    label: 'Contact Number for Order Delivery',
                    isRequired: true,
                    readOnly: true, // Disabled - can't be changed by user
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Contact number is required';
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
                    helperText: 'Contact number is taken from your current login profile',
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
    String? helperText,
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
                  color: readOnly ? Colors.grey[500] : Colors.grey[700],
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(color: AppColors.error),
                ),
              if (readOnly)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.lock,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            readOnly: readOnly,
            style: TextStyle(
              color: readOnly ? Colors.grey[600] : Colors.black,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: readOnly ? Colors.grey[300]! : Colors.grey[400]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: readOnly ? Colors.grey[300]! : Colors.grey[400]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: readOnly ? Colors.grey[300]! : AppColors.primary,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixText: prefixText,
              filled: readOnly,
              fillColor: readOnly ? Colors.grey[100] : null,
              helperText: helperText,
              helperStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}