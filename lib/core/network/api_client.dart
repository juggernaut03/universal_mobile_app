// lib/core/network/api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import '../widgets/error_widgets.dart';
import '../constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ErrorType type;

  ApiException({
    required this.message,
    this.statusCode,
    this.type = ErrorType.generic
  });

  @override
  String toString() => 'ApiException: $message';
}

/// Single choke point for all backend traffic against the universal
/// multi-tenant API:
/// - X-Project-Code header on every request (plus project_code in body/query,
///   which several routes still validate explicitly)
/// - `Authorization: Bearer` JWT header on the *WithAuth variants
/// - 401 on an authenticated call forces logout (stale/invalid session)
class ApiClient {
  final http.Client _client;
  final Logger _logger;

  /// Supplies the bearer token, or null when there is no valid session.
  ///
  /// A plain callback rather than a CentralizedAuthManager. ApiClient lives in
  /// `core/`, which must not know about the data layer; taking the manager
  /// directly is what kept that class in `core/` even though it does secure
  /// storage I/O. The composition root wires these to the real session store.
  final Future<String?> Function()? _readToken;

  /// Invoked when an authenticated call returns 401, so the app can drop back
  /// to the login flow. Failures inside it are swallowed and logged.
  final Future<void> Function()? _onUnauthorized;

  /// Renews the access token, returning the new one or null if the session is
  /// genuinely over. Given a 401, this is tried before [_onUnauthorized].
  final Future<String?> Function()? _refreshToken;

  ApiClient({
    http.Client? client,
    Logger? logger,
    Future<String?> Function()? readToken,
    Future<void> Function()? onUnauthorized,
    Future<String?> Function()? refreshToken,
  }) : _client = client ?? http.Client(),
       _logger = logger ?? Logger(),
       _readToken = readToken,
       _onUnauthorized = onUnauthorized,
       _refreshToken = refreshToken;

  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Project-Code': ApiConstants.projectCode,
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// Fetch the JWT with retries — new-login flows can race storage writes.
  Future<String?> _getToken() async {
    if (_readToken == null) {
      // This client was built without a token source, so every `*WithAuth`
      // call it makes is unauthenticated. See apiClientProvider — resolving an
      // ApiClient from anywhere else is how this happens.
      _logger.warning('[AUTH] ApiClient has NO token reader — sending '
          'authenticated calls without a token');
      return null;
    }
    String? token;
    for (int attempt = 0; attempt < 3; attempt++) {
      token = await _readToken();
      if (token != null && token.isNotEmpty) break;
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        _logger.log('Retrying token retrieval, attempt ${attempt + 2}');
      }
    }
    if (token == null || token.isEmpty) {
      _logger.warning('[AUTH] token reader returned nothing after 3 attempts');
    }
    return token;
  }

  Future<dynamic> get(String url, {bool includeProjectCode = true}) async {
    return _run(() async {
      final Map<String, String> queryParams = {
        if (includeProjectCode) 'project_code': ApiConstants.projectCode,
        ...Uri.parse(url).queryParameters,
      };
      final Uri uri = Uri.parse(url)
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      _logger.log('GET request to: $uri');

      final response = await _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    });
  }

  Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    return _run(() async {
      final Map<String, dynamic> requestBody = {
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      };

      _logger.log('POST request to: $url');

      final response = await _client
          .post(Uri.parse(url),
              headers: _headers(), body: json.encode(requestBody))
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    });
  }

  /// POST with a caller-supplied bearer token.
  ///
  /// For the callers that already hold the token and must not go through the
  /// session machinery — sign-out being the case that matters: routing it via
  /// [postWithAuth] would let a 401 trigger a refresh and re-establish the very
  /// session being torn down, and would need an ApiClient built from the auth
  /// manager that is calling it.
  ///
  /// No refresh, no forced logout: the response is returned or thrown as-is.
  Future<dynamic> postWithToken(
    String url,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    return _run(() async {
      final Map<String, dynamic> requestBody = {
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      };

      _logger.log('POST with explicit token to: $url');

      final response = await _client
          .post(Uri.parse(url),
              headers: _headers(token: token), body: json.encode(requestBody))
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    });
  }

  /// Runs an authenticated request, renewing the session once if it 401s.
  ///
  /// [send] is called with the bearer token to use, so the retry re-sends the
  /// same request under the new token. Every `*WithAuth` verb goes through here
  /// so the 401 policy is defined once:
  ///
  ///   401 -> refresh -> retry once -> still 401? force logout.
  ///
  /// Previously a 401 forced logout immediately, so the instant an access token
  /// lapsed the shopper was signed out mid-session with no attempt to renew.
  Future<dynamic> _sendAuthed(
    Future<http.Response> Function(String? token) send,
  ) async {
    return _run(() async {
      final token = await _getToken();
      var response = await send(token);

      if (response.statusCode == 401 && _refreshToken != null) {
        _logger.warning('401 on authenticated call — attempting token refresh');
        String? renewed;
        try {
          renewed = await _refreshToken();
        } catch (e) {
          // Refresh itself failed to complete (offline, server down). Treat as
          // "could not renew" and fall through to the original 401 rather than
          // masking it with a different error.
          _logger.error('Token refresh threw: $e');
        }

        if (renewed != null && renewed.isNotEmpty) {
          _logger.log('Token refreshed — retrying the original request');
          response = await send(renewed);
        }
      }

      // Only now, with renewal ruled out, is a 401 a dead session — and only
      // if we actually presented a credential for the server to reject.
      //
      // When no token was sent, the 401 says nothing about the stored session:
      // the server never saw it. Logging out here destroyed live sessions
      // because of a client-side failure to attach the header, and the shopper
      // was signed out mid-checkout for a bug that had nothing to do with
      // their credentials.
      if (response.statusCode == 401 && _onUnauthorized != null) {
        if (token == null || token.isEmpty) {
          _logger.warning(
              '[AUTH] 401 on a request that carried NO token — not logging '
              'out; the session was never presented to the server');
        } else {
          _logger.warning('401 after refresh — forcing logout');
          unawaited(_onUnauthorized().catchError((e) {
            _logger.error('Forced logout failed: $e');
          }));
        }
      }

      return _handleResponse(response);
    });
  }

  /// POST with Authorization: Bearer header
  Future<dynamic> postWithAuth(String url, {Map<String, dynamic>? body}) async {
    final Map<String, dynamic> requestBody = {
      'project_code': ApiConstants.projectCode,
      ...body ?? {},
    };

    return _sendAuthed((token) {
      if (token == null || token.isEmpty) {
        _logger.warning('POST with auth request to: $url (NO TOKEN AVAILABLE)');
      } else {
        _logger.log('POST with auth request to: $url');
      }

      return _client
          .post(Uri.parse(url),
              headers: _headers(token: token), body: json.encode(requestBody))
          .timeout(const Duration(seconds: 15));
    });
  }

  /// GET with Authorization: Bearer header
  Future<dynamic> getWithAuth(String url, {Map<String, String>? additionalParams}) async {
    final Map<String, String> queryParams = {
      'project_code': ApiConstants.projectCode,
      ...Uri.parse(url).queryParameters,
      ...additionalParams ?? {},
    };

    final Uri uri = Uri.parse(url).replace(queryParameters: queryParams);

    return _sendAuthed((token) {
      if (token == null || token.isEmpty) {
        _logger.warning('GET with auth request to: $uri (NO TOKEN AVAILABLE)');
      } else {
        _logger.log('GET with auth request to: $uri');
      }

      return _client
          .get(uri, headers: _headers(token: token))
          .timeout(const Duration(seconds: 15));
    });
  }

  /// PUT with Authorization: Bearer header
  Future<dynamic> putWithAuth(String url, {Map<String, dynamic>? body}) async {
    final Map<String, dynamic> requestBody = {
      'project_code': ApiConstants.projectCode,
      ...body ?? {},
    };

    return _sendAuthed((token) {
      _logger.log('PUT with auth request to: $url');

      return _client
          .put(Uri.parse(url),
              headers: _headers(token: token), body: json.encode(requestBody))
          .timeout(const Duration(seconds: 15));
    });
  }

  /// DELETE with Authorization: Bearer header and optional JSON body
  Future<dynamic> deleteWithAuth(String url, {Map<String, dynamic>? body}) async {
    final encodedBody = json.encode({
      'project_code': ApiConstants.projectCode,
      ...body ?? {},
    });

    return _sendAuthed((token) async {
      _logger.log('DELETE with auth request to: $url');

      final request = http.Request('DELETE', Uri.parse(url));
      request.headers.addAll(_headers(token: token));
      request.body = encodedBody;

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      return http.Response.fromStream(streamed);
    });
  }

  /// Shared network-error mapping so every verb behaves identically.
  Future<dynamic> _run(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(
        message: 'No Internet connection',
        type: ErrorType.network
      );
    } on http.ClientException {
      throw ApiException(
        message: 'Failed to connect to server',
        type: ErrorType.network
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Connection timed out',
        type: ErrorType.network
      );
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
        type: ErrorType.generic
      );
    }
  }

  /// Decodes a response, or throws [ApiException] describing the failure.
  ///
  /// Deliberately free of side effects. Deciding what a 401 means — renew, or
  /// end the session — belongs to [_sendAuthed], which is the only place that
  /// knows whether a refresh has already been tried.
  dynamic _handleResponse(http.Response response) {
    _logger.log('Response status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;

      try {
        return json.decode(response.body);
      } catch (e) {
        _logger.error('Error decoding JSON response: $e. Raw response: ${response.body}');
        throw ApiException(
          message: 'Failed to decode API response',
          statusCode: response.statusCode,
          type: ErrorType.generic,
        );
      }
    } else {
      final errorType = _getErrorType(response.statusCode);
      throw ApiException(
        message: _getErrorMessage(response),
        statusCode: response.statusCode,
        type: errorType,
      );
    }
  }

  ErrorType _getErrorType(int statusCode) {
    if (statusCode == 0 || statusCode == -1) {
      return ErrorType.network;
    } else if (statusCode >= 500) {
      return ErrorType.server;
    } else if (statusCode == 401) {
      return ErrorType.auth;
    } else if (statusCode == 404) {
      return ErrorType.dataNotFound;
    } else {
      return ErrorType.generic;
    }
  }

  String _getErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map && body.containsKey('message')) {
        return body['message'] as String;
      }
      if (body is Map && body.containsKey('error') && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Session expired. Please log in again.';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Resource not found';
      case 500:
        return 'Server error';
      default:
        return 'Something went wrong (${response.statusCode})';
    }
  }
}
