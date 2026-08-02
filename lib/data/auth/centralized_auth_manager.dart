// lib/data/auth/centralized_auth_manager.dart

import 'dart:async';

import '../../core/utils/logger.dart';
import '../models/auth_models.dart';
import 'auth_local_data_source.dart';
import 'session_expiry_policy.dart';

/// A freshly minted access/refresh pair from POST /api/auth/refresh-token.
class RefreshedTokens {
  final String accessToken;
  final String refreshToken;

  const RefreshedTokens({
    required this.accessToken,
    required this.refreshToken,
  });
}

/// Single source of truth for the signed-in session.
///
/// Orchestration only. The three things it used to do inline now live behind
/// collaborators it depends on abstractly:
///
///   * persistence and JSON  -> [AuthLocalDataSource]
///   * "is this still valid" -> [SessionExpiryPolicy]
///   * the refresh round-trip -> the [refreshTokens] callback
///
/// This file declares no Riverpod providers. It used to declare seven at the
/// bottom, four of which duplicated declarations in
/// `presentation/providers/auth_providers.dart` under the same names. Those
/// were distinct provider objects with separate caches, so
/// `ref.invalidate(userProfileProvider)` in a screen that imported this file
/// invalidated a provider no other screen watched, and the rest of the app kept
/// serving stale data. Wiring belongs in `lib/di/`.
class CentralizedAuthManager {
  final AuthLocalDataSource _storage;
  final SessionExpiryPolicy _expiry;
  final Logger _logger;

  UserProfile? _cachedProfile;
  DateTime? _lastValidation;
  Timer? _validationTimer;

  final StreamController<UserProfile?> _profileController =
      StreamController<UserProfile?>.broadcast();
  final StreamController<bool> _loginStatusController =
      StreamController<bool>.broadcast();

  static const Duration _validationInterval = Duration(minutes: 5);

  /// Performs the network half of a token refresh.
  ///
  /// A callback rather than an ApiClient: ApiClient asks this manager for the
  /// bearer token on every request, so holding one here would be a cycle. The
  /// composition root wires it to TokenRefresher.
  final Future<RefreshedTokens?> Function(String refreshToken)? _refreshTokens;

  /// Tells the server to revoke a refresh token on sign-out. Best-effort.
  final Future<void> Function({
    required String accessToken,
    required String refreshToken,
  })? _revokeSession;

  /// De-duplicates concurrent refreshes; see [refreshAccessToken].
  Future<String?>? _refreshInFlight;

  /// Completes once the stored session has been loaded.
  ///
  /// Every public accessor awaits this. Initialisation used to be launched from
  /// the constructor and never awaited, so `getValidAccessKey()` could return
  /// null purely because storage had not finished loading — the app then sent
  /// an unauthenticated request and the backend's "no token provided" looked
  /// like a lost session. `ApiClient._getToken()` grew a three-attempt retry
  /// loop with sleeps to paper over exactly this race.
  late final Future<void> _ready;

  CentralizedAuthManager({
    required AuthLocalDataSource storage,
    required Logger logger,
    SessionExpiryPolicy expiryPolicy = const SessionExpiryPolicy(),
    Future<RefreshedTokens?> Function(String refreshToken)? refreshTokens,
    Future<void> Function({
      required String accessToken,
      required String refreshToken,
    })? revokeSession,
  })  : _storage = storage,
        _expiry = expiryPolicy,
        _logger = logger,
        _refreshTokens = refreshTokens,
        _revokeSession = revokeSession {
    _ready = _initialize();
  }

  /// Awaitable startup, for callers that want the session resolved before they
  /// render — the router's first redirect being the one that matters.
  Future<void> get ready => _ready;

  Stream<UserProfile?> get profileStream => _profileController.stream;
  Stream<bool> get loginStatusStream => _loginStatusController.stream;

  Future<void> _initialize() async {
    try {
      // Legacy access_key sessions (pre-universal backend) are not migrated —
      // they are useless against the JWT-based backend. Just purge them.
      await _storage.purgeLegacy();
      await _loadCachedProfile();
      _startPeriodicValidation();
      _logger.log('CentralizedAuthManager initialized');
    } catch (e) {
      _logger.error('Error initializing auth manager: $e');
    }
  }

  /// Loads the stored profile into the cache.
  ///
  /// Three outcomes, kept distinct because conflating them is what signed
  /// people out spuriously:
  ///   * no profile        -> signed out, nothing to do
  ///   * unreadable profile-> keep whatever is cached, do NOT sign out
  ///   * expired profile   -> sign out
  Future<void> _loadCachedProfile() async {
    final UserProfile? profile;
    try {
      profile = await _storage.read();
    } on AuthStorageException catch (e) {
      // Keystore key gone after a device restore, keychain still locked, or a
      // corrupt blob. None of these say the session ended. Clearing here threw
      // away live sessions for a storage problem.
      _logger.error('[AUTH] session unreadable, keeping current state: $e');
      return;
    }

    if (profile == null) {
      final cached = _cachedProfile;
      if (cached != null) {
        // Storage says there is no session while one is plainly live in memory.
        // That is not a sign-out — nothing asked for one. It means the read
        // came back empty: the iOS Simulator keychain does this intermittently,
        // and a write that silently failed leaves the same trace.
        //
        // Trusting the empty read here signed the shopper out mid-checkout,
        // because the cache is re-read every _validationInterval and one blank
        // answer was enough. Only logout() ends a session.
        _logger.warning('[AUTH] storage returned nothing while a session is '
            'cached — keeping it and re-persisting');
        unawaited(_repersist(cached));
        return;
      }

      _logger.log('[AUTH] no stored session');
      _lastValidation = null;
      return;
    }

    if (_expiry.isValid(profile)) {
      _cachedProfile = profile;
      _lastValidation = DateTime.now();
      _notifyProfileChanged(profile);
      _notifyLoginStatusChanged(true);
      return;
    }

    _logger.warning('[AUTH] stored session expired — '
        'accessKeyEmpty=${profile.accessKey.isEmpty} '
        'hasRefresh=${profile.hasRefreshToken} '
        'expiresAt=${profile.accessKeyExpiresAt} '
        'loginTime=${profile.loginTime}');
    await logout();
  }

  /// Writes [profile] back after storage came up empty holding a live session.
  ///
  /// Best-effort and never throws: this runs to repair storage, and failing to
  /// repair it must not disturb a session that is working from memory.
  Future<void> _repersist(UserProfile profile) async {
    try {
      await _storage.write(profile);
      _logger.log('[AUTH] cached session re-persisted');
    } catch (e) {
      _logger.warning('[AUTH] could not re-persist cached session: $e');
    }
  }

  /// Save user profile after successful login.
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
      await _storage.write(profile);

      _cachedProfile = profile;
      _lastValidation = DateTime.now();

      _notifyProfileChanged(profile);
      _notifyLoginStatusChanged(true);

      if (notifyDelay > Duration.zero) {
        await Future.delayed(notifyDelay);
      }

      _logger.log('User profile saved and streams updated: ${profile.mobile}');
    } catch (e) {
      _logger.error('Error saving user profile: $e');
      rethrow;
    }
  }

  /// Get current user profile.
  Future<UserProfile?> getCurrentUserProfile() async {
    await _ready;
    try {
      if (_cachedProfile != null && _isRecentlyValidated()) {
        return _cachedProfile;
      }
      await _loadCachedProfile();
      return _cachedProfile;
    } catch (e) {
      _logger.error('Error getting current user profile: $e');
      return _cachedProfile;
    }
  }

  /// Get a valid access key, renewing it first if it is at or near expiry.
  ///
  /// Refreshing here rather than only on a 401 means the common case never
  /// produces a failed request at all.
  Future<String?> getValidAccessKey() async {
    final profile = await getCurrentUserProfile();
    if (profile == null) {
      // The single most consequential null in the app: every authenticated
      // call silently goes out with no Authorization header and the backend
      // answers "Access denied. No token provided.", which reads like a server
      // fault rather than a lost local session.
      _logger.warning('[AUTH] getValidAccessKey: NO PROFILE — request will be '
          'sent unauthenticated');
      return null;
    }

    if (_expiry.needsRefresh(profile)) {
      _logger.log('Access token at/near expiry — refreshing before use');
      final refreshed = await refreshAccessToken();
      if (refreshed != null) return refreshed;

      // Refresh failed on a token we already know is at/past expiry. Returning
      // the captured `profile.accessKey` handed back a credential known to be
      // dead, and after a rejected refresh it came from a session that had just
      // been cleared. Re-read instead: whatever survived is the truth.
      _logger.warning('[AUTH] refresh yielded no token for an expiring session');
      final current = _cachedProfile;
      if (current == null || current.accessKey.isEmpty) return null;
      return current.accessKey;
    }

    if (profile.accessKey.isEmpty) {
      _logger.warning('[AUTH] getValidAccessKey: profile has an EMPTY access '
          'key (mobile=${profile.mobile})');
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
    return _refreshInFlight ??=
        _performRefresh().whenComplete(() => _refreshInFlight = null);
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

  Future<String?> getUserMobile() async {
    final profile = await getCurrentUserProfile();
    return profile?.mobile;
  }

  Future<bool> isLoggedIn() async {
    final profile = await getCurrentUserProfile();
    return profile != null;
  }

  /// Clear the session locally, revoking it server-side first when possible.
  Future<void> logout() async {
    // Logged with a stack because sign-out is reached from several places that
    // are not the user pressing "log out" — a 401 that survives a refresh, a
    // rejected refresh token, a profile judged expired on load. When the
    // session vanishes mid-checkout, this line says which one did it.
    _logger.warning('[AUTH] logout() called — clearing session\n'
        '${StackTrace.current}');
    try {
      // Revoke server-side first, so the refresh token cannot outlive the
      // sign-out. Best-effort and never blocking: if the device is offline the
      // local session must still be cleared, and the refresh token expires on
      // its own.
      final refreshToken = _cachedProfile?.refreshToken ?? '';
      final accessToken = _cachedProfile?.accessKey ?? '';
      if (refreshToken.isNotEmpty &&
          accessToken.isNotEmpty &&
          _revokeSession != null) {
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

      await _storage.clear();

      _cachedProfile = null;
      _lastValidation = null;

      _notifyProfileChanged(null);
      _notifyLoginStatusChanged(false);

      _logger.log('User logged out successfully');
    } catch (e) {
      _logger.error('Error during logout: $e');
      rethrow;
    }
  }

  bool _isRecentlyValidated() {
    if (_lastValidation == null) return false;
    return DateTime.now().difference(_lastValidation!) < _validationInterval;
  }

  void _startPeriodicValidation() {
    _validationTimer?.cancel();
    _validationTimer = Timer.periodic(_validationInterval, (_) async {
      final profile = _cachedProfile;
      if (profile == null) return;

      // Renew before discarding. A renewable session that merely has a stale
      // access token is not an expired session, and signing the shopper out of
      // one — potentially mid-checkout — is the outcome worth avoiding here.
      if (_expiry.needsRefresh(profile)) {
        await refreshAccessToken();
        return;
      }

      if (!_expiry.isValid(profile)) {
        await logout();
      }
    });
  }

  void _notifyProfileChanged(UserProfile? profile) {
    if (!_profileController.isClosed) {
      _profileController.add(profile);
    }
  }

  void _notifyLoginStatusChanged(bool isLoggedIn) {
    if (!_loginStatusController.isClosed) {
      _loginStatusController.add(isLoggedIn);
    }
  }

  /// Force the next read to go to storage rather than the cache.
  Future<void> refreshValidation() async {
    _lastValidation = null;
    await getCurrentUserProfile();
  }

  /// Whether the session is close enough to expiry to warn the shopper.
  ///
  /// Answered by [SessionExpiryPolicy] like every other expiry question. This
  /// used to apply its own "days since login >= 8" rule against a 10-day
  /// constant, ignoring the token's real `exp` — so it disagreed with the rule
  /// that actually decided whether the session was valid.
  bool isAccessKeyNearExpiry() {
    final profile = _cachedProfile;
    return profile != null && _expiry.isNearExpiry(profile);
  }

  /// Whole days until the session expires, or 0 when signed out.
  int getDaysUntilExpiry() {
    final profile = _cachedProfile;
    return profile == null ? 0 : _expiry.daysUntilExpiry(profile);
  }

  void dispose() {
    _validationTimer?.cancel();
    _profileController.close();
    _loginStatusController.close();
  }
}
