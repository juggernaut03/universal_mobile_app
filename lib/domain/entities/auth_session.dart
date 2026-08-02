// lib/domain/entities/auth_session.dart
//
// Pure Dart. The wire shapes — `{success, message, data:{token, user}}`,
// `authentication: 1`, `expiresIn` as a string — stop at the data layer.
//
// Replaces the parts of `auth_models.dart` the app reasons about. Note what is
// gone: `OtpValidationResponse.authentication` was an int where 1 meant "yes",
// and callers wrote `if (response.authentication == 1)`. A session either
// exists or it does not.

import 'package:meta/meta.dart';

/// A signed-in user and the credential proving it.
@immutable
final class AuthSession {
  /// Mobile number the session belongs to.
  final String mobile;

  /// JWT presented as `Authorization: Bearer`.
  final String accessToken;

  /// When the session was established.
  final DateTime issuedAt;

  /// Fallback lifetime, used only when [tokenExpiresAt] is unknown.
  ///
  /// This is a guess the client makes about a value only the server knows.
  /// Prefer [tokenExpiresAt]; see the note on [expiresAt].
  final Duration lifetime;

  /// Long-lived credential that mints new access tokens without a fresh OTP.
  ///
  /// Empty when the backend issued no refresh token, in which case the session
  /// simply ends at [expiresAt] as before.
  final String refreshToken;

  /// When [accessToken] actually stops being accepted, from its own `exp`.
  ///
  /// The authority on expiry. `issuedAt + lifetime` was a client-side guess
  /// with no relationship to the token, and it disagreed with the rule
  /// CentralizedAuthManager applies — so `isSignedIn()` could say yes while
  /// `currentSession()` said "Session expired" for the very same session.
  /// Checkout asks the second one, so a live shopper silently lost their
  /// identity at the till.
  final DateTime? tokenExpiresAt;

  const AuthSession({
    required this.mobile,
    required this.accessToken,
    required this.issuedAt,
    this.lifetime = const Duration(days: 10),
    this.refreshToken = '',
    this.tokenExpiresAt,
  });

  /// Whether this session can outlive its access token.
  bool get isRenewable => refreshToken.isNotEmpty;

  /// Moment the credential stops being accepted.
  ///
  /// The token's own `exp` when known, and only otherwise the guess.
  DateTime get expiresAt => tokenExpiresAt ?? issuedAt.add(lifetime);

  /// Whether the session is expired at [now].
  ///
  /// Takes `now` rather than reading the clock, so expiry is testable.
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Whether the session is usable at [now].
  ///
  /// A renewable session stays usable past its access token: renewing it is
  /// precisely what the refresh token is for, and treating it as expired is
  /// what signed people out with a perfectly good session on the device.
  bool isValidAt(DateTime now) {
    if (accessToken.isEmpty) return false;
    if (isRenewable) return true;
    return !isExpiredAt(now);
  }

  /// Whole days remaining before expiry, floored at zero.
  int daysRemainingAt(DateTime now) {
    final remaining = expiresAt.difference(now).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Whether the session is close enough to expiry to warn the user.
  bool isNearExpiryAt(DateTime now, {Duration threshold = const Duration(days: 2)}) =>
      !isExpiredAt(now) && expiresAt.difference(now) <= threshold;

  AuthSession copyWith({
    String? mobile,
    String? accessToken,
    DateTime? issuedAt,
    Duration? lifetime,
    String? refreshToken,
    DateTime? tokenExpiresAt,
  }) =>
      AuthSession(
        mobile: mobile ?? this.mobile,
        accessToken: accessToken ?? this.accessToken,
        issuedAt: issuedAt ?? this.issuedAt,
        lifetime: lifetime ?? this.lifetime,
        refreshToken: refreshToken ?? this.refreshToken,
        tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          other.mobile == mobile &&
          other.accessToken == accessToken &&
          other.issuedAt == issuedAt;

  @override
  int get hashCode => Object.hash(mobile, accessToken, issuedAt);

  /// Never interpolates the token — this string reaches logs.
  @override
  String toString() => 'AuthSession($mobile, issued $issuedAt, expires $expiresAt)';
}

/// Outcome of asking the backend to send an OTP.
@immutable
final class OtpChallenge {
  /// Mobile number the code was sent to.
  final String mobile;

  /// How long the code stays valid, when the backend reports it.
  final Duration? expiresIn;

  const OtpChallenge({required this.mobile, this.expiresIn});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpChallenge &&
          other.mobile == mobile &&
          other.expiresIn == expiresIn;

  @override
  int get hashCode => Object.hash(mobile, expiresIn);

  @override
  String toString() => 'OtpChallenge($mobile, expiresIn: $expiresIn)';
}
