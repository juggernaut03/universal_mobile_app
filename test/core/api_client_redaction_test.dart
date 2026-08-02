// test/core/api_client_redaction_test.dart
//
// ApiClient logged every response body verbatim, and the sign-in and refresh
// responses carry `token` and `refreshToken`. A plaintext refresh token — good
// for 90 days, and enough to mint access tokens at will — was therefore written
// to the device log on every login and every renewal.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patelmart/core/network/api_client.dart';
import 'package:patelmart/core/utils/logger.dart';

/// Captures what would have been logged.
class RecordingLogger implements Logger {
  final List<String> lines = [];

  String get all => lines.join('\n');

  @override
  void log(String message) => lines.add(message);

  @override
  void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      lines.add(message);

  @override
  void warning(String message) => lines.add(message);

  @override
  noSuchMethod(Invocation invocation) => null;
}

ApiClient clientReturning(Map<String, dynamic> body, RecordingLogger logger) {
  return ApiClient(
    client: MockClient((_) async => http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        )),
    logger: logger,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a sign-in response never puts credentials in the log', () async {
    final logger = RecordingLogger();
    final client = clientReturning({
      'success': true,
      'data': {
        'token': 'header.payload.signature-that-authenticates-requests',
        'refreshToken': 'a-refresh-token-good-for-ninety-days',
        'user': {'mobile': '9999999999', 'name': 'Test'},
      },
    }, logger);

    await client.post('https://example.test/api/auth/verify-otp');

    expect(logger.all, isNot(contains('header.payload.signature')));
    expect(logger.all, isNot(contains('a-refresh-token-good-for-ninety-days')));
    expect(logger.all, contains('redacted'));
  });

  test('the response shape survives redaction', () async {
    // These logs are read to answer "did the server send a token at all?".
    // Dropping them entirely would lose that; the length keeps it answerable.
    final logger = RecordingLogger();
    final client = clientReturning({
      'success': true,
      'data': {'token': 'abcdefghij', 'user': {'mobile': '9999999999'}},
    }, logger);

    await client.post('https://example.test/api/auth/verify-otp');

    expect(logger.all, contains('success'));
    expect(logger.all, contains('9999999999'), reason: 'non-secret fields stay');
    expect(logger.all, contains('<redacted 10 chars>'));
  });

  test('the caller still receives the real token', () async {
    // Redaction is for the log only — it must not touch what is parsed.
    final logger = RecordingLogger();
    final client = clientReturning({
      'success': true,
      'data': {'token': 'the-real-token'},
    }, logger);

    final response = await client.post('https://example.test/api/auth/verify-otp');

    expect(response['data']['token'], 'the-real-token');
  });

  test('a non-JSON body is logged unchanged', () async {
    // An HTML error page carries no credentials and has nothing to redact, so
    // it must reach the log intact — that text is the only clue to what a
    // proxy or gateway actually returned. The decode failure that follows is
    // existing behaviour and not what this test is about.
    final logger = RecordingLogger();
    final client = ApiClient(
      client: MockClient((_) async => http.Response('<html>Bad Gateway</html>', 200)),
      logger: logger,
    );

    await expectLater(
      client.post('https://example.test/api/anything'),
      throwsA(isA<ApiException>()),
    );

    expect(logger.all, contains('Bad Gateway'));
  });

  test('a razorpay signature is redacted too', () async {
    final logger = RecordingLogger();
    final client = clientReturning({
      'success': true,
      'razorpay_signature': 'signature-proving-the-payment',
    }, logger);

    await client.post('https://example.test/api/razorpay/verify');

    expect(logger.all, isNot(contains('signature-proving-the-payment')));
  });
}
