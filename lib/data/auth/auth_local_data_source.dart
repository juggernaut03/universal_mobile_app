// lib/data/auth/auth_local_data_source.dart

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/logger.dart';
import '../models/auth_models.dart';

/// Persistence for the signed-in session.
///
/// An interface so [CentralizedAuthManager] can be unit-tested against an
/// in-memory fake. Previously the manager did secure-storage I/O and JSON
/// encoding inline, which meant no test could exercise session restore, the
/// periodic validation timer, or the corrupt-payload path without a device.
abstract interface class AuthLocalDataSource {
  /// The stored profile, or null when absent.
  ///
  /// Throws [AuthStorageException] when a profile exists but cannot be read —
  /// which is emphatically not the same as "signed out". See the note there.
  Future<UserProfile?> read();

  /// Persists [profile], replacing any existing one.
  Future<void> write(UserProfile profile);

  /// Removes the stored profile.
  Future<void> clear();

  /// Deletes credentials written by superseded versions of the app.
  Future<void> purgeLegacy();
}

/// Raised when a stored profile exists but cannot be decrypted or parsed.
///
/// Distinguished from "no profile" on purpose. The two used to be conflated,
/// so a keystore failure after an Android device-to-device restore — where the
/// ciphertext survives but the key does not — was indistinguishable from a
/// deliberate sign-out, and the app silently logged the shopper out.
class AuthStorageException implements Exception {
  final String message;
  final Object cause;

  const AuthStorageException(this.message, this.cause);

  @override
  String toString() => 'AuthStorageException: $message ($cause)';
}

/// [AuthLocalDataSource] backed by the platform keystore/keychain.
class SecureAuthLocalDataSource implements AuthLocalDataSource {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final Logger _logger;

  /// v3: profiles hold JWT tokens from the universal backend. Bumping the key
  /// deterministically logs out installs holding a legacy access_key that the
  /// new backend would reject.
  static const String _userProfileKey = 'user_profile_v3';

  /// Written by versions that stored the token outside the profile blob.
  /// Cleared on sign-out so nothing is left behind.
  static const String _accessKeyKey = 'access_key_v2';
  static const String _loginTimeKey = 'login_time_v2';

  /// Keys from before the universal backend. Their values are useless against
  /// it, so they are purged rather than migrated.
  static const List<String> _legacySecureKeys = [
    'user_access_key',
    'login_time',
    'user_profile',
    'user_profile_v2',
  ];

  static const List<String> _legacyPrefsKeys = [
    'user_profile',
    'otp_validation_response',
    'user_access_key',
  ];

  const SecureAuthLocalDataSource({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
    required Logger logger,
  })  : _secureStorage = secureStorage,
        _prefs = prefs,
        _logger = logger;

  @override
  Future<UserProfile?> read() async {
    String? raw;
    try {
      raw = await _secureStorage.read(key: _userProfileKey);
    } on Object catch (e) {
      // Platform-level failure: keystore key missing after a restore, keychain
      // locked before first unlock, corrupt cipher blob. The session may well
      // still be fine once the device is in a different state, so this must not
      // read as "signed out".
      throw AuthStorageException('secure storage read failed', e);
    }

    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('stored profile is not a JSON object');
      }
      return UserProfile.fromJson(decoded);
    } on Object catch (e) {
      throw AuthStorageException('stored profile could not be parsed', e);
    }
  }

  @override
  Future<void> write(UserProfile profile) {
    return _secureStorage.write(
      key: _userProfileKey,
      value: jsonEncode(profile.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: _userProfileKey);
    await _secureStorage.delete(key: _accessKeyKey);
    await _secureStorage.delete(key: _loginTimeKey);
  }

  @override
  Future<void> purgeLegacy() async {
    try {
      for (final key in _legacySecureKeys) {
        await _secureStorage.delete(key: key);
      }
      for (final key in _legacyPrefsKeys) {
        await _prefs.remove(key);
      }
      _logger.log('Legacy auth storage purged');
    } on Object catch (e) {
      // Best-effort housekeeping. Failing here must not block sign-in.
      _logger.warning('Legacy auth storage purge failed: $e');
    }
  }
}
