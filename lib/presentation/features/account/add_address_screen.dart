// lib/presentation/features/account/add_address_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/core/constants/app_colors.dart';
import 'package:patelmart/core/constants/app_text_styles.dart';
import 'package:patelmart/presentation/features/account/address_book_screen.dart' as address_book;
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/presentation/providers/address_provider.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import 'package:patelmart/utils/ascii_only_input_formatter.dart';
import 'package:patelmart/core/utils/input_formatters.dart';
import '../../../di/infrastructure_providers.dart';


class AddAddressScreen extends ConsumerStatefulWidget {
  final bool returnToCheckout;

  const AddAddressScreen({
    Key? key,
    this.returnToCheckout = false,
  }) : super(key: key);

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _wingFloorController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  
  bool _isLoading = false;
  bool _isDefault = false;
  String _errorMessage = '';
  
  // Variables to store coordinates
  String _latitude = '';
  String _longitude = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserDataAndPincode();
  }
  
  Future<void> _loadUserDataAndPincode() async {
    final logger = ref.read(loggerProvider);
    
    try {
      // Load user mobile number from auth provider with retry logic
      await _loadUserMobileWithRetry();
    } catch (e) {
      logger.error('Error loading user mobile number: $e');
    }
    
    try {
      // Load selected pincode from location provider
      final selectedPincode = ref.read(selectedPincodeProvider);
      if (selectedPincode != null && selectedPincode.isNotEmpty) {
        setState(() {
          _pincodeController.text = selectedPincode;
        });
        logger.log('Loaded selected pincode: $selectedPincode');
      } else {
        logger.warning('No pincode selected');
      }
    } catch (e) {
      logger.error('Error loading selected pincode: $e');
    }
  }

  /// Load user mobile number with retry logic to handle race conditions
  Future<void> _loadUserMobileWithRetry() async {
    final logger = ref.read(loggerProvider);
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 300);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        logger.log('Attempting to load user mobile number (attempt $attempt/$maxRetries)');
        
        // Try to get user profile
        final userProfile = await ref.read(userProfileProvider.future);
        
        if (userProfile != null && userProfile.mobile.isNotEmpty) {
          setState(() {
            _contactNumberController.text = userProfile.mobile;
          });
          logger.log('Successfully loaded user mobile number: ${userProfile.mobile}');
          return; // Success, exit retry loop
        } else {
          logger.warning('User profile is null or mobile is empty on attempt $attempt');
        }
      } catch (e) {
        logger.warning('Error loading user profile on attempt $attempt: $e');
      }
      
      // If not the last attempt, wait before retrying
      if (attempt < maxRetries) {
        logger.log('Waiting ${retryDelay.inMilliseconds}ms before retry...');
        await Future.delayed(retryDelay);
        
        // Invalidate the provider to force a fresh fetch
        ref.invalidate(userProfileProvider);
      }
    }
    
      // If all retries failed, try direct access to auth manager
      try {
        logger.log('All retries failed, trying direct auth manager access...');
        final authManager = ref.read(centralizedAuthManagerProvider);
        final userProfile = await authManager.getCurrentUserProfile();
      
      if (userProfile != null && userProfile.mobile.isNotEmpty) {
        setState(() {
          _contactNumberController.text = userProfile.mobile;
        });
        logger.log('Successfully loaded user mobile via direct auth manager: ${userProfile.mobile}');
      } else {
        logger.error('Could not load user mobile number after all attempts');
      }
    } catch (e) {
      logger.error('Error accessing auth manager directly: $e');
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

  /// Creates ASCII-only input formatter with dialog notification
  List<TextInputFormatter> _getAsciiOnlyFormatters() {
    return [
      NoEmojiInputFormatter(),
      AsciiOnlyInputFormatter(
        onBlocked: () {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text(
                  'Use English keyboard',
                  style: TextStyle(color: Colors.black),
                ),
                content: const Text(
                  'System accepts English text only',
                  style: TextStyle(color: Colors.black),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
      ),
    ];
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

  Future<void> _useCurrentLocation() async {
    final logger = ref.read(loggerProvider);
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      logger.log('Getting current location...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      logger.log('Location: ${position.latitude}, ${position.longitude}');
      
      // Save coordinates for later use
      setState(() {
        _latitude = position.latitude.toString();
        _longitude = position.longitude.toString();
      });
      
      // Get address from location coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        logger.log('Placemark: ${place.name}, ${place.locality}, ${place.postalCode}');
        
        setState(() {
          _areaController.text = place.subLocality ?? '';
          _localityController.text = place.street ?? '';
          // Don't update pincode from location as it's disabled
          _cityController.text = place.locality ?? '';
          _stateController.text = place.administrativeArea ?? '';
        });
      }
    } catch (e) {
      logger.error('Error getting location: $e');
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Updated save method using centralized access key management
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final logger = ref.read(loggerProvider);
    logger.log('Saving address - Return to checkout: ${widget.returnToCheckout}');
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Attempt to get coordinates if we don't have them yet
      if (_latitude.isEmpty || _longitude.isEmpty) {
        await _getCoordinatesFromAddress();
      }
      
      // Format mobile number (remove prefix if present)
      String mobileNumber = _contactNumberController.text;
      if (mobileNumber.startsWith('+91 | ')) {
        mobileNumber = mobileNumber.replaceAll('+91 | ', '');
      }
      
      // Create address model
      final newAddress = Address(
        id: '', // Will be set by backend
        fullName: _fullNameController.text.trim(),
        mobileNumber: mobileNumber.trim(),
        emailId: '', // Using empty email as per existing pattern
        deliveryAddrLine1: _wingFloorController.text.trim(),
        deliveryAddrLine2: _localityController.text.trim(),
        deliveryAddrCity: _cityController.text.trim(),
        deliveryAddrPincode: _pincodeController.text.trim(),
        isDefault: _isDefault ? "Yes" : "No",
        latitude: _latitude.isNotEmpty ? _latitude : null,
        longitude: _longitude.isNotEmpty ? _longitude : null,
        areaId: _areaController.text.isEmpty ? "1" : _areaController.text.trim(),
      );
      
      logger.log('Saving address: ${newAddress.toString()}');
      
      // Use the repository to add the address
      final addressOperations = ref.read(addressOperationsProvider);
      final success = await addressOperations.addAddress(newAddress);
      
      if (success) {
        // Address saved successfully
        logger.log('Address added successfully');
        
        // **** CRITICAL FIX: Trigger address refresh ****
        // This ensures the checkout flow sees the new address immediately
        try {
          // 1. Trigger refresh counter increment (if exists)
          try {
            ref.read(addressRefreshProvider.notifier).state++;
          } catch (e) {
            logger.warning('addressRefreshProvider not found, skipping: $e');
          }
          
          // 2. Refresh the address list provider (used by checkout flow)
          ref.refresh(address_book.addressListProvider);
          
          // 3. Refresh the main address providers
          try {
            ref.refresh(addressesProvider);
            ref.refresh(directAddressListProvider);
          } catch (e) {
            logger.warning('Some address providers not found, skipping: $e');
          }
          
          logger.log('Address providers refreshed successfully');
        } catch (e) {
          logger.error('Error refreshing address providers: $e');
          // Continue even if refresh fails
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Small delay to ensure providers are refreshed before navigation
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Navigate based on where we came from
          if (widget.returnToCheckout) {
            logger.log('Navigating back to checkout flow');
            context.go('/checkout-flow');
          } else {
            logger.log('Navigating back to address book');
            context.go('/address-book');
          }
        }
      } else {
        // Failed to add address
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to add address. Please try again.';
        });
      }
    } catch (e) {
      logger.error('Error in save address: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error saving address: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set white background
      appBar: AppBar(
        title: const Text('Add New Address'),
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
                  // Show context message if coming from checkout
                  if (widget.returnToCheckout)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add your delivery address to continue with checkout',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  // Use current location button
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('USE CURRENT LOCATION'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  
                  // OR divider
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('OR'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  
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
                    inputFormatters: _getAsciiOnlyFormatters(),
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
                    helperText: 'Pincode is pre-selected based on your location selection',
                  ),
                  
                  _buildFormField(
                    controller: _areaController,
                    label: 'Area',
                    isRequired: true,
                    inputFormatters: _getAsciiOnlyFormatters(),
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
                    inputFormatters: _getAsciiOnlyFormatters(),
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
                    inputFormatters: _getAsciiOnlyFormatters(),
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
                    inputFormatters: _getAsciiOnlyFormatters(),
                  ),
                  
                  _buildFormField(
                    controller: _cityController,
                    label: 'City',
                    isRequired: true,
                    inputFormatters: _getAsciiOnlyFormatters(),
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
                    inputFormatters: _getAsciiOnlyFormatters(),
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
                    helperText: 'Contact number is taken from your login profile',
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
                        const Text('Set as default'),
                      ],
                    ),
                  ),
                  
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE ADDRESS'),
                    ),
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
    List<TextInputFormatter>? inputFormatters,
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
            inputFormatters: inputFormatters,
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