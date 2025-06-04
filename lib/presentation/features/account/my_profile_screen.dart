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
  final bool isAuthenticated; // Added to track authentication status

  ProfileEditState({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.mobileNumber = '',
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.isAuthenticated = true, // Default to true
  });

  ProfileEditState copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? mobileNumber,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool? isAuthenticated,
  }) {
    return ProfileEditState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  // Create from API response
  factory ProfileEditState.fromJson(Map<String, dynamic> json) {
    return ProfileEditState(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email_id'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      isAuthenticated: true,
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
    
    // Pre-fill controllers with empty values to prevent visual flicker
    _firstNameController.text = '';
    _lastNameController.text = '';
    _mobileController.text = '';
    _emailController.text = '';
    
    // Load user profile in the next frame after widgets are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  // Reliable authentication check
  Future<bool> _checkAuthentication() async {
    try {
      final authRepository = ref.read(authRepositoryProvider);
      return await authRepository.isLoggedIn();
    } catch (e) {
      ref.read(loggerProvider).error('Authentication check failed: $e');
      return false;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final logger = ref.read(loggerProvider);
      logger.log('Starting to load user profile');
      
      // Show loading state
      ref.read(profileEditingProvider.notifier).state = 
          ProfileEditState(isLoading: true, isAuthenticated: true);

      // First check if user is logged in directly
      final isLoggedIn = await _checkAuthentication();
      
      if (!isLoggedIn) {
        logger.log('User not logged in, redirecting to login');
        
        ref.read(profileEditingProvider.notifier).state = ProfileEditState(
          isLoading: false,
          isAuthenticated: false,
          errorMessage: 'User not logged in',
        );
        
        if (mounted) {
          context.go('/auth/login?redirectRoute=/profile');
        }
        return; // Important: stop execution here
      }
      
      // If we're still here, user is logged in
      logger.log('User is logged in, proceeding to load profile');
      
      // Get the current user profile from auth provider
      final userProfile = await ref.read(userProfileProvider.future);
      
      if (userProfile == null) {
        // This is an edge case - user is logged in but profile is null
        // This shouldn't normally happen, but let's handle it anyway
        logger.error('User logged in but profile is null - possible data issue');
        
        ref.read(profileEditingProvider.notifier).state = ProfileEditState(
          isLoading: false,
          isAuthenticated: true, // Keep as true since they are logged in
          errorMessage: 'Profile data unavailable, try again later',
        );
        return;
      }
      
      // We have a valid profile, proceed
      logger.log('User profile retrieved: ${userProfile.mobile}');
      
      // Store access key and mobile for API calls
      _accessKey = userProfile.accessKey;
      _mobileNumber = userProfile.mobile;
      
      // Initial update to form with mobile number
      _mobileController.text = userProfile.mobile;
      
      // Create base profile state with mobile number
      var profileState = ProfileEditState(
        mobileNumber: userProfile.mobile,
        isLoading: false,
        isAuthenticated: true,
      );
      
      // Fetch profile details from API if we have credentials
      if (_accessKey != null && _mobileNumber != null) {
        try {
          final profileRepository = ref.read(profileRepositoryProvider);
          logger.log('Fetching profile from API...');
          
          final profileData = await profileRepository.getUserProfile(
            _mobileNumber!,
            _accessKey!,
          );
          
          logger.log('Profile data received: $profileData');
          
          // Update state with API data if available
          if (profileData.isNotEmpty) {
            profileState = ProfileEditState.fromJson(profileData);
            logger.log('Profile data parsed successfully');
            
            // Update controllers with data from API
            _firstNameController.text = profileState.firstName;
            _lastNameController.text = profileState.lastName;
            _mobileController.text = profileState.mobileNumber.isNotEmpty 
                ? profileState.mobileNumber 
                : userProfile.mobile;
            _emailController.text = profileState.email;
          } else {
            logger.log('No profile data from API, using base state');
            // Keep the base profile state with mobile number
          }
        } catch (e) {
          logger.error('Error fetching profile from API: $e');
          // If profile fetch fails, still show the form with mobile number
          // Don't set error message for API failures - user can still update profile
        }
      }
      
      // Set the final state (either with API data or just mobile number)
      ref.read(profileEditingProvider.notifier).state = profileState;
      logger.log('Profile state set successfully');
      
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('Error loading user profile: $e');
      
      // For general errors, keep user on profile page if possible
      ref.read(profileEditingProvider.notifier).state = ProfileEditState(
        isLoading: false,
        isAuthenticated: true, // Assume authenticated until proven otherwise
        errorMessage: 'Failed to load profile data. Try again later.',
      );
    }
  }

  Future<void> _saveProfile() async {
    final logger = ref.read(loggerProvider);
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      logger.log('Form validation failed');
      return;
    }

    // Check if we have access key and mobile
    if (_accessKey == null || _mobileNumber == null) {
      logger.error('Missing authentication details for profile save');
      ref.read(profileEditingProvider.notifier).state = 
          ref.read(profileEditingProvider).copyWith(
            errorMessage: 'Missing authentication details',
          );
      return;
    }

    // Update state to loading
    ref.read(profileEditingProvider.notifier).state = 
        ref.read(profileEditingProvider).copyWith(
          isLoading: true,
          errorMessage: null, // Clear previous errors
        );

    try {
      logger.log('Saving profile data...');
      
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
        logger.log('Profile updated successfully');
        
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
            
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        logger.error('Profile update failed');
        
        // Update state with error
        ref.read(profileEditingProvider.notifier).state = 
            ref.read(profileEditingProvider).copyWith(
              isLoading: false,
              isSuccess: false,
              errorMessage: 'Failed to update profile',
            );
      }
    } catch (e) {
      logger.error('Error saving profile: $e');
      
      // Update state with error
      ref.read(profileEditingProvider.notifier).state = 
          ref.read(profileEditingProvider).copyWith(
            isLoading: false,
            isSuccess: false,
            errorMessage: 'Failed to update profile: ${e.toString()}',
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
      final logger = ref.read(loggerProvider);
      logger.log('Deleting user account...');
      
      // Show loading indicator
      ref.read(profileEditingProvider.notifier).state = 
          ref.read(profileEditingProvider).copyWith(isLoading: true);
      
      // For demo, simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Logout the user
      await ref.read(logoutProvider)();
      
      // Navigate to login screen
      if (mounted) {
        logger.log('Account deleted, navigating to login');
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
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : !profileState.isAuthenticated
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Please login to view your profile'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/auth/login?redirectRoute=/profile'),
                        child: Text('Login'),
                      ),
                    ],
                  ),
                )
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
                        
                        // Error message (only show if it's not an authentication error)
                        if (profileState.errorMessage != null && profileState.isAuthenticated)
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      profileState.errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
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