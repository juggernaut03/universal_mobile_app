// lib/presentation/features/account/my_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../data/models/auth_models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/launch_flow_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider to store profile editing state
final profileEditingProvider = StateProvider.autoDispose<ProfileEditState>((ref) {
  return ProfileEditState();
});

// Extension for UserProfile to add profile fields
extension UserProfileExtension on UserProfile {
  String? get firstName => null; // These would normally be part of your UserProfile model
  String? get lastName => null;  // For this example, we're returning null as defaults
  String? get email => null;     // In a real app, these would be actual fields
}

// State class for profile editing form
class ProfileEditState {
  final String firstName;
  final String lastName;
  final String email;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  ProfileEditState({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ProfileEditState copyWith({
    String? firstName,
    String? lastName,
    String? email,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileEditState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

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
      // Get the current user profile
      final userProfile = await ref.read(userProfileProvider.future);
      
      if (userProfile != null) {
        _mobileController.text = userProfile.mobile;
        
        // If we have additional profile data, we would load it here
        // For now, just initialize the state
        ref.read(profileEditingProvider.notifier).state = ProfileEditState(
          firstName: userProfile.firstName ?? '',
          lastName: userProfile.lastName ?? '',
          email: userProfile.email ?? '',
        );

        // Set controllers from the state
        _firstNameController.text = userProfile.firstName ?? '';
        _lastNameController.text = userProfile.lastName ?? '';
        _emailController.text = userProfile.email ?? '';
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error loading user profile: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profile information'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Update state to loading
    ref.read(profileEditingProvider.notifier).state = 
        ref.read(profileEditingProvider).copyWith(isLoading: true);

    try {
      // Get the current profile data
      final currentState = ref.read(profileEditingProvider);
      
      // In a real app, you would call your repository here to update the profile
      // For this example, we'll simulate a successful update
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Update the success message in the state
      ref.read(profileEditingProvider.notifier).state = currentState.copyWith(
        isLoading: false,
        successMessage: 'Profile updated successfully',
      );
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      
      // In a real app, we would update the user profile in a repository
      // await ref.read(authRepositoryProvider).updateUserProfile(
      //   firstName: _firstNameController.text,
      //   lastName: _lastNameController.text,
      //   email: _emailController.text,
      // );
      
    } catch (e) {
      ref.read(loggerProvider).error('Error saving profile: $e');
      
      // Update state with error
      ref.read(profileEditingProvider.notifier).state = 
          ref.read(profileEditingProvider).copyWith(
            isLoading: false,
            errorMessage: 'Failed to save profile: ${e.toString()}',
          );
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
              foregroundColor: AppColors.error,
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
      
      // In a real app, call repository to delete account
      // await ref.read(authRepositoryProvider).deleteAccount();
      
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
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete account'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
    
    return BackButtonWrapper(
      alternateRoute: '/account',
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('My Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/account'),
          ),
        ),
        body: SafeArea(
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
                  onChanged: (value) {
                    ref.read(profileEditingProvider.notifier).state = 
                        profileState.copyWith(firstName: value);
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
                  onChanged: (value) {
                    ref.read(profileEditingProvider.notifier).state = 
                        profileState.copyWith(lastName: value);
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
                      borderSide: const BorderSide(color: AppColors.neutral400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.neutral700, // Slightly dimmed text for disabled
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
                  onChanged: (value) {
                    ref.read(profileEditingProvider.notifier).state = 
                        profileState.copyWith(email: value);
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
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
                      foregroundColor: AppColors.error,
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
              ],
            ),
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
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.error,
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
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.neutral400),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
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