// lib/core/auth/centralized_auth_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:patelmart/di/infrastructure_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import '../models/auth_models.dart';

/// A freshly minted access/refresh pair from POST /api/auth/refresh-token.
class RefreshedTokens {
  final String accessToken;
  final String refreshToken;

  const RefreshedTokens({
    required this.accessToken,
    required this.refreshToken,
  });
}

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
  
  // Storage keys.
  // v3: profiles hold JWT tokens from the universal backend. Bumping the key
  // deterministically logs out installs holding a legacy access_key that the
  // new backend would reject.
  static const String _userProfileKey = 'user_profile_v3';
  static const String _loginTimeKey = 'login_time_v2';
  static const String _accessKeyKey = 'access_key_v2';
  
  /// Performs the network half of a token refresh.
  ///
  /// A callback rather than an ApiClient: ApiClient asks this manager for the
  /// bearer token on every request, so holding one here would be a cycle. The
  /// composition root wires it to AuthService.
  final Future<RefreshedTokens?> Function(String refreshToken)? _refreshTokens;

  /// Tells the server to revoke a refresh token on sign-out. Best-effort.
  final Future<void> Function({
    required String accessToken,
    required String refreshToken,
  })? _revokeSession;

  /// De-duplicates concurrent refreshes; see [refreshAccessToken].
  Future<String?>? _refreshInFlight;

  CentralizedAuthManager({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
    required Logger logger,
    Future<RefreshedTokens?> Function(String refreshToken)? refreshTokens,
    Future<void> Function({
      required String accessToken,
      required String refreshToken,
    })? revokeSession,
  }) : _secureStorage = secureStorage,
       _prefs = prefs,
       _logger = logger,
       _refreshTokens = refreshTokens,
       _revokeSession = revokeSession {
    _initializeManager();
  }

  // Streams for reactive updates
  Stream<UserProfile?> get profileStream => _profileController.stream;
  Stream<bool> get loginStatusStream => _loginStatusController.stream;

  /// Initialize the manager and load cached data
  Future<void> _initializeManager() async {
    try {
      // Legacy access_key sessions (pre-universal backend) are not migrated —
      // they are useless against the JWT-based backend. Just purge them.
      await _cleanupLegacyStorage();
      await _loadCachedProfile();
      _startPeriodicValidation();
      _logger.log('CentralizedAuthManager initialized');
    } catch (e) {
      _logger.error('Error initializing auth manager: $e');
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
      // v2 profiles hold legacy access_keys the universal backend rejects
      await _secureStorage.delete(key: 'user_profile_v2');
      
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
  ///
  /// A session with a refresh token is valid regardless of the access token's
  /// state — renewing it is exactly what the refresh token is for. Discarding
  /// such a profile is what made a restart look like a logout: the stored
  /// session was thrown away locally while the server still considered it live.
  ///
  /// Without a refresh token, fall back to the access token's real `exp`, and
  /// only then to the legacy days-since-login rule (for profiles written before
  /// expiry was recorded).
  bool _isProfileValid(UserProfile profile) {
    if (profile.accessKey.isEmpty) return false;
    if (profile.hasRefreshToken) return true;

    final expiry = profile.accessKeyExpiresAt;
    if (expiry != null) return DateTime.now().isBefore(expiry);

    final daysSinceLogin = DateTime.now().difference(profile.loginTime).inDays;
    return daysSinceLogin < _accessKeyExpiry.inDays;
  }

  /// Save user profile after successful login
  ///
  /// [notifyDelay] is the settle time given to auth-state listeners after a
  /// login. A token refresh passes zero: it changes the credential, not the
  /// signed-in identity, and it can happen mid-request where half a second of
  /// added latency on every call would be felt.
  Future<void> saveUserProfile(
    UserProfile profile, {
    Duration notifyDelay = const Duration(milliseconds: 500),
  }) async {
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

      // Force a longer delay to ensure all listeners are updated and auth state propagates
      // This is crucial for new user login flow to prevent race conditions
      if (notifyDelay > Duration.zero) {
        await Future.delayed(notifyDelay);
      }

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

  /// Get valid access key, renewing it first if it is at or near expiry.
  ///
  /// Refreshing here rather than only on a 401 means the common case never
  /// produces a failed request at all.
  Future<String?> getValidAccessKey() async {
    final profile = await getCurrentUserProfile();
    if (profile == null) return null;

    if (profile.hasRefreshToken && profile.accessKeyNeedsRefresh()) {
      _logger.log('Access token at/near expiry — refreshing before use');
      final refreshed = await refreshAccessToken();
      if (refreshed != null) return refreshed;
    }

    return profile.accessKey;
  }

  /// Exchange the stored refresh token for a new access/refresh pair.
  ///
  /// Returns the new access token, or null when the session cannot be renewed
  /// (no refresh token, or the server rejected it — a revoked or expired
  /// refresh token, or a sign-out on another device).
  ///
  /// Concurrent callers share one in-flight request: a screen typically fires
  /// several requests at once, and without this they would each burn a
  /// rotation of the refresh token, with all but one of the resulting tokens
  /// immediately invalidated by the next.
  Future<String?> refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh()
        .whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _performRefresh() async {
    final profile = _cachedProfile ?? await getCurrentUserProfile();
    if (profile == null || !profile.hasRefreshToken) {
      _logger.warning('Refresh requested but no refresh token is stored');
      return null;
    }

    if (_refreshTokens == null) {
      _logger.warning('Refresh requested but no refresh callback is wired');
      return null;
    }

    try {
      final result = await _refreshTokens(profile.refreshToken);
      if (result == null || result.accessToken.isEmpty) {
        _logger.warning('Refresh rejected by server — session is over');
        await logout();
        return null;
      }

      final updated = profile.copyWith(
        accessKey: result.accessToken,
        // The server rotates on every refresh, so the old one is already spent.
        refreshToken: result.refreshToken.isNotEmpty
            ? result.refreshToken
            : profile.refreshToken,
        accessKeyExpiresAt: UserProfile.expiryFromJwt(result.accessToken),
      );
      await saveUserProfile(updated, notifyDelay: Duration.zero);
      _logger.log('Access token refreshed');
      return updated.accessKey;
    } catch (e) {
      // A network failure is not an expired session. Keep the stored session
      // so the shopper is not signed out by a dropped connection; the next
      // call retries, and a genuinely dead session fails on the server's word.
      _logger.error('Token refresh failed (keeping session): $e');
      return null;
    }
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
      // Revoke server-side first, so the refresh token cannot outlive the
      // sign-out. Best-effort and never blocking: if the device is offline the
      // local session must still be cleared, and the refresh token expires on
      // its own. (A refresh racing this call could leave the rotated token
      // live until it expires — rare, and not worth holding logout for.)
      final refreshToken = _cachedProfile?.refreshToken ?? '';
      final accessToken = _cachedProfile?.accessKey ?? '';
      if (refreshToken.isNotEmpty && accessToken.isNotEmpty && _revokeSession != null) {
        try {
          await _revokeSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          _logger.log('Refresh token revoked server-side');
        } catch (e) {
          _logger.warning('Server-side revoke failed, clearing locally: $e');
        }
      }

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
      final profile = _cachedProfile;
      if (profile == null) return;

      // Renew before discarding. A renewable session that merely has a stale
      // access token is not an expired session, and signing the shopper out of
      // one — potentially mid-checkout — is the outcome worth avoiding here.
      if (profile.hasRefreshToken && profile.accessKeyNeedsRefresh()) {
        await refreshAccessToken();
        return;
      }

      if (!_isProfileValid(profile)) {
        await _clearExpiredProfile();
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

// centralizedAuthManagerProvider now declared in lib/di/infrastructure_providers.dart

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