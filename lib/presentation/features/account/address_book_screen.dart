// lib/presentation/features/account/address_book_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/presentation/features/account/my_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/error_widgets.dart';
import '../../providers/auth_providers.dart';
import '../../providers/launch_flow_provider.dart';

// Model class for an address
class Address {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String emailId;
  final String deliveryAddrLine1; // Wing/Floor/Flat/House No.
  final String deliveryAddrLine2; // Locality/Street
  final String deliveryAddrCity;
  final String deliveryAddrPincode;
  final String isDefault;
  final String areaId;
  final String landmark;
  final String state;
  final String latitude;
  final String longitude;

  Address({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.emailId,
    required this.deliveryAddrLine1,
    required this.deliveryAddrLine2,
    required this.deliveryAddrCity,
    required this.deliveryAddrPincode,
    required this.isDefault,
    required this.areaId,
    this.landmark = '',
    this.state = '',
    this.latitude = '',
    this.longitude = '',
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['_id'] ?? '',
      fullName: json['full_name'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      emailId: json['email_id'] ?? '',
      deliveryAddrLine1: json['delivery_addr_line_1'] ?? '',
      deliveryAddrLine2: json['delivery_addr_line_2'] ?? '',
      deliveryAddrCity: json['delivery_addr_city'] ?? '',
      deliveryAddrPincode: json['delivery_addr_pincode'] ?? '',
      isDefault: json['is_default'] ?? 'No',
      areaId: json['area_id'] ?? '1',
      landmark: json['landmark'] ?? '',
      state: json['state'] ?? '',
      latitude: json['latitude'] ?? '',
      longitude: json['longitude'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idaddress_book': id == '' ? '1' : id, // Use '1' as default when creating new
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'email_id': emailId,
      'delivery_addr_line_1': deliveryAddrLine1,
      'delivery_addr_line_2': deliveryAddrLine2,
      'delivery_addr_city': deliveryAddrCity,
      'delivery_addr_pincode': deliveryAddrPincode,
      'is_default': isDefault,
      'area_id': areaId,
      'landmark': landmark,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Address copyWith({
    String? id,
    String? fullName,
    String? mobileNumber,
    String? emailId,
    String? deliveryAddrLine1,
    String? deliveryAddrLine2,
    String? deliveryAddrCity,
    String? deliveryAddrPincode,
    String? isDefault,
    String? areaId,
    String? landmark,
    String? state,
    String? latitude,
    String? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      emailId: emailId ?? this.emailId,
      deliveryAddrLine1: deliveryAddrLine1 ?? this.deliveryAddrLine1,
      deliveryAddrLine2: deliveryAddrLine2 ?? this.deliveryAddrLine2,
      deliveryAddrCity: deliveryAddrCity ?? this.deliveryAddrCity,
      deliveryAddrPincode: deliveryAddrPincode ?? this.deliveryAddrPincode,
      isDefault: isDefault ?? this.isDefault,
      areaId: areaId ?? this.areaId,
      landmark: landmark ?? this.landmark,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

// Provider for the list of addresses
final addressesProvider = FutureProvider.autoDispose<List<Address>>((ref) async {
  try {
    // Get mobile number from user profile
    final userProfile = await ref.read(userProfileProvider.future);
    if (userProfile == null) {
      throw Exception('User not logged in');
    }

    final mobileNumber = userProfile.mobile;
    final addresses = await fetchAddresses(mobileNumber);
    return addresses;
  } catch (e) {
    ref.read(loggerProvider).error('Error fetching addresses: $e');
    rethrow;
  }
});

// Function to fetch addresses from API
Future<List<Address>> fetchAddresses(String mobileNumber) async {
  final response = await http.post(
    Uri.parse('${ApiConstants.baseUrl}/get_address_list'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'mobile_number': mobileNumber,
      'project_code': ApiConstants.projectCode,
    }),
  );

  if (response.statusCode == 200) {
    List<dynamic> addressesJson = json.decode(response.body);
    return addressesJson.map((json) => Address.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load addresses');
  }
}

// Function to add new address
Future<Address> addAddress(Address address) async {
  final response = await http.post(
    Uri.parse('${ApiConstants.baseUrl}/add_address'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      ...address.toJson(),
      'project_code': ApiConstants.projectCode,
    }),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    final responseData = json.decode(response.body);
    if (responseData['insertedItems'] != null && 
        responseData['insertedItems'].isNotEmpty) {
      return Address.fromJson(responseData['insertedItems'][0]);
    } else {
      throw Exception('No address data returned from API');
    }
  } else {
    throw Exception('Failed to add address: ${response.body}');
  }
}

// Function to update existing address
Future<Address> updateAddress(Address address) async {
  final response = await http.post(
    Uri.parse('${ApiConstants.baseUrl}/add_address'), // Using same endpoint for update
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      ...address.toJson(),
      'project_code': ApiConstants.projectCode,
    }),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    final responseData = json.decode(response.body);
    if (responseData['message'] != null && 
        responseData['message'].contains('Successfully')) {
      // Return updated address
      return address;
    } else {
      throw Exception('Failed to update address: ${response.body}');
    }
  } else {
    throw Exception('Failed to update address: ${response.body}');
  }
}

// Function to get latitude and longitude from address using Google Maps API
Future<Map<String, double>> getLatLngFromAddress(String address) async {
  try {
    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=${ApiConstants.googleApiKey}';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        return {
          'latitude': location['lat'],
          'longitude': location['lng'],
        };
      } else {
        throw Exception('No location data found: ${data['status']}');
      }
    } else {
      throw Exception('Failed to geocode address: ${response.statusCode}');
    }
  } catch (e) {
    print('Error geocoding address: $e');
    // Return default coordinates (0,0) if geocoding fails
    return {'latitude': 0.0, 'longitude': 0.0};
  }
}

// Main Address Book Screen
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsyncValue = ref.watch(addressesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Book'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/account'),  // Use go instead of pop
        ),
      ),
      body: SafeArea(
        child: addressesAsyncValue.when(
          data: (addresses) {
            return _buildAddressList(context, ref, addresses);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorWidget(
            errorType: ErrorType.network,
            message: 'Failed to load addresses: $error',
            onRetry: () => ref.refresh(addressesProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressList(BuildContext context, WidgetRef ref, List<Address> addresses) {
    return Column(
      children: [
        Expanded(
          child: addresses.isEmpty
              ? Center(
                  child: Text(
                    'No addresses found',
                    style: AppTextStyles.bodyLarge,
                  ),
                )
              : ListView.builder(
                  itemCount: addresses.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return _buildAddressCard(context, ref, address);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildAddNewAddressButton(context),
        ),
      ],
    );
  }

  Widget _buildAddressCard(BuildContext context, WidgetRef ref, Address address) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.fullName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (address.isDefault == 'Yes')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Primary',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${address.deliveryAddrLine1}, ${address.deliveryAddrLine2}, ${address.deliveryAddrCity} - ${address.deliveryAddrPincode}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 4),
            if (address.landmark.isNotEmpty)
              Text(
                'Landmark: ${address.landmark}',
                style: AppTextStyles.bodyMedium,
              ),
            const SizedBox(height: 4),
            Text(
              'Mob No: ${address.mobileNumber}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _navigateToEditAddress(context, address);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                    ),
                    child: const Text('EDIT'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _showDeleteConfirmation(context, ref, address);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('DELETE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewAddressButton(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push('/add-address');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.secondary,
            width: 1,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(
              'ADD NEW ADDRESS',
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditAddress(BuildContext context, Address address) {
    // Store the address in shared preferences for the edit screen to access
    _saveAddressForEditing(address);
    context.push('/edit-address');
  }
  
  // Helper method to save address for editing
  Future<void> _saveAddressForEditing(Address address) async {
    final prefs = await SharedPreferences.getInstance();
    final addressJson = jsonEncode(address.toJson());
    await prefs.setString('address_to_edit', addressJson);
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Address address) {
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
              // Mock delete functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Address deleted successfully'),
                ),
              );
              // Refresh addresses list
              ref.refresh(addressesProvider);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

// Add New Address Screen
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
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserMobileNumber();
  }
  
  Future<void> _loadUserMobileNumber() async {
    try {
      final userProfile = await ref.read(userProfileProvider.future);
      if (userProfile != null) {
        setState(() {
          _contactNumberController.text = userProfile.mobile;
        });
      }
    } catch (e) {
      print('Error loading user mobile number: $e');
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

  Future<void> _useCurrentLocation() async {
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      // Get address from location coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        
        setState(() {
          _areaController.text = place.subLocality ?? '';
          _localityController.text = place.street ?? '';
          _pincodeController.text = place.postalCode ?? '';
          _cityController.text = place.locality ?? '';
          _stateController.text = place.administrativeArea ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Construct full address string for geocoding
      final fullAddress = '${_wingFloorController.text}, ${_localityController.text}, ${_cityController.text}, ${_stateController.text}, ${_pincodeController.text}';
      
      // Get latitude and longitude from address
      final coords = await getLatLngFromAddress(fullAddress);
      
      // Get user email from profile (or use empty string)
      String email = '';
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        email = userProfile?.email ?? '';
      } catch (e) {
        // Use empty email if profile can't be loaded
      }
      
      // Create address object
      final address = Address(
        id: '', // Empty for new address
        fullName: _fullNameController.text,
        mobileNumber: _contactNumberController.text.replaceAll('+91 | ', ''),
        emailId: email,
        deliveryAddrLine1: _wingFloorController.text,
        deliveryAddrLine2: _localityController.text,
        deliveryAddrCity: _cityController.text,
        deliveryAddrPincode: _pincodeController.text,
        isDefault: 'Yes', // Set as default for simplicity
        areaId: '1', // Default area ID
        landmark: _landmarkController.text,
        state: _stateController.text,
        latitude: coords['latitude'].toString(),
        longitude: coords['longitude'].toString(),
      );
      
      // Save address to API
      await addAddress(address);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate based on where we came from
        if (widget.returnToCheckout) {
          context.go('/checkout-flow');
        } else {
          context.go('/address-book');
        }
        
        // Refresh address list
        ref.refresh(addressesProvider);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving address: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add new address'),
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
                  // Use current location button
                  OutlinedButton(
                    onPressed: _isLoading ? null : _useCurrentLocation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: BorderSide(color: AppColors.secondary),
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.green[50],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('USE CURRENT LOCATION'),
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
                    readOnly: true, // Pre-filled and read-only
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter contact number';
                      }
                      return null;
                    },
                    prefixText: '+91 | ',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Save button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SAVE TO ADDRESS BOOK'),
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

// Edit Address Screen
class EditAddressScreen extends ConsumerStatefulWidget {
  final Address address;
  final bool returnToCheckout;
  
  const EditAddressScreen({
    Key? key,
    required this.address,
    this.returnToCheckout = false,
  }) : super(key: key);

  @override
  ConsumerState<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends ConsumerState<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _pincodeController;
  late TextEditingController _areaController;
  late TextEditingController _localityController;
  late TextEditingController _wingFloorController;
  late TextEditingController _landmarkController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _contactNumberController;
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing address data
    _fullNameController = TextEditingController(text: widget.address.fullName);
    _pincodeController = TextEditingController(text: widget.address.deliveryAddrPincode);
    _areaController = TextEditingController(text: widget.address.areaId); // Using areaId as area
    _localityController = TextEditingController(text: widget.address.deliveryAddrLine2);
    _wingFloorController = TextEditingController(text: widget.address.deliveryAddrLine1);
    _landmarkController = TextEditingController(text: widget.address.landmark);
    _cityController = TextEditingController(text: widget.address.deliveryAddrCity);
    _stateController = TextEditingController(text: widget.address.state);
    _contactNumberController = TextEditingController(text: widget.address.mobileNumber);
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
  
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Construct full address string for geocoding
      final fullAddress = '${_wingFloorController.text}, ${_localityController.text}, ${_cityController.text}, ${_stateController.text}, ${_pincodeController.text}';
      
      // Get latitude and longitude from address
      final coords = await getLatLngFromAddress(fullAddress);
      
      // Create updated address object
      final updatedAddress = widget.address.copyWith(
        fullName: _fullNameController.text,
        mobileNumber: _contactNumberController.text.replaceAll('+91 | ', ''),
        deliveryAddrLine1: _wingFloorController.text,
        deliveryAddrLine2: _localityController.text,
        deliveryAddrCity: _cityController.text,
        deliveryAddrPincode: _pincodeController.text,
        landmark: _landmarkController.text,
        state: _stateController.text,
        latitude: coords['latitude'].toString(),
        longitude: coords['longitude'].toString(),
      );
      
      // Update address
      await updateAddress(updatedAddress);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate based on where we came from
        if (widget.returnToCheckout) {
          context.go('/checkout-flow');
        } else {
          context.go('/address-book');
        }
        
        // Refresh address list
        ref.refresh(addressesProvider);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating address: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  // Area dropdown (shown as a disabled text field for simplicity)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.address.deliveryAddrCity,
                          style: AppTextStyles.bodyLarge,
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
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
                    readOnly: true, // Pre-filled and read-only
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter contact number';
                      }
                      return null;
                    },
                    prefixText: '+91 | ',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Save button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SAVE CHANGES'),
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