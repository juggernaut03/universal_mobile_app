// lib/core/config/env_config.dart
//
// Build-time configuration for the universal multi-tenant backend.
// Every client build of this app is produced from the same codebase with:
//   flutter build apk \
//     --dart-define=PROJECT_CODE=RET5677 \
//     --dart-define=API_BASE_URL=https://dev-universal-backendapi.shalviadvision.com/api \
//     --dart-define=RAZORPAY_KEY_ID=rzp_live_xxx
class EnvConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev-universal-backendapi.shalviadvision.com/api',
  );

  /// The tenant this build belongs to.
  ///
  /// Build-time by necessity, not by preference: it is the key the backend
  /// routes on, so it has to be known before the first request — there is no
  /// call that could supply it. Everything downstream of it (stores, config,
  /// branding, catalogue) does come from the API.
  ///
  /// Deliberately no default. It previously fell back to a real tenant's code,
  /// so a build that forgot the flag silently shipped as that client instead of
  /// failing — see [assertConfigured].
  static const String projectCode = String.fromEnvironment('PROJECT_CODE');

  /// Razorpay key for this tenant. No default for the same reason, and one
  /// more: the previous default was a *live* key, so an unflagged build took
  /// real payments into one specific client's account.
  static const String razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

  /// Fails the build's first frame rather than letting it run mis-tenanted.
  ///
  /// Called from main(); a missing project code cannot be recovered at runtime,
  /// and the failure it causes otherwise is a confusing empty catalogue rather
  /// than an obviously wrong build.
  static void assertConfigured() {
    if (projectCode.isEmpty) {
      throw StateError(
        'PROJECT_CODE is not set. Build with '
        '--dart-define=PROJECT_CODE=<tenant code> '
        '(see lib/core/config/env_config.dart).',
      );
    }
  }
}
