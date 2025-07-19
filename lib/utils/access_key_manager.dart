// lib/core/utils/access_key_manager.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/auth_models.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/launch_flow_provider.dart';

class AccessKeyManager {
  final SharedPreferences _prefs;
  final Logger _logger;
  final Ref _ref;
  
  // Cache the access key to avoid repeated storage reads
  String? _cachedAccessKey;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  AccessKeyManager({
    required SharedPreferences prefs,
    required Logger logger,
    required Ref ref,
  }) : _prefs = prefs, _logger = logger, _ref = ref;

  /// Get access key with proper error handling and caching
  Future<String?> getAccessKey() async {
    try {
      // Return cached key if still valid
      if (_isCacheValid()) {
        _logger.log('Returning cached access key');
        return _cachedAccessKey;
      }

      String? accessKey;
      
      // Strategy 1: Try from userProfileProvider first (most reliable)
      try {
        final userProfile = await _ref.read(userProfileProvider.future);
        if (userProfile?.accessKey != null && userProfile!.accessKey.isNotEmpty) {
          accessKey = userProfile.accessKey;
          _logger.log('Access key retrieved from userProfileProvider: ${accessKey?.substring(0, 8)}...');
        }
      } catch (e) {
        _logger.warning('Failed to get access key from userProfileProvider: $e');
      }

      // Strategy 2: Fallback to SharedPreferences with priority order
      if (accessKey == null || accessKey.isEmpty) {
        accessKey = await _getAccessKeyFromStorage();
      }

      // Strategy 3: Force refresh userProfileProvider if still no key
      if (accessKey == null || accessKey.isEmpty) {
        _logger.log('No access key found, forcing userProfileProvider refresh...');
        _ref.invalidate(userProfileProvider);
        
        try {
          final userProfile = await _ref.read(userProfileProvider.future);
          accessKey = userProfile?.accessKey;
        } catch (e) {
          _logger.error('Failed to refresh userProfileProvider: $e');
        }
      }

      // Cache the result
      if (accessKey != null && accessKey.isNotEmpty) {
        _cacheAccessKey(accessKey);
        return accessKey;
      }

      _logger.error('No valid access key found in any storage location');
      return null;
      
    } catch (e) {
      _logger.error('Error getting access key: $e');
      return null;
    }
  }

  /// Get access key from SharedPreferences with proper priority
  Future<String?> _getAccessKeyFromStorage() async {
    try {
      // Priority 1: user_profile format (most common)
      final userProfileStr = _prefs.getString('user_profile');
      if (userProfileStr != null && userProfileStr.isNotEmpty) {
        try {
          final userProfileData = jsonDecode(userProfileStr);
          if (userProfileData is Map && userProfileData.containsKey('accessKey')) {
            final key = userProfileData['accessKey'];
            if (key != null && key.toString().isNotEmpty) {
              _logger.log('Access key found in user_profile format');
              return key.toString();
            }
          }
        } catch (e) {
          _logger.warning('Error parsing user_profile: $e');
        }
      }

      // Priority 2: Direct storage format
      final directKey = _prefs.getString('user_access_key');
      if (directKey != null && directKey.isNotEmpty) {
        _logger.log('Access key found in direct storage format');
        return directKey;
      }

      // Priority 3: OTP validation response format
      final otpResponseStr = _prefs.getString('otp_validation_response');
      if (otpResponseStr != null && otpResponseStr.isNotEmpty) {
        try {
          final otpResponseData = jsonDecode(otpResponseStr);
          if (otpResponseData is Map && otpResponseData.containsKey('access_key')) {
            final key = otpResponseData['access_key'];
            if (key != null && key.toString().isNotEmpty) {
              _logger.log('Access key found in otp_validation_response format');
              return key.toString();
            }
          }
        } catch (e) {
          _logger.warning('Error parsing otp_validation_response: $e');
        }
      }

      _logger.warning('No access key found in SharedPreferences');
      return null;
      
    } catch (e) {
      _logger.error('Error reading access key from storage: $e');
      return null;
    }
  }

  /// Cache access key with timestamp
  void _cacheAccessKey(String accessKey) {
    _cachedAccessKey = accessKey;
    _lastCacheTime = DateTime.now();
    _logger.log('Access key cached successfully');
  }

  /// Check if cached access key is still valid
  bool _isCacheValid() {
    if (_cachedAccessKey == null || _lastCacheTime == null) {
      return false;
    }
    
    final now = DateTime.now();
    final timeSinceCache = now.difference(_lastCacheTime!);
    return timeSinceCache < _cacheValidDuration;
  }

  /// Clear cached access key (call when user logs out or key becomes invalid)
  void clearCache() {
    _cachedAccessKey = null;
    _lastCacheTime = null;
    _logger.log('Access key cache cleared');
  }

  /// Validate if access key exists and is not empty
  Future<bool> hasValidAccessKey() async {
    final accessKey = await getAccessKey();
    return accessKey != null && accessKey.isNotEmpty;
  }

  /// Force refresh access key from all sources
  Future<String?> forceRefreshAccessKey() async {
    clearCache();
    _ref.invalidate(userProfileProvider);
    
    // Wait a bit for provider to refresh
    await Future.delayed(const Duration(milliseconds: 500));
    
    return await getAccessKey();
  }
}

// Provider for AccessKeyManager
final accessKeyManagerProvider = Provider<AccessKeyManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final logger = ref.watch(loggerProvider);
  
  return AccessKeyManager(
    prefs: prefs,
    logger: logger,
    ref: ref,
  );
});

// Convenient provider to get access key
final accessKeyProvider = FutureProvider<String?>((ref) async {
  final manager = ref.watch(accessKeyManagerProvider);
  return await manager.getAccessKey();
});

// Provider to check if user has valid access key
final hasValidAccessKeyProvider = FutureProvider<bool>((ref) async {
  final manager = ref.watch(accessKeyManagerProvider);
  return await manager.hasValidAccessKey();
});