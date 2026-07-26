// lib/presentation/providers/profile_edit_providers.dart
//
// Profile-editing UI state, moved out of my_profile_screen.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final profileEditingProvider = StateProvider.autoDispose<ProfileEditState>((ref) {
  return ProfileEditState();
});
