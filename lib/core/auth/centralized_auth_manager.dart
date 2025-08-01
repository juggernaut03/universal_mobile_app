// lib/core/auth/centralized_auth_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../../data/models/auth_models.dart';

/// Centralized authentication manager for access key and user data
class CentralizedAuthManager {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final Logger _logger;
  
  // Cache to avoid repeated secure storage reads
  UserProfile? _cachedProfile;
  DateTime? _lastValidation;
  Timer? _validationTimer;
  
  // Stream controllers for reactive updates
  final StreamController<UserProfile?> _profileController = StreamController<UserProfile?>.broadcast();
  final StreamController<bool> _loginStatusController = StreamController<bool>.broadcast();
  
  static const Duration _validationInterval = Duration(minutes: 5);
  static const Duration _accessKeyExpiry = Duration(days: 10);
  
  // Storage keys
  static const String _userProfileKey = 'user_profile_v2';
  static const String _loginTimeKey = 'login_time_v2';
  static const String _accessKeyKey = 'access_key_v2';
  
  CentralizedAuthManager({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
    required Logger logger,
  }) : _secureStorage = secureStorage,
       _prefs = prefs,
       _logger = logger {
    _initializeManager();
  }

  // Streams for reactive updates
  Stream<UserProfile?> get profileStream => _profileController.stream;
  Stream<bool> get loginStatusStream => _loginStatusController.stream;

  /// Initialize the manager and load cached data
  Future<void> _initializeManager() async {
    try {
      await _migrateLegacyStorage();
      await _loadCachedProfile();
      _startPeriodicValidation();
      _logger.log('CentralizedAuthManager initialized');
    } catch (e) {
      _logger.error('Error initializing auth manager: $e');
    }
  }

  /// Migrate legacy storage to centralized format
  Future<void> _migrateLegacyStorage() async {
    try {
      _logger.log('Checking for legacy storage to migrate...');
      
      // Check if new format already exists
      final existingProfile = await _secureStorage.read(key: _userProfileKey);
      if (existingProfile != null) {
        _logger.log('New format already exists, skipping migration');
        return;
      }
      
      // Try to migrate from legacy AuthService format
      String? legacyAccessKey;
      String? legacyLoginTime;
      String? legacyUserProfile;
      
      try {
        legacyAccessKey = await _secureStorage.read(key: 'user_access_key');
        legacyLoginTime = await _secureStorage.read(key: 'login_time');
        legacyUserProfile = await _secureStorage.read(key: 'user_profile');
      } catch (e) {
        _logger.warning('Error reading legacy secure storage: $e');
      }
      
      // Try to migrate from SharedPreferences
      String? mobile;
      String? accessKey = legacyAccessKey;
      DateTime? loginTime;
      
      if (legacyLoginTime != null) {
        try {
          loginTime = DateTime.parse(legacyLoginTime);
        } catch (e) {
          _logger.warning('Error parsing legacy login time: $e');
        }
      }
      
      // Try to extract from legacy user profile
      if (legacyUserProfile != null) {
        try {
          final parts = legacyUserProfile.split(':');
          if (parts.length >= 3) {
            mobile = parts[0];
            accessKey = parts[1];
            loginTime = DateTime.parse(parts[2]);
          }
        } catch (e) {
          _logger.warning('Error parsing legacy user profile: $e');
        }
      }
      
      // Try SharedPreferences as fallback
      if (accessKey == null || mobile == null) {
        try {
          final userProfileStr = _prefs.getString('user_profile');
          if (userProfileStr != null) {
            final userProfileData = jsonDecode(userProfileStr);
            if (userProfileData is Map) {
              mobile ??= userProfileData['mobile']?.toString();
              accessKey ??= userProfileData['accessKey']?.toString();
            }
          }
          
          // Try OTP validation response
          if (accessKey == null) {
            final otpResponseStr = _prefs.getString('otp_validation_response');
            if (otpResponseStr != null) {
              final otpResponseData = jsonDecode(otpResponseStr);
              if (otpResponseData is Map) {
                accessKey = otpResponseData['access_key']?.toString();
              }
            }
          }
          
          // Try direct access key
          accessKey ??= _prefs.getString('user_access_key');
        } catch (e) {
          _logger.warning('Error reading legacy SharedPreferences: $e');
        }
      }
      
      // If we have enough data, migrate to new format
      if (mobile != null && accessKey != null && mobile.isNotEmpty && accessKey.isNotEmpty) {
        final profile = UserProfile(
          mobile: mobile,
          accessKey: accessKey,
          loginTime: loginTime ?? DateTime.now(),
        );
        
        await saveUserProfile(profile);
        
        _logger.log('Successfully migrated legacy storage for mobile: $mobile');
        
        // Clean up legacy storage
        await _cleanupLegacyStorage();
      } else {
        _logger.log('No valid legacy data found to migrate');
      }
      
    } catch (e) {
      _logger.error('Error migrating legacy storage: $e');
    }
  }

  /// Clean up legacy storage keys
  Future<void> _cleanupLegacyStorage() async {
    try {
      _logger.log('Cleaning up legacy storage...');
      
      // Clean up legacy secure storage
      await _secureStorage.delete(key: 'user_access_key');
      await _secureStorage.delete(key: 'login_time');
      await _secureStorage.delete(key: 'user_profile');
      
      // Clean up legacy SharedPreferences
      await _prefs.remove('user_profile');
      await _prefs.remove('otp_validation_response');
      await _prefs.remove('user_access_key');
      
      _logger.log('Legacy storage cleanup completed');
    } catch (e) {
      _logger.error('Error cleaning up legacy storage: $e');
    }
  }

  /// Load cached profile from secure storage
  Future<void> _loadCachedProfile() async {
    try {
      final profileData = await _secureStorage.read(key: _userProfileKey);
      if (profileData != null) {
        final profile = UserProfile.fromJson(jsonDecode(profileData));
        
        // Validate if still valid
        if (_isProfileValid(profile)) {
          _cachedProfile = profile;
          _lastValidation = DateTime.now();
          _notifyProfileChanged(profile);
          _notifyLoginStatusChanged(true);
        } else {
          await _clearExpiredProfile();
        }
      }
    } catch (e) {
      _logger.error('Error loading cached profile: $e');
      await _clearExpiredProfile();
    }
  }

  /// Check if profile is still valid
  bool _isProfileValid(UserProfile profile) {
    final now = DateTime.now();
    final daysSinceLogin = now.difference(profile.loginTime).inDays;
    return daysSinceLogin < _accessKeyExpiry.inDays;
  }

  /// Save user profile after successful login
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      // Save to secure storage
      await _secureStorage.write(
        key: _userProfileKey,
        value: jsonEncode(profile.toJson()),
      );
      
      // Cache in memory
      _cachedProfile = profile;
      _lastValidation = DateTime.now();
      
      // Notify listeners immediately - this ensures reactive UI updates
      _notifyProfileChanged(profile);
      _notifyLoginStatusChanged(true);
      
      // Force a small delay to ensure all listeners are updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      _logger.log('User profile saved and streams updated: ${profile.mobile}');
    } catch (e) {
      _logger.error('Error saving user profile: $e');
      rethrow;
    }
  }

  /// Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      // Return cached if recently validated
      if (_cachedProfile != null && _isRecentlyValidated()) {
        return _cachedProfile;
      }
      
      // Reload from storage if cache is stale
      await _loadCachedProfile();
      return _cachedProfile;
    } catch (e) {
      _logger.error('Error getting current user profile: $e');
      return null;
    }
  }

  /// Get valid access key
  Future<String?> getValidAccessKey() async {
    final profile = await getCurrentUserProfile();
    return profile?.accessKey;
  }

  /// Get user mobile number
  Future<String?> getUserMobile() async {
    final profile = await getCurrentUserProfile();
    return profile?.mobile;
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final profile = await getCurrentUserProfile();
    return profile != null;
  }

  /// Logout and clear all data
  Future<void> logout() async {
    try {
      // Clear secure storage
      await _secureStorage.delete(key: _userProfileKey);
      await _secureStorage.delete(key: _accessKeyKey);
      await _secureStorage.delete(key: _loginTimeKey);
      
      // Clear cache
      _cachedProfile = null;
      _lastValidation = null;
      
      // Notify listeners
      _notifyProfileChanged(null);
      _notifyLoginStatusChanged(false);
      
      _logger.log('User logged out successfully');
    } catch (e) {
      _logger.error('Error during logout: $e');
      rethrow;
    }
  }

  /// Clear expired profile
  Future<void> _clearExpiredProfile() async {
    _logger.log('Clearing expired profile');
    await logout();
  }

  /// Check if validation was done recently
  bool _isRecentlyValidated() {
    if (_lastValidation == null) return false;
    final timeSinceValidation = DateTime.now().difference(_lastValidation!);
    return timeSinceValidation < _validationInterval;
  }

  /// Start periodic validation
  void _startPeriodicValidation() {
    _validationTimer = Timer.periodic(_validationInterval, (timer) async {
      if (_cachedProfile != null) {
        if (!_isProfileValid(_cachedProfile!)) {
          await _clearExpiredProfile();
        }
      }
    });
  }

  /// Notify profile change
  void _notifyProfileChanged(UserProfile? profile) {
    if (!_profileController.isClosed) {
      _profileController.add(profile);
    }
  }

  /// Notify login status change
  void _notifyLoginStatusChanged(bool isLoggedIn) {
    if (!_loginStatusController.isClosed) {
      _loginStatusController.add(isLoggedIn);
    }
  }

  /// Refresh profile validation
  Future<void> refreshValidation() async {
    _lastValidation = null;
    await getCurrentUserProfile();
  }

  /// Check if access key is about to expire
  bool isAccessKeyNearExpiry() {
    if (_cachedProfile == null) return false;
    
    final now = DateTime.now();
    final daysSinceLogin = now.difference(_cachedProfile!.loginTime).inDays;
    return daysSinceLogin >= 8; // Warn 2 days before expiry
  }

  /// Get days until access key expires
  int getDaysUntilExpiry() {
    if (_cachedProfile == null) return 0;
    
    final now = DateTime.now();
    final daysSinceLogin = now.difference(_cachedProfile!.loginTime).inDays;
    return (_accessKeyExpiry.inDays - daysSinceLogin).clamp(0, _accessKeyExpiry.inDays);
  }

  /// Dispose resources
  void dispose() {
    _validationTimer?.cancel();
    _profileController.close();
    _loginStatusController.close();
  }
}

// Provider for CentralizedAuthManager
final centralizedAuthManagerProvider = Provider<CentralizedAuthManager>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final logger = ref.watch(loggerProvider);
  
  final manager = CentralizedAuthManager(
    secureStorage: secureStorage,
    prefs: prefs,
    logger: logger,
  );
  
  ref.onDispose(() => manager.dispose());
  return manager;
});

// Stream providers for reactive UI updates
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final manager = ref.watch(centralizedAuthManagerProvider);
  return manager.profileStream;
});

final loginStatusStreamProvider = StreamProvider<bool>((ref) {
  final manager = ref.watch(centralizedAuthManagerProvider);
  return manager.loginStatusStream;
});

// Updated providers using centralized manager
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final manager = ref.watch(centralizedAuthManagerProvider);
  return await manager.isLoggedIn();
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final manager = ref.watch(centralizedAuthManagerProvider);
  return await manager.getCurrentUserProfile();
});

final validAccessKeyProvider = FutureProvider<String?>((ref) async {
  final manager = ref.watch(centralizedAuthManagerProvider);
  return await manager.getValidAccessKey();
});

final userMobileProvider = FutureProvider<String?>((ref) async {
  final manager = ref.watch(centralizedAuthManagerProvider);
  return await manager.getUserMobile();
});

// Helper provider for access key expiry status
final accessKeyExpiryStatusProvider = Provider<AccessKeyExpiryStatus>((ref) {
  final manager = ref.watch(centralizedAuthManagerProvider);
  return AccessKeyExpiryStatus(
    isNearExpiry: manager.isAccessKeyNearExpiry(),
    daysUntilExpiry: manager.getDaysUntilExpiry(),
  );
});

class AccessKeyExpiryStatus {
  final bool isNearExpiry;
  final int daysUntilExpiry;
  
  AccessKeyExpiryStatus({
    required this.isNearExpiry,
    required this.daysUntilExpiry,
  });
}