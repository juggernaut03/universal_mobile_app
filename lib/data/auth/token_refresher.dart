// lib/data/auth/token_refresher.dart

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import 'centralized_auth_manager.dart';

/// Calls POST /api/auth/refresh-token.
///
/// Deliberately tiny and separate from AuthService. CentralizedAuthManager
/// needs this, and AuthService needs an authenticated ApiClient, which needs
/// the manager — routing refresh through AuthService would close that loop.
/// This takes an ApiClient directly and uses only its unauthenticated verbs.
class TokenRefresher {
  final ApiClient _apiClient;
  final Logger _logger;

  TokenRefresher({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// Exchanges [refreshToken] for a new pair.
  ///
  /// Returns null when the server rejects the token — a genuine end of session.
  /// Anything else (5xx, timeout, offline) throws, so the caller can tell
  /// "signed out" from "unreachable" and not discard a live session because
  /// the network dropped.
  Future<RefreshedTokens?> refresh(String refreshToken) async {
    _logger.log('Refreshing access token');

    try {
      // `post`, not `postWithAuth`: this must work precisely when the access
      // token is dead, and attaching an expired bearer would trip ApiClient's
      // 401 handling and force the logout this call exists to prevent.
      final response = await _apiClient.post(
        ApiConstants.authRefreshToken,
        body: {'refreshToken': refreshToken},
      );

      final data = response is Map && response['data'] is Map
          ? response['data'] as Map
          : const {};
      final access = (data['token'] ?? '').toString();
      final rotated = (data['refreshToken'] ?? '').toString();

      if (access.isEmpty) {
        _logger.warning('Refresh response carried no token');
        return null;
      }
      return RefreshedTokens(accessToken: access, refreshToken: rotated);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 400) {
        _logger.warning('Refresh token rejected by server: ${e.message}');
        return null;
      }
      rethrow;
    }
  }

  /// Revokes [refreshToken] server-side, so signing out really ends the
  /// session rather than leaving a token that works until it expires.
  ///
  /// Uses [ApiClient.postWithToken] with the access token the caller already
  /// holds: the ordinary authenticated path would try to refresh on a 401 and
  /// resurrect the session being ended.
  Future<void> revoke({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _apiClient.postWithToken(
      ApiConstants.authLogout,
      accessToken,
      body: {'refreshToken': refreshToken},
    );
  }
}
