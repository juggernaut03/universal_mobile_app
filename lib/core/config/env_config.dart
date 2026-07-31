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

  /// Why the build cannot start, or null when it is configured.
  ///
  /// A missing project code cannot be recovered at runtime, so the app refuses
  /// to run rather than run mis-tenanted. main() turns this into a visible
  /// screen: this used to `throw` before runApp, which on iOS leaves the launch
  /// storyboard up and is indistinguishable from a hung white app.
  static String? configurationError() {
    if (projectCode.isEmpty) {
      return 'PROJECT_CODE is not set.\n\n'
          'Run with:\n'
          'flutter run --dart-define-from-file=dart_defines/dev.json\n\n'
          '(see lib/core/config/env_config.dart)';
    }
    return null;
  }
}
