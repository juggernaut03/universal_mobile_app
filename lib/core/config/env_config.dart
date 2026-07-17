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

  static const String projectCode = String.fromEnvironment(
    'PROJECT_CODE',
    defaultValue: 'RET5677',
  );

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_live_Qq9CQRIX2I2qej',
  );
}
