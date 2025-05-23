// lib/presentation/features/account/my_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/launch_flow_provider.dart';

// Provider for the profile repository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  return ProfileRepository(
    client: http.Client(),
    logger: logger,
  );
});

// State class for profile editing form
class ProfileEditState {
  final String firstName;
  final String lastName;
  final String email;
  final String mobileNumber;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  ProfileEditState({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.mobileNumber = '',
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  ProfileEditState copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? mobileNumber,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return ProfileEditState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  // Create from API response
  factory ProfileEditState.fromJson(Map<String, dynamic> json) {
    return ProfileEditState(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email_id'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
    );
  }
}

// Provider to store profile editing state
final profileEditingProvider = StateProvider.autoDispose<ProfileEditState>((ref) {
  return ProfileEditState();
});

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  String? _accessKey;
  String? _mobileNumber;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    
    // Load user profile in the next frame after widgets are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      // Show loading state
      ref.read(profileEditingProvider.notifier).state = 
          ProfileEditState(isLoading: true);

      // Get the current user profile from auth provider
      final userProfile = await ref.read(userProfileProvider.future);
      
      if (userProfile != null) {
        // Store access key and mobile for API calls
        _accessKey = userProfile.accessKey;
        _mobileNumber = userProfile.mobile;
        
        // Initial update to form with mobile number
        _mobileController.text = userProfile.mobile;
        
        // Fetch profile details from API
        if (_accessKey != null && _mobileNumber != null) {
          final profileRepository = ref.read(profileRepositoryProvider);
          try {
            final profileData = await profileRepository.getUserProfile(
              _mobileNumber!,
              _accessKey!,
            );
            
            // Update state with API data
            if (profileData.isNotEmpty) {
              final profileState = ProfileEditState.fromJson(profileData);
              ref.read(profileEditingProvider.notifier).state = profileState;
              
              // Update controllers with data from API
              _firstNameController.text = profileState.firstName;
              _lastNameController.text = profileState.lastName;
              _mobileController.text = profileState.mobileNumber;
              _emailController.text = profileState.email;
            } else {
              // No profile data from API, set mobile number only
              ref.read(profileEditingProvider.notifier).state = ProfileEditState(
                mobileNumber: userProfile.mobile,
                isLoading: false,
              );
            }
          } catch (e) {
            // If profile fetch fails, still allow user to update with what we have
            ref.read(profileEditingProvider.notifier).state = ProfileEditState(
              mobileNumber: userProfile.mobile,
              isLoading: false,
            );
          }
        } else {
          // No access key or mobile, show error
          ref.read(profileEditingProvider.notifier).state = ProfileEditState(
            errorMessage: 'Unable to fetch profile: Missing authentication details',
            isLoading: false,
          );
        }
      } else {
        // No user profile, update state with error
        ref.read(profileEditingProvider.notifier).state = ProfileEditState(
          errorMessage: 'Unable to fetch profile: User not logged in',
          isLoading: false,
        );
        
        if (mounted) {
          // Navigate to login screen
          context.go('/auth/login?redirectRoute=/profile');
        }
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error loading user profile: $e');
      
      // Update state with error
      ref.read(profileEditingProvider.notifier).state = ProfileEditState(
        errorMessage: 'Failed to load profile',
        isLoading: false,
      );
    }
  }

  Future<void> _saveProfile() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if we have access key and mobile
    if (_accessKey == null || _mobileNumber == null) {
      setState(() {
        ref.read(profileEditingProvider.notifier).state = 
            ref.read(profileEditingProvider).copyWith(
              errorMessage: 'Missing authentication details',
            );
      });
      return;
    }

    // Update state to loading
    ref.read(profileEditingProvider.notifier).state = 
        ref.read(profileEditingProvider).copyWith(
          isLoading: true,
          errorMessage: null, // Clear previous errors
        );

    try {
      // Get profile repository
      final profileRepository = ref.read(profileRepositoryProvider);
      
      // Call API to update profile
      final success = await profileRepository.updateUserProfile(
        accessKey: _accessKey!,
        mobileNumber: _mobileNumber!,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        emailId: _emailController.text.isNotEmpty ? _emailController.text : null,
      );
      
      if (success) {
        // Update the state with success
        ref.read(profileEditingProvider.notifier).state = 
            ref.read(profileEditingProvider).copyWith(
              isLoading: false,
              isSuccess: true,
              errorMessage: null,
              firstName: _firstNameController.text,
              lastName: _lastNameController.text,
              email: _emailController.text,
            );
      } else {
        // Update state with error
        ref.read(profileEditingProvider.notifier).state = 
            ref.read(profileEditingProvider).copyWith(
              isLoading: false,
              isSuccess: false,
              errorMessage: 'Failed to update profile',
            );
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error saving profile: $e');
      
      // Update state with error
      ref.read(profileEditingProvider.notifier).state = 
          ref.read(profileEditingProvider).copyWith(
            isLoading: false,
            isSuccess: false,
            errorMessage: 'Failed to update profile',
          );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      // Show loading indicator
      ref.read(profileEditingProvider.notifier).state = 
          ref.read(profileEditingProvider).copyWith(isLoading: true);
      
      // For demo, simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Logout the user
      await ref.read(logoutProvider)();
      
      // Navigate to login screen
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error deleting account: $e');
      
      // Update state with error
      ref.read(profileEditingProvider.notifier).state = 
          ref.read(profileEditingProvider).copyWith(
            isLoading: false, 
            errorMessage: 'Failed to delete account',
          );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileEditingProvider);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF77318B), // Purple color from screenshot
        foregroundColor: Colors.white,
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/account'),
        ),
      ),
      body: profileState.isLoading && _firstNameController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // First Name
                    _buildFormLabel('First Name', true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _firstNameController,
                      focusNode: _firstNameFocus,
                      hintText: 'Enter your first name',
                      nextFocus: _lastNameFocus,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Last Name
                    _buildFormLabel('Last Name', true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _lastNameController,
                      focusNode: _lastNameFocus,
                      hintText: 'Enter your last name',
                      nextFocus: _emailFocus,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Mobile Number (disabled)
                    _buildFormLabel('Your Mobile Number', true),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mobileController,
                      enabled: false, // Disabled since users can't change their mobile number
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[200],
                        hintText: 'Your mobile number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Email (optional)
                    _buildFormLabel('Your Email Id (optional)', false),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      hintText: 'Enter your email address',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          // Simple email validation
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: profileState.isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF77318B), // Purple color from screenshot
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: profileState.isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Text('SAVE CHANGES'),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Delete Account
                    Center(
                      child: TextButton(
                        onPressed: profileState.isLoading ? null : _confirmDeleteAccount,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Delete My Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    // Error message
                    if (profileState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profileState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFormLabel(String label, bool isRequired) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    FocusNode? nextFocus,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF77318B), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
    );
  }
}